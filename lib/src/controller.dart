import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqlcool/sqlcool.dart';
import 'package:err/err.dart';
import 'package:slugify2/slugify.dart';
import 'models.dart';
import 'state.dart';

/// Callback to run after exporting a database
typedef Future<void> DataTransferCallback(
    {@required String slug,
    @required String dbPath,
    @required String destinationPath});

Slugify _slugify = Slugify();

/// The main class to control db switching
class DbSwitcher {
  /// Default constructor: provide a [databasesPath] and a [schema]
  DbSwitcher(
      {@required this.databasesPath,
      @required this.schema,
      this.initQueries,
      this.logger,
      this.afterExportCallback,
      this.verbose})
      : assert(schema != null),
        assert(schema.isNotEmpty),
        assert(databasesPath != null) {
    logger = logger ?? ErrRouter(infoRoute: [ErrRoute.screen]);
    verbose = verbose ?? false;
    initQueries = initQueries ?? [];
  }

  /// The database schema: create table queries
  final List<String> schema;

  /// The queries to be executed at database creation time
  List<String> initQueries;

  /// The file path of the databases
  final String databasesPath;

  /// After export callback
  DataTransferCallback afterExportCallback;

  /// The err logger
  ErrRouter logger;

  /// Verbosity
  bool verbose;

  final _switcherDb = Db();
  final _dbSwitchState = DbSwitchState();
  bool _initialized = false;

  final _changeFeed = StreamController<ActiveDatabase>();

  /// The main switcher instance
  Db get switcherDb => _switcherDb;

  /// The state of the database
  DbSwitchState get state => _dbSwitchState;

  /// Get the active database
  ActiveDatabase get activeDb => _dbSwitchState.activeDb;

  /// The changefeed: a stream with databases switches changes
  Stream<ActiveDatabase> get changeFeed => _changeFeed.stream;

  /// The initialization function: has to be run after [DbSwitcher]
  /// creation to be able to work with the package
  Future<void> init({@required Db db}) async {
    await _initSwitcherDb();
    await _switcherDb.onReady;
    _dbSwitchState.activeDb = await _initActiveDb(db: db);
    _changeFeed.sink.add(_dbSwitchState.activeDb);
    _dbSwitchState.activeDb.db.onReady.then((_) {
      _initialized = true;
    });
  }

  /// Dispose the changefeed
  void dispose() {
    _changeFeed.close();
  }

  /// Switch the active database
  Future<ActiveDatabase> switchDb(
      {@required String slug, @required int id}) async {
    // activate
    var activeDb = await _switchDb(id: id, slug: slug);
    // set state
    _dbSwitchState.activeDb = activeDb;
    // emit the change
    _changeFeed.sink.add(_dbSwitchState.activeDb);
    return activeDb;
  }

  /// Add a database: will run the [schema] and [initQueries] queries
  Future<void> addDb({@required String name}) async {
    assert(_initialized);
    assert(_switcherDb != null);
    String slug = _slugify.slugify(name);
    var row = {"name": name, "slug": slug};
    await _switcherDb
        .insert(table: "database", row: row, verbose: verbose)
        .catchError((dynamic e) {
      logger.error("Can not insert database: ${e.message}");
      throw (e);
    });
    if (verbose) logger.debug('Added database $name');
  }

  /// Import an existing Sqlite database from the filesystem by copying it
  Future<void> importDb(
      {@required String name, @required String sourcePath}) async {
    // Copy the file
    String slug = _slugify.slugify(name.trim());
    var file = File("$sourcePath/$slug/geodb.sqlite");
    String destinationPath = _getDbPath(slug);
    try {
      file.copySync(destinationPath);
    } catch (e) {
      logger.error("Can not copy database from $sourcePath", err: e);
      throw (e);
    }
    // Save the new database reference
    Map<String, String> row = {
      "name": name,
      "slug": slug,
      "path": destinationPath
    };
    await _switcherDb
        .insert(table: "database", row: row)
        .catchError((dynamic e) {
      logger.error("Can not save the new database reference", err: e);
      throw (e);
    });
    logger.info("Database imported");
  }

