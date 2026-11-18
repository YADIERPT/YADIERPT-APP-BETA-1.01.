-- ==============================================================================
-- PLANTEAPP POS - SCRIPT DEFINITIVO DE CONSOLIDACIÓN DE INVENTARIO EN SUPABASE
-- Motor de Deltas de Stock Offline-First (PostgreSQL / Supabase)
-- ==============================================================================

-- 1. TABLA: movimientos_inventario (Si aún no existe en Supabase)
CREATE TABLE IF NOT EXISTS public.movimientos_inventario (
    uuid TEXT PRIMARY KEY,
    producto_uuid TEXT NOT NULL,
    tipo TEXT NOT NULL,
    cantidad INTEGER NOT NULL,
    referencia_uuid TEXT,
    motivo TEXT,
    colaborador_uuid TEXT,
    dispositivo_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Índices de alto rendimiento para sincronización y auditoría
CREATE INDEX IF NOT EXISTS idx_mov_inv_producto_uuid 
    ON public.movimientos_inventario(producto_uuid);

CREATE INDEX IF NOT EXISTS idx_mov_inv_created_at 
    ON public.movimientos_inventario(created_at);

CREATE INDEX IF NOT EXISTS idx_mov_inv_tipo 
    ON public.movimientos_inventario(tipo);

-- Habilitar RLS (Row Level Security) y políticas de acceso
ALTER TABLE public.movimientos_inventario ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'movimientos_inventario' 
        AND policyname = 'Permitir todo a autenticados y anon en movimientos_inventario'
    ) THEN
        CREATE POLICY "Permitir todo a autenticados y anon en movimientos_inventario"
        ON public.movimientos_inventario
        FOR ALL
        TO anon, authenticated
        USING (true)
        WITH CHECK (true);
    END IF;
END $$;

-- ==============================================================================
-- 2. FUNCIÓN DE TRIGGER: actualizar_stock_desde_movimiento()
-- ==============================================================================
CREATE OR REPLACE FUNCTION public.actualizar_stock_desde_movimiento()
RETURNS TRIGGER 
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_tipo_lower TEXT;
    v_delta_nuevo INTEGER := 0;
    v_delta_viejo INTEGER := 0;
    v_delta_neto  INTEGER := 0;
    v_producto_uuid TEXT;
BEGIN
    -- Determinar el producto afectado según la operación
    IF (TG_OP = 'DELETE') THEN
        v_producto_uuid := OLD.producto_uuid;
    ELSE
        v_producto_uuid := NEW.producto_uuid;
    END IF;

    -- -------------------------------------------------------------------------
    -- A) CÁLCULO DE DELTA NUEVO (Normalización inteligente de signos)
    -- -------------------------------------------------------------------------
    IF (TG_OP IN ('INSERT', 'UPDATE')) THEN
        v_tipo_lower := LOWER(TRIM(NEW.tipo));

        IF v_tipo_lower IN ('venta', 'merma', 'salida', 'baja', 'perdida') THEN
            -- Salidas: Siempre restan existencias (fuerza valor negativo)
            v_delta_nuevo := -ABS(NEW.cantidad);
        ELSIF v_tipo_lower IN ('compra', 'abastecimiento', 'entrada', 'devolucion', 'recepcion') THEN
            -- Entradas: Siempre suman existencias (fuerza valor positivo)
            v_delta_nuevo := ABS(NEW.cantidad);
        ELSE
            -- Ajustes manuales ('ajuste', 'inventario_inicial', etc.):
            -- Respeta el signo aritmético enviado desde el cliente (+ o -)
            v_delta_nuevo := NEW.cantidad;
        END IF;
    END IF;

    -- -------------------------------------------------------------------------
    -- B) CÁLCULO DE DELTA VIEJO (En caso de UPDATE o DELETE)
    -- -------------------------------------------------------------------------
    IF (TG_OP IN ('UPDATE', 'DELETE')) THEN
        v_tipo_lower := LOWER(TRIM(OLD.tipo));

        IF v_tipo_lower IN ('venta', 'merma', 'salida', 'baja', 'perdida') THEN
            v_delta_viejo := -ABS(OLD.cantidad);
        ELSIF v_tipo_lower IN ('compra', 'abastecimiento', 'entrada', 'devolucion', 'recepcion') THEN
            v_delta_viejo := ABS(OLD.cantidad);
        ELSE
            v_delta_viejo := OLD.cantidad;
        END IF;
    END IF;

    -- -------------------------------------------------------------------------
    -- C) DETERMINACIÓN DEL DELTA NETO (Idempotencia en Upsert)
    -- -------------------------------------------------------------------------
    IF (TG_OP = 'INSERT') THEN
        v_delta_neto := v_delta_nuevo;
    ELSIF (TG_OP = 'UPDATE') THEN
        -- Si un re-intento de red envía el mismo registro, delta_neto será 0
        v_delta_neto := v_delta_nuevo - v_delta_viejo;
    ELSIF (TG_OP = 'DELETE') THEN
        -- Si se borra un movimiento, se revierte su impacto
        v_delta_neto := -v_delta_viejo;
    END IF;

    -- Si no hay cambio real en las cantidades, salimos inmediatamente
    IF v_delta_neto = 0 THEN
        IF (TG_OP = 'DELETE') THEN
            RETURN OLD;
        ELSE
            RETURN NEW;
        END IF;
    END IF;

    -- -------------------------------------------------------------------------
    -- D) BLOQUEO PESIMISTA (FOR UPDATE) Y ACTUALIZACIÓN ATÓMICA DE STOCK
    -- -------------------------------------------------------------------------
    -- Bloquear la fila del producto para prevenir condiciones de carrera
    -- entre múltiples dispositivos subiendo ventas al mismo milisegundo.
    PERFORM 1 
    FROM public.productos 
    WHERE uuid = v_producto_uuid 
    FOR UPDATE;

    -- Actualizar el stock y adelantar updated_at para que las demás tablets
    -- lo descarguen en su próximo Pull Incremental.
    UPDATE public.productos
    SET stock = COALESCE(stock, 0) + v_delta_neto,
        updated_at = timezone('utc'::text, now())
    WHERE uuid = v_producto_uuid;

    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$;

