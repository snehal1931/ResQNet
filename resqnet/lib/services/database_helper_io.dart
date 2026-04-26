import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/message.dart';
import '../models/chat_message.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'resqnet.db');
    return await openDatabase(
      path,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages(
        messageId TEXT PRIMARY KEY,
        senderId TEXT,
        timestamp INTEGER,
        content TEXT,
        headcount INTEGER,
        severity TEXT,
        status TEXT,
        hopCount INTEGER,
        latitude REAL,
        longitude REAL,
        rescuerLatitude REAL,
        rescuerLongitude REAL
      )
    ''');
    await db.execute('''
      CREATE TABLE chat_messages(
        messageId TEXT PRIMARY KEY,
        senderId TEXT,
        receiverId TEXT,
        sosId TEXT,
        content TEXT,
        imagePath TEXT,
        audioPath TEXT,
        timestamp INTEGER
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE messages ADD COLUMN latitude REAL;");
      await db.execute("ALTER TABLE messages ADD COLUMN longitude REAL;");
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE messages ADD COLUMN status TEXT DEFAULT 'PENDING';");
    }
    if (oldVersion < 4) {
      await db.execute("ALTER TABLE messages ADD COLUMN rescuerLatitude REAL;");
      await db.execute("ALTER TABLE messages ADD COLUMN rescuerLongitude REAL;");
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE chat_messages(
          messageId TEXT PRIMARY KEY,
          senderId TEXT,
          receiverId TEXT,
          sosId TEXT,
          content TEXT,
          timestamp INTEGER
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute("ALTER TABLE chat_messages ADD COLUMN imagePath TEXT;");
    }
    if (oldVersion < 7) {
      await db.execute("ALTER TABLE chat_messages ADD COLUMN audioPath TEXT;");
    }
  }

  Future<void> insertMessage(SosMessage message) async {
    final db = await database;
    await db.insert(
      'messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, // Changed to replace to allow updates
    );
  }

  Future<void> updateMessageStatus(String messageId, String newStatus) async {
    final db = await database;
    await db.update(
      'messages',
      {'status': newStatus},
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
  }

  Future<List<SosMessage>> getMessages() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      orderBy: 'timestamp DESC',
    );
    return List.generate(maps.length, (i) {
      return SosMessage.fromMap(maps[i]);
    });
  }

  Future<bool> messageExists(String messageId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      where: 'messageId = ?',
      whereArgs: [messageId],
    );
    return maps.isNotEmpty;
  }
  Future<void> insertChatMessage(ChatMessage message) async {
    final db = await database;
    await db.insert(
      'chat_messages',
      message.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<ChatMessage>> getChatMessages(String sosId, String localNodeId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chat_messages',
      where: 'sosId = ?',
      whereArgs: [sosId],
      orderBy: 'timestamp ASC',
    );
    return maps.map((m) => ChatMessage.fromMap(m, localNodeId)).toList();
  }
}
