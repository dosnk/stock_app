import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'stock_app.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE stocks (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        market TEXT DEFAULT 'A股',
        created_at TEXT DEFAULT (datetime('now','localtime'))
      )
    ''');
    await db.execute('''
      CREATE TABLE trades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_code TEXT NOT NULL,
        stock_name TEXT NOT NULL DEFAULT '',
        trade_type TEXT NOT NULL CHECK(trade_type IN ('buy','sell')),
        trade_date TEXT NOT NULL,
        trade_time TEXT DEFAULT '',
        price REAL NOT NULL,
        volume INTEGER NOT NULL,
        amount REAL NOT NULL,
        commission REAL DEFAULT 0,
        stamp_tax REAL DEFAULT 0,
        transfer_fee REAL DEFAULT 0,
        net_amount REAL DEFAULT 0,
        notes TEXT DEFAULT '',
        created_at TEXT DEFAULT (datetime('now','localtime'))
      )
    ''');
    await db.execute('''
      CREATE TABLE kline_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_code TEXT NOT NULL,
        stock_name TEXT NOT NULL DEFAULT '',
        kdate TEXT NOT NULL,
        open REAL NOT NULL,
        close REAL NOT NULL,
        high REAL NOT NULL,
        low REAL NOT NULL,
        volume REAL DEFAULT 0,
        amount REAL DEFAULT 0,
        UNIQUE(stock_code, kdate)
      )
    ''');
    await db.execute('''
      CREATE TABLE positions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_code TEXT NOT NULL,
        stock_name TEXT NOT NULL DEFAULT '',
        volume INTEGER NOT NULL DEFAULT 0,
        cost_price REAL NOT NULL,
        updated_at TEXT DEFAULT (datetime('now','localtime')),
        UNIQUE(stock_code)
      )
    ''');
    await db.execute('''
      CREATE TABLE analysis_log (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        stock_code TEXT DEFAULT '',
        analysis_type TEXT NOT NULL,
        prompt TEXT,
        response TEXT,
        created_at TEXT DEFAULT (datetime('now','localtime'))
      )
    ''');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_trades_stock ON trades(stock_code)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_trades_date ON trades(trade_date)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_kline_stock ON kline_data(stock_code)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {}

  // ===== 备份 =====
  Future<String> getDbPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return join(dir.path, 'stock_app.db');
  }

  Future<void> restoreDb(String backupPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = join(dir.path, 'stock_app.db');
    // 关闭当前数据库
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
    // 复制备份文件
    final bytes = File(backupPath).readAsBytesSync();
    await File(dbPath).writeAsBytes(bytes);
    // 重新打开
    _database = await _initDB();
  }

  // ===== 股票自动补全 =====
  Future<Map<String, String>> getOrCreateStock(String code, String name) async {
    final db = await database;
    await db.insert('stocks', {
      'code': code,
      'name': name,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    return {'code': code, 'name': name};
  }

  Future<List<Map<String, dynamic>>> searchStocks(String query) async {
    final db = await database;
    return await db.query('stocks',
        where: 'code LIKE ? OR name LIKE ?',
        whereArgs: ['%$query%', '%$query%'],
        orderBy: 'code');
  }

  // ===== 交割单 =====
  Future<int> addTrade(Map<String, dynamic> trade) async {
    final db = await database;
    return await db.insert('trades', trade);
  }

  Future<List<Map<String, dynamic>>> getTrades(
      {String? stockCode, int limit = 200, int offset = 0}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (stockCode != null && stockCode.isNotEmpty) {
      where = 'stock_code = ?';
      whereArgs = [stockCode];
    }
    return await db.query('trades',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'trade_date DESC, id DESC',
        limit: limit,
        offset: offset);
  }

  Future<void> deleteTrade(int id) async {
    final db = await database;
    await db.delete('trades', where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, dynamic>> getTradeStats({String? stockCode}) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;
    if (stockCode != null && stockCode.isNotEmpty) {
      where = 'stock_code = ?';
      whereArgs = [stockCode];
    }
    final buys = await db.rawQuery(
        'SELECT COUNT(*) as cnt, COALESCE(SUM(amount),0) as total FROM trades WHERE trade_type="buy"${where != null ? ' AND stock_code=?' : ''}',
        whereArgs);
    final sells = await db.rawQuery(
        'SELECT COUNT(*) as cnt, COALESCE(SUM(amount),0) as total FROM trades WHERE trade_type="sell"${where != null ? ' AND stock_code=?' : ''}',
        whereArgs);
    return {
      'buy_count': buys.first['cnt'] ?? 0,
      'buy_amount': buys.first['total'] ?? 0,
      'sell_count': sells.first['cnt'] ?? 0,
      'sell_amount': sells.first['total'] ?? 0,
    };
  }

  // ===== K线 =====
  Future<int> addKline(Map<String, dynamic> kline) async {
    final db = await database;
    return await db.insert('kline_data', kline,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getKline(
      String stockCode, int days) async {
    final db = await database;
    return await db.rawQuery('''
      SELECT * FROM kline_data
      WHERE stock_code = ?
      ORDER BY kdate DESC LIMIT ?
    ''', [stockCode, days]);
  }

  Future<List<Map<String, dynamic>>> getDistinctKlineStocks() async {
    final db = await database;
    return await db.rawQuery(
        'SELECT DISTINCT stock_code, stock_name FROM kline_data ORDER BY stock_code');
  }

  // ===== 持仓 =====
  Future<int> upsertPosition(Map<String, dynamic> pos) async {
    final db = await database;
    // 先删后插实现 upsert
    await db.delete('positions',
        where: 'stock_code = ?', whereArgs: [pos['stock_code']]);
    return await db.insert('positions', pos);
  }

  Future<List<Map<String, dynamic>>> getPositions() async {
    final db = await database;
    return await db
        .query('positions', orderBy: 'updated_at DESC');
  }

  Future<void> deletePosition(String stockCode) async {
    final db = await database;
    await db
        .delete('positions', where: 'stock_code = ?', whereArgs: [stockCode]);
  }

  // ===== 分析日志 =====
  Future<int> addAnalysisLog(Map<String, dynamic> log) async {
    final db = await database;
    return await db.insert('analysis_log', log);
  }

  Future<List<Map<String, dynamic>>> getAnalysisLog({int limit = 20}) async {
    final db = await database;
    return await db
        .query('analysis_log', orderBy: 'created_at DESC', limit: limit);
  }

  // ===== 仪表盘统计 =====
  Future<Map<String, dynamic>> getDashboardStats() async {
    final db = await database;
    final tradeCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM trades')) ??
        0;
    final stockCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(DISTINCT stock_code) FROM trades')) ??
        0;
    final klineCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM kline_data')) ??
        0;
    final posCount = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM positions')) ??
        0;
    return {
      'trade_count': tradeCount,
      'stock_count': stockCount,
      'kline_count': klineCount,
      'position_count': posCount,
    };
  }

  Future<List<Map<String, dynamic>>> getRecentTradesByStock() async {
    final db = await database;
    return await db.rawQuery('''
      SELECT stock_code, stock_name, COUNT(*) as cnt,
             SUM(CASE WHEN trade_type="buy" THEN amount ELSE 0 END) as buy_amt,
             SUM(CASE WHEN trade_type="sell" THEN amount ELSE 0 END) as sell_amt
      FROM trades
      GROUP BY stock_code
      ORDER BY cnt DESC
      LIMIT 10
    ''');
  }

  /// 获取所有不同的股票代码+名称（从交割单 + K线 + 持仓中汇总）
  Future<List<Map<String, dynamic>>> getAllStockCodes() async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT code, name FROM stocks ORDER BY code
    ''');
    return result;
  }
}