  /// Export a database to the filesystem
  Future<void> exportDb(
      {@required int id, @required String destinationPath}) async {
    assert(id != null);
    assert(destinationPath != null);
    // Get the database to export
    var res = await switcherDb
        .select(table: "database", where: 'id=$id', columns: "slug")
        .catchError((dynamic e) {
      logger.error("Can not select database to export", err: e);
      throw (e);
    });
    Map<String, dynamic> item = res[0];
    // Get paths
    File originFile;
    String destPath;
    String slug = "${item["slug"]}";
    String dbPath = _getDbPath(slug);
    try {
      originFile = File(dbPath);
      destPath = "$destinationPath/$slug/$slug.sqlite";
      // verify destination path
      Directory destDir = Directory("$destinationPath/$slug");
      logger.debug("Creating directory ${destDir.path}");
      if (!destDir.existsSync()) destDir.createSync(recursive: true);
    } catch (e) {
      throw ("Can not get paths: $e");
    }
    // Copy
    try {
      originFile.copySync(destPath);
    } catch (e) {
      logger.error("Can not copy database file");
      throw (e);
    }
    // Run the callback
    if (afterExportCallback != null)
      await afterExportCallback(
          slug: slug, dbPath: dbPath, destinationPath: destinationPath);
    logger.infoFlash('Database exported');
  }

  Future<ActiveDatabase> _switchDb(
      {@required String slug, @required int id}) async {
    assert(_initialized);
    assert(_switcherDb != null);
    Db oldDb = _dbSwitchState.activeDb.db;
    String path = _getDbPath(slug);
    ActiveDatabase activeDb =
        ActiveDatabase(id: id, path: path, slug: slug, db: Db());
    activeDb = await _initActiveDb(activeDb: activeDb).catchError((dynamic e) {
      throw (e);
    });
    // update active database in switcher db
    await _switcherDb
        .update(
            table: "active_database",
            where: "id=1",
            row: {"active_db_id": "$id"},
            verbose: verbose)
        .catchError((dynamic e) {
      logger.error("Can not update active database", err: e);
      throw (e);
    });
    oldDb.database.close();
    if (verbose) logger.infoFlash('Switched to ${activeDb.db.file.path}');
    return activeDb;
  }

  Future<ActiveDatabase> _initActiveDb({ActiveDatabase activeDb, Db db}) async {
    assert((db != null) || (activeDb != null));
    activeDb ??= await _getActiveDatabase();
    db ??= activeDb.db;
    List<String> queries = [];
    queries.addAll(schema);
    queries.addAll(initQueries);
    await db
        .init(
            path: activeDb.path,
            absolutePath: true,
            queries: queries,
            verbose: verbose)
        .catchError((dynamic e) {
      logger.critical("Can not init database: ${e.message}");
      throw ("Init db error from dbswitch");
    });
    if (verbose) logger.debug('Initialized active database ${db.file.path}');
    activeDb.db = db;
    return activeDb;
  }

  Future<ActiveDatabase> _getActiveDatabase() async {
    assert(_switcherDb != null);
    List<Map<String, dynamic>> res = await _switcherDb
        .join(
            table: "active_database",
            columns: "database.id, database.slug",
            joinTable: "database",
            joinOn: "active_db_id=database.id",
            verbose: verbose)
        .catchError((dynamic e) {
      logger.critical("Can not get active database: $e");
      throw (e);
    });
    String slug = "${res[0]["slug"]}";
    String path = _getDbPath(slug);
    return ActiveDatabase(
        id: int.parse("${res[0]["id"]}"),
        path: path,
        slug: "${res[0]["slug"]}");
  }

  /// Get the database path and ensure that the directory exists
  String _getDbPath(String slug) {
    // create the project directory if necessary
    var dir = Directory("$databasesPath/$slug");
    if (!dir.existsSync()) {
      logger.debug("Creating directory ${dir.path}");
      dir.createSync(recursive: true);
    }
    String path = "$databasesPath/$slug/$slug.sqlite";
    return path;
  }

  Future<void> _initSwitcherDb() async {
    String q1 = """CREATE TABLE database (
        id INTEGER PRIMARY KEY,
        name VARCHAR(30) UNIQUE NOT NULL,
        slug VARCHAR(30) UNIQUE NOT NULL,
        active BOOLEAN DEFAULT false
        )""";
    String q2 = """CREATE TABLE active_database (
        id INTEGER PRIMARY KEY,
        active_db_id INTEGER NOT NULL, 
        CONSTRAINT active_db
         FOREIGN KEY (active_db_id)
         REFERENCES database(id)
         ON DELETE CASCADE
    )""";
    String dbPath = "dbswitch1.sqlite";
    String q3 = 'INSERT INTO database(id, name, slug, active) ' +
        'VALUES (1, "Default", "default", "true")';
    String q4 = 'INSERT INTO active_database(id, active_db_id) VALUES (1, 1)';
    await _switcherDb
        .init(path: dbPath, queries: [q1, q2, q3, q4], verbose: verbose)
        .catchError((dynamic e) {
      logger.critical("Can not init database: ${e.message}");
      throw (e);
    });
    if (verbose) logger.debug("Switcher database initialized");
  }
}
