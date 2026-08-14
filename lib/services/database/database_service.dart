import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import '../../shared/models/download_item.dart';
import '../../shared/models/recent_link.dart';
import '../logger/app_logger.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;

  DatabaseService._();

  static DatabaseService get instance {
    _instance ??= DatabaseService._();
    return _instance!;
  }

  static Future<void> initialize() async {
    // Initialize sqflite for desktop platforms
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      AppLogger.info('Initialized sqflite_ffi for desktop platform');
    }
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;

    if (Platform.isWindows) {
      // Use APPDATA on Windows
      final appData = Platform.environment['APPDATA'];
      if (appData == null) {
        throw Exception('APPDATA environment variable not found');
      }
      final dbDir = Directory('$appData${Platform.pathSeparator}MBNDownloader');
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }
      path =
          '$appData${Platform.pathSeparator}MBNDownloader${Platform.pathSeparator}mbn_downloader.db';
    } else {
      // Use default database path for Android/iOS
      final dbPath = await getDatabasesPath();
      path = join(dbPath, 'mbn_downloader.db');
    }

    AppLogger.info('Initializing database at: $path');

    return await openDatabase(
      path,
      version: 4,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    AppLogger.info('Creating database tables');

    await db.execute('''
      CREATE TABLE downloads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL,
        title TEXT NOT NULL,
        thumbnail TEXT,
        status INTEGER NOT NULL,
        filePath TEXT,
        fileSize INTEGER,
        errorMessage TEXT,
        createdAt INTEGER NOT NULL,
        completedAt INTEGER,
        progress REAL NOT NULL DEFAULT 0.0,
        formatId TEXT,
        videoCodec TEXT,
        audioCodec TEXT,
        fileExtension TEXT,
        quality TEXT,
        downloadType TEXT,
        currentPhase TEXT,
        formatLabel TEXT,
        coverPath TEXT,
        subtitlePaths TEXT NOT NULL DEFAULT '[]',
        relatedFilePaths TEXT NOT NULL DEFAULT '[]',
        publicUris TEXT NOT NULL DEFAULT '[]'
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_status ON downloads(status)
    ''');

    await db.execute('''
      CREATE INDEX idx_createdAt ON downloads(createdAt DESC)
    ''');

    await db.execute('''
      CREATE TABLE recent_links (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        url TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        thumbnail TEXT,
        formatsJson TEXT NOT NULL,
        videoInfoJson TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_recent_links_createdAt ON recent_links(createdAt DESC)
    ''');

    AppLogger.info('Database tables created successfully');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.info(
      'Upgrading database from version $oldVersion to $newVersion',
    );

    if (oldVersion < 2) {
      // Add new metadata columns for version 2
      await db.execute('ALTER TABLE downloads ADD COLUMN formatId TEXT');
      await db.execute('ALTER TABLE downloads ADD COLUMN videoCodec TEXT');
      await db.execute('ALTER TABLE downloads ADD COLUMN audioCodec TEXT');
      await db.execute('ALTER TABLE downloads ADD COLUMN fileExtension TEXT');
      await db.execute('ALTER TABLE downloads ADD COLUMN quality TEXT');
      await db.execute('ALTER TABLE downloads ADD COLUMN downloadType TEXT');
      await db.execute('ALTER TABLE downloads ADD COLUMN currentPhase TEXT');
      AppLogger.info('Added metadata columns to downloads table');
    }

    if (oldVersion < 3) {
      // Add recent_links table for version 3
      await db.execute('''
        CREATE TABLE recent_links (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          url TEXT NOT NULL UNIQUE,
          title TEXT NOT NULL,
          thumbnail TEXT,
          formatsJson TEXT NOT NULL,
          videoInfoJson TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE INDEX idx_recent_links_createdAt ON recent_links(createdAt DESC)
      ''');
      AppLogger.info('Added recent_links table');
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE downloads ADD COLUMN formatLabel TEXT');
      await db.execute('ALTER TABLE downloads ADD COLUMN coverPath TEXT');
      await db.execute(
        "ALTER TABLE downloads ADD COLUMN subtitlePaths TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        "ALTER TABLE downloads ADD COLUMN relatedFilePaths TEXT NOT NULL DEFAULT '[]'",
      );
      await db.execute(
        "ALTER TABLE downloads ADD COLUMN publicUris TEXT NOT NULL DEFAULT '[]'",
      );
      AppLogger.info('Added downloaded artifact columns');
    }
  }

  // CRUD Operations

  Future<int> insertDownload(DownloadItem item) async {
    try {
      final db = await database;
      final id = await db.insert('downloads', item.toMap());
      AppLogger.info('Inserted download: ${item.title} with ID: $id');
      return id;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to insert download', e, stackTrace);
      rethrow;
    }
  }

  Future<int> updateDownload(DownloadItem item) async {
    try {
      final db = await database;
      final count = await db.update(
        'downloads',
        item.toMap(),
        where: 'id = ?',
        whereArgs: [item.id],
      );
      AppLogger.trace('Updated download: ${item.title}');
      return count;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to update download', e, stackTrace);
      rethrow;
    }
  }

  Future<int> deleteDownload(int id) async {
    try {
      final db = await database;
      final count = await db.delete(
        'downloads',
        where: 'id = ?',
        whereArgs: [id],
      );
      AppLogger.info('Deleted download with ID: $id');
      return count;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete download', e, stackTrace);
      rethrow;
    }
  }

  Future<DownloadItem?> getDownloadById(int id) async {
    try {
      final db = await database;
      final maps = await db.query(
        'downloads',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (maps.isNotEmpty) {
        return DownloadItem.fromMap(maps.first);
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get download by ID', e, stackTrace);
      rethrow;
    }
  }

  Future<List<DownloadItem>> getAllDownloads({
    String orderBy = 'createdAt DESC',
  }) async {
    try {
      final db = await database;
      final maps = await db.query('downloads', orderBy: orderBy);
      return maps.map((map) => DownloadItem.fromMap(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get all downloads', e, stackTrace);
      rethrow;
    }
  }

  Future<List<DownloadItem>> getDownloadsByStatus(DownloadStatus status) async {
    try {
      final db = await database;
      final maps = await db.query(
        'downloads',
        where: 'status = ?',
        whereArgs: [status.index],
        orderBy: 'createdAt DESC',
      );
      return maps.map((map) => DownloadItem.fromMap(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get downloads by status', e, stackTrace);
      rethrow;
    }
  }

  Future<int> getDownloadCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('SELECT COUNT(*) FROM downloads');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get download count', e, stackTrace);
      rethrow;
    }
  }

  Future<int> clearAllDownloads() async {
    try {
      final db = await database;
      final count = await db.delete('downloads');
      AppLogger.warning('Cleared all downloads: $count items');
      return count;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear downloads', e, stackTrace);
      rethrow;
    }
  }

  Future<int> clearCompletedDownloads() async {
    try {
      final db = await database;
      final count = await db.delete(
        'downloads',
        where: 'status = ?',
        whereArgs: [DownloadStatus.completed.index],
      );
      AppLogger.info('Cleared completed downloads: $count items');
      return count;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear completed downloads', e, stackTrace);
      rethrow;
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    AppLogger.info('Database closed');
  }

  // Recent Links CRUD Operations

  Future<int> insertRecentLink(RecentLink link) async {
    try {
      final db = await database;
      final id = await db.insert(
        'recent_links',
        link.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      AppLogger.info('Inserted recent link: ${link.title}');
      return id;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to insert recent link', e, stackTrace);
      rethrow;
    }
  }

  Future<List<RecentLink>> getAllRecentLinks({int limit = 50}) async {
    try {
      final db = await database;
      final maps = await db.query(
        'recent_links',
        orderBy: 'createdAt DESC',
        limit: limit,
      );
      return maps.map((map) => RecentLink.fromMap(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get recent links', e, stackTrace);
      rethrow;
    }
  }

  Future<RecentLink?> getRecentLinkByUrl(String url) async {
    try {
      final db = await database;
      final maps = await db.query(
        'recent_links',
        where: 'url = ?',
        whereArgs: [url],
      );
      if (maps.isNotEmpty) {
        return RecentLink.fromMap(maps.first);
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get recent link by URL', e, stackTrace);
      rethrow;
    }
  }

  Future<List<RecentLink>> searchRecentLinks(String query) async {
    try {
      final db = await database;
      final maps = await db.query(
        'recent_links',
        where: 'title LIKE ? OR url LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'createdAt DESC',
      );
      return maps.map((map) => RecentLink.fromMap(map)).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to search recent links', e, stackTrace);
      rethrow;
    }
  }

  Future<int> deleteRecentLink(int id) async {
    try {
      final db = await database;
      final count = await db.delete(
        'recent_links',
        where: 'id = ?',
        whereArgs: [id],
      );
      AppLogger.info('Deleted recent link with ID: $id');
      return count;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete recent link', e, stackTrace);
      rethrow;
    }
  }

  Future<int> clearAllRecentLinks() async {
    try {
      final db = await database;
      final count = await db.delete('recent_links');
      AppLogger.info('Cleared all recent links: $count items');
      return count;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to clear recent links', e, stackTrace);
      rethrow;
    }
  }
}
