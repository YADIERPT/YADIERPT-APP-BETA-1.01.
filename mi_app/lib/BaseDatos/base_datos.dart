import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class BaseDeDatos {
  static final BaseDeDatos instancia = BaseDeDatos._init();
  static Database? _database;

  BaseDeDatos._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _inicializarDB('viverapp.db');
    return _database!;
  }

  Future<Database> _inicializarDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 5,
      onCreate: _crearEsquema,
      onUpgrade: _actualizarEsquema,
    );
  }

  Future _actualizarEsquema(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE colaboradores (
          id TEXT PRIMARY KEY,
          nombre TEXT NOT NULL,
          clave TEXT NOT NULL,
          rol TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE configuracion ADD COLUMN etiquetasJson TEXT NOT NULL DEFAULT \'["Interior", "Suculentas", "Macetas", "Regalos"]\'',
      );
    }
    if (oldVersion < 4) {
      await db.execute(
        'ALTER TABLE configuracion ADD COLUMN aplicarIva INTEGER NOT NULL DEFAULT 1',
      );
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE ventas ADD COLUMN aplicarIva INTEGER NOT NULL DEFAULT 1',
      );
    }
  }

  Future _crearEsquema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE colaboradores (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        clave TEXT NOT NULL,
        rol TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE productos (
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        notas TEXT,
        precioVenta REAL NOT NULL,
        costo REAL NOT NULL,
        cantidadEnInventario INTEGER NOT NULL,
        imagenes TEXT -- Guardaremos las rutas separadas por comas
      )
    ''');
    await db.execute('''
      CREATE TABLE ventas (
        id TEXT PRIMARY KEY,
        fecha TEXT NOT NULL,
        estado TEXT NOT NULL,
        porcentajeIva REAL NOT NULL,
        aplicarIva INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE articulos_venta (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        venta_id TEXT NOT NULL,
        producto_id TEXT NOT NULL,
        cantidad INTEGER NOT NULL,
        precioUnitario REAL NOT NULL,
        FOREIGN KEY (venta_id) REFERENCES ventas (id) ON DELETE CASCADE,
        FOREIGN KEY (producto_id) REFERENCES productos (id)
      )
    ''');
    await db.execute('''
      CREATE TABLE transacciones (
        id TEXT PRIMARY KEY,
        tipo TEXT NOT NULL,
        monto REAL NOT NULL,
        fecha TEXT NOT NULL,
        descripcion TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE configuracion (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        temaOscuro INTEGER NOT NULL,
        tipoCambioUSD REAL NOT NULL,
        porcentajeIvaDefecto REAL NOT NULL,
        aplicarIva INTEGER NOT NULL,
        etiquetasJson TEXT NOT NULL
      )
    ''');
    await db.execute('''
      INSERT INTO configuracion (id, temaOscuro, tipoCambioUSD, porcentajeIvaDefecto, aplicarIva, etiquetasJson)
      VALUES (1, 0, 18.0, 0.16, 1, '["Interior", "Suculentas", "Macetas", "Regalos"]')
    ''');
  }

  Future cerrar() async {
    final db = await instancia.database;
    db.close();
    _database = null;
  }
}