-- ==============================================================================
-- 3. VINCULACIÓN DEL TRIGGER A LA TABLA movimientos_inventario
-- ==============================================================================
DROP TRIGGER IF EXISTS trg_aplicar_movimiento_stock ON public.movimientos_inventario;

CREATE TRIGGER trg_aplicar_movimiento_stock
    AFTER INSERT OR UPDATE OR DELETE
    ON public.movimientos_inventario
    FOR EACH ROW
    EXECUTE FUNCTION public.actualizar_stock_desde_movimiento();

-- ==============================================================================
-- 4. FUNCIÓN AUXILIAR DE RECALCULO GENERAL (Disaster Recovery / Mantenimiento)
-- ==============================================================================
-- Permite al DBA recalcular el stock de un producto o de todos sumando
-- el histórico completo de movimientos si se sospecha desalineación.
CREATE OR REPLACE FUNCTION public.recalcular_stock_total(p_producto_uuid TEXT DEFAULT NULL)
RETURNS void
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_producto_uuid IS NOT NULL THEN
        UPDATE public.productos p
        SET stock = COALESCE((
            SELECT SUM(
                CASE 
                    WHEN LOWER(TRIM(m.tipo)) IN ('venta', 'merma', 'salida', 'baja', 'perdida') THEN -ABS(m.cantidad)
                    WHEN LOWER(TRIM(m.tipo)) IN ('compra', 'abastecimiento', 'entrada', 'devolucion', 'recepcion') THEN ABS(m.cantidad)
                    ELSE m.cantidad
                END
            )
            FROM public.movimientos_inventario m
            WHERE m.producto_uuid = p_producto_uuid
        ), 0),
        updated_at = timezone('utc'::text, now())
        WHERE p.uuid = p_producto_uuid;
    ELSE
        UPDATE public.productos p
        SET stock = COALESCE((
            SELECT SUM(
                CASE 
                    WHEN LOWER(TRIM(m.tipo)) IN ('venta', 'merma', 'salida', 'baja', 'perdida') THEN -ABS(m.cantidad)
                    WHEN LOWER(TRIM(m.tipo)) IN ('compra', 'abastecimiento', 'entrada', 'devolucion', 'recepcion') THEN ABS(m.cantidad)
                    ELSE m.cantidad
                END
            )
            FROM public.movimientos_inventario m
            WHERE m.producto_uuid = p.uuid
        ), 0),
        updated_at = timezone('utc'::text, now());
    END IF;
END;
$$;

