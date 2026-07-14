# 股票交易助手 (stock_app) - Code Wiki

> 📈 个人股票交易分析系统 - 基于 Flutter 的跨平台本地优先应用

---

## 目录

- [1. 项目概览](#1-项目概览)
- [2. 项目整体架构](#2-项目整体架构)
- [3. 目录结构](#3-目录结构)
- [4. 主要模块职责](#4-主要模块职责)
- [5. 关键类与函数说明](#5-关键类与函数说明)
  - [5.1 应用入口与主壳 (main.dart)](#51-应用入口与主壳-maindart)
  - [5.2 数据访问层 (DatabaseHelper)](#52-数据访问层-databasehelper)
  - [5.3 页面层 (Pages)](#53-页面层-pages)
- [6. 数据模型与数据库设计](#6-数据模型与数据库设计)
- [7. 依赖关系](#7-依赖关系)
- [8. 主题与视觉设计](#8-主题与视觉设计)
- [9. 构建与部署](#9-构建与部署)
- [10. 项目运行方式](#10-项目运行方式)
- [11. 已知问题与改进建议](#11-已知问题与改进建议)

---

## 1. 项目概览

| 属性 | 值 |
|------|-----|
| **项目名称** | stock_app（股票交易助手） |
| **版本** | 1.0.0+1 |
| **描述** | 📈 股票交易助手 - 个人股票交易分析系统 |
| **技术栈** | Flutter + Dart |
| **Dart SDK** | ^3.6.2 |
| **Flutter 版本** | 3.27.4 (stable) |
| **支持平台** | Android / iOS / Linux / macOS / Web / Windows |
| **主目标平台** | Android（applicationId: `com.atrader.stock_app`） |
| **数据存储** | 本地 SQLite（sqflite），不上传云端 |
| **AI 集成** | 兼容 OpenAI Chat Completions 协议的 LLM（默认 DeepSeek） |

**核心功能：**
- 📋 交割单（交易记录）录入、查询、统计
- 📊 K 线数据管理（单条 / 批量导入）
- 💼 持仓管理（成本价、数量维护）
- 🤖 AI 智能分析（操作风格分析、持仓操作建议）
- 🗄️ 本地数据库备份与恢复
- 📈 仪表盘统计与活跃股票展示

**设计理念：** 本地优先（Local-First），所有用户数据仅存储在设备本地 SQLite 数据库中，不上传任何云端，保障隐私安全。AI 分析通过用户自行配置的 LLM API 完成。

---

## 2. 项目整体架构

项目采用 **Flutter 标准分层架构**，结合 **底部导航 + 单 Activity/页面栈** 的 UI 模式。

```
┌─────────────────────────────────────────────────────────────┐
│                        UI 层 (Pages)                         │
│  HomePage  TradesPage  KlinePage  PositionsPage  AnalysisPage│
│                      SettingsPage (独立路由)                  │
└──────────────────────────┬──────────────────────────────────┘
                           │ 调用
┌──────────────────────────▼──────────────────────────────────┐
│                  数据访问层 (DatabaseHelper)                  │
│          单例模式 · SQLite CRUD · 统计聚合查询                │
└──────────────────────────┬──────────────────────────────────┘
                           │ 持久化
┌──────────────────────────▼──────────────────────────────────┐
│              本地存储 (sqflite + path_provider)               │
│                    stock_app.db (SQLite)                     │
└─────────────────────────────────────────────────────────────┘

           ╔═══════════════════════════════════════╗
           ║   外部服务 (AnalysisPage → HTTP)        ║
           ║   LLM API (DeepSeek / OpenAI 兼容)      ║
           ╚═══════════════════════════════════════╝
```

**架构特点：**
1. **单例数据库访问**：`DatabaseHelper.instance` 全局唯一，懒加载，避免重复初始化。
2. **页面即模块**：每个功能页面自包含 UI + 业务逻辑，通过 `DatabaseHelper` 访问数据。
3. **无状态管理库**：使用 Flutter 原生 `setState`，未引入 Provider/Riverpod/Bloc 等状态管理框架，保持轻量。
4. **本地优先**：所有数据本地化，AI 分析为可选增强功能。
5. **跨平台构建**：通过 Docker 容器化编译 APK，CI/CD 通过 GitHub Actions。

---

## 3. 目录结构

```
stock_app/
├── lib/                          # 🎯 Dart 源码（核心）
│   ├── main.dart                 # 应用入口 + 主壳 MainShell
│   ├── database/
│   │   └── database_helper.dart  # SQLite 数据访问层（单例）
│   └── pages/                    # 功能页面
│       ├── home_page.dart        # 首页（仪表盘）
│       ├── trades_page.dart      # 交割单管理
│       ├── kline_page.dart       # K线数据管理
│       ├── positions_page.dart   # 持仓管理
│       ├── analysis_page.dart    # AI 分析
│       └── settings_page.dart    # 设置（备份/恢复）
│
├── android/                      # Android 平台配置
│   ├── app/
│   │   ├── build.gradle          # Android 应用级构建配置
│   │   └── src/main/
│   │       ├── AndroidManifest.xml
│   │       └── kotlin/com/atrader/stock_app/MainActivity.kt
│   ├── build.gradle              # 项目级构建配置
│   ├── settings.gradle           # Gradle 设置（含阿里云镜像）
│   ├── gradle.properties         # Gradle JVM 参数
│   └── gradle/wrapper/           # Gradle 8.3
│
├── ios/                          # iOS 平台配置（Swift）
├── linux/                        # Linux 平台配置（CMake）
├── macos/                        # macOS 平台配置（Swift）
├── windows/                      # Windows 平台配置（CMake）
├── web/                          # Web 平台配置
│
├── docker/                       # 🐳 Docker 编译环境
│   ├── Dockerfile                # Ubuntu 22.04 + Flutter 3.27.4 + Android SDK
│   ├── docker-compose.yml        # 编译服务编排
│   ├── build.sh                  # Linux/Mac 编译脚本
│   ├── build.bat                 # Windows 编译脚本
│   └── build-entrypoint.sh       # 容器编译入口
│
├── .github/workflows/
│   └── build-apk.yml             # GitHub Actions CI（push master 触发）
│
├── test/
│   └── widget_test.dart          # Widget 测试（模板代码，需更新）
│
├── pubspec.yaml                  # Flutter 项目配置与依赖
├── pubspec.lock                  # 依赖锁定版本
├── analysis_options.yaml         # Dart 静态分析配置
├── build_apk.sh                  # 本地直连编译脚本
├── DOCKER_BUILD.md               # Docker 编译指南
├── README.md                     # 项目说明
└── .metadata                     # Flutter 元数据
```

---

## 4. 主要模块职责

| 模块 | 文件 | 职责 |
|------|------|------|
| **应用入口** | [main.dart](file:///workspace/lib/main.dart) | 初始化数据库、配置全局主题、构建 `MainShell` 底部导航框架 |
| **数据访问层** | [database_helper.dart](file:///workspace/lib/database/database_helper.dart) | SQLite 数据库初始化、表结构创建、所有 CRUD 操作、统计聚合查询、备份恢复 |
| **首页** | [home_page.dart](file:///workspace/lib/pages/home_page.dart) | 仪表盘：显示交易/持仓/K线/股票数量统计、活跃股票排名 |
| **交割单** | [trades_page.dart](file:///workspace/lib/pages/trades_page.dart) | 交易记录录入（买/卖）、自动计算成交额与净额、列表展示、删除、买卖统计 |
| **K线数据** | [kline_page.dart](file:///workspace/lib/pages/kline_page.dart) | K线单条录入、批量粘贴导入、按股票查看、涨跌幅计算展示 |
| **持仓管理** | [positions_page.dart](file:///workspace/lib/pages/positions_page.dart) | 持仓录入/更新（upsert）、持仓列表、删除 |
| **AI 分析** | [analysis_page.dart](file:///workspace/lib/pages/analysis_page.dart) | 调用 LLM 进行操作风格分析、持仓操作建议、分析历史记录 |
| **设置** | [settings_page.dart](file:///workspace/lib/pages/settings_page.dart) | 数据库信息展示、备份（分享）、恢复、使用提示 |
| **构建环境** | [docker/](file:///workspace/docker) | 容器化 APK 编译环境（Ubuntu + Flutter + Android SDK） |
| **CI/CD** | [.github/workflows/build-apk.yml](file:///workspace/.github/workflows/build-apk.yml) | 自动化构建 APK 并上传 artifact |

---

## 5. 关键类与函数说明

### 5.1 应用入口与主壳 ([main.dart](file:///workspace/lib/main.dart))

#### `main()` - 全局入口函数

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;   // 预初始化数据库
  SystemChrome.setSystemUIOverlayStyle(...); // 透明状态栏
  runApp(const StockApp());
}
```

**职责：** 确保 Flutter 绑定初始化 → 预热数据库连接 → 设置透明状态栏 → 启动应用。

#### `StockApp` - 应用根 Widget（StatelessWidget）

构建 `MaterialApp`，配置：
- 暗色主题（`Brightness.dark`）
- 主色调 `#00C896`（绿色，象征上涨/盈利）
- Material 3 设计
- 自定义 AppBar、Card、Input、Button、SnackBar 主题
- 首页为 `MainShell`

#### `MainShell` - 主导航壳（StatefulWidget）

**核心状态：**
- `_currentIndex`：当前选中的底部导航索引（0-4）
- `_pages`：5 个常量页面实例列表（保持页面状态）

**UI 结构：**
- `Scaffold.body`：根据 `_currentIndex` 切换显示对应页面
- `Scaffold.bottomNavigationBar`：`NavigationBar`（Material 3 风格），5 个 `NavigationDestination`
  - 首页 / 交割单 / K线 / 持仓 / 分析
- `Scaffold.floatingActionButton`：右下角设置按钮（在"分析"页隐藏），跳转 `SettingsPage`

> ⚠️ **注意：** `_pages` 为 `const` 列表，页面实例在应用生命周期内常驻，切换 tab 时不会重建（保留状态），但数据不会自动刷新。各页面在 `initState` 时加载一次数据，需手动下拉刷新或点击刷新按钮。

---

### 5.2 数据访问层 ([DatabaseHelper](file:///workspace/lib/database/database_helper.dart))

#### 类定义：`DatabaseHelper`（单例模式）

```dart
class DatabaseHelper {
  DatabaseHelper._();                              // 私有构造
  static final DatabaseHelper instance = ...;      // 全局单例
  static Database? _database;                      // 懒加载数据库实例
}
```

**初始化流程：**
- `database` getter：懒加载，首次访问时调用 `_initDB()`
- `_initDB()`：在 `getApplicationDocumentsDirectory()` 下创建 `stock_app.db`，版本 1
- `_onCreate()`：建表 + 创建索引
- `_onUpgrade()`：空实现（预留升级迁移）

#### 核心方法清单

| 方法 | 功能 | 操作表 |
|------|------|--------|
| `getDbPath()` | 获取数据库文件路径（用于备份） | - |
| `restoreDb(String backupPath)` | 关闭当前库 → 复制备份 → 重开 | 全部 |
| `getOrCreateStock(code, name)` | 插入或替换股票（自动补全库） | stocks |
| `searchStocks(query)` | 按代码/名称模糊搜索股票 | stocks |
| `addTrade(Map)` | 新增交割单记录 | trades |
| `getTrades({stockCode, limit, offset})` | 查询交割单（可按股票过滤，分页） | trades |
| `deleteTrade(int id)` | 删除指定交割单 | trades |
| `getTradeStats({stockCode})` | 统计买入/卖出笔数与金额 | trades |
| `addKline(Map)` | 新增/替换 K 线数据（UNIQUE 冲突 replace） | kline_data |
| `getKline(stockCode, days)` | 查询最近 N 天 K 线（按日期倒序） | kline_data |
| `getDistinctKlineStocks()` | 获取所有有 K 线的股票去重列表 | kline_data |
| `upsertPosition(Map)` | 持仓 upsert（先删后插） | positions |
| `getPositions()` | 查询所有持仓（按更新时间倒序） | positions |
| `deletePosition(String code)` | 删除指定股票持仓 | positions |
| `addAnalysisLog(Map)` | 记录 AI 分析日志 | analysis_log |
| `getAnalysisLog({limit})` | 查询分析历史（按时间倒序） | analysis_log |
| `getDashboardStats()` | 仪表盘统计（交易数、股票数、K线数、持仓数） | 多表 |
| `getRecentTradesByStock()` | 按股票分组的交易统计 Top 10 | trades |
| `getAllStockCodes()` | 获取股票库全部代码 | stocks |

**关键实现细节：**
- `addTrade` 中净额 `net_amount` 由页面层计算后传入：买入为负（`-(amt+费用)`），卖出为正（`amt-费用`）。
- `getKline` 返回倒序数据，`KlinePage` 中通过 `data.reversed.toList()` 反转为正序展示。
- `upsertPosition` 采用"先 delete 再 insert"方式实现 upsert（因表上有 `UNIQUE(stock_code)`）。
- `addKline` 使用 `ConflictAlgorithm.replace` 处理 `UNIQUE(stock_code, kdate)` 冲突。
- 统计查询大量使用 `COALESCE` 和 `SUM(CASE WHEN ...)` 聚合。

---

### 5.3 页面层 (Pages)

#### HomePage - [home_page.dart](file:///workspace/lib/pages/home_page.dart)

**状态：** `_stats`（仪表盘统计）、`_recentStocks`（活跃股票）、`_loading`

**核心方法：**
- `_loadData()`：并行调用 `getDashboardStats()` + `getRecentTradesByStock()`，支持下拉刷新
- `_statCard(title, value, icon, color)`：构建统计卡片 Widget
- `_stockCard(s)`：构建活跃股票列表项

**UI 组成：** 问候语 AppBar → 欢迎渐变卡片 → 2×2 统计卡片网格 → 活跃股票列表

---

#### TradesPage - [trades_page.dart](file:///workspace/lib/pages/trades_page.dart)

**状态：** 9 个 `TextEditingController`（代码、名称、价格、数量、成交额、佣金、印花税、过户费、备注）+ 交易类型 + 日期 + 时间

**核心方法：**
- `_loadTrades()`：加载交割单列表 + 统计
- `_addTrade()`：核心录入逻辑
  - 自动大写股票代码
  - 自动计算成交额（`price * vol`，保留 2 位小数）
  - 计算 `net_amount`：买入 `-(amt+comm+stamp+transfer)`，卖出 `amt-comm-stamp-transfer`
  - 格式化日期 `yyyy-MM-dd`、时间 `HH:mm:ss`
  - 同步写入 `stocks` 表（自动补全）
  - 清空表单 + 刷新列表
- `_calcAmount()`：实时根据价格×数量计算成交额
- `_deleteTrade(int id)`：二次确认对话框 → 删除
- `_tradeCard(t)`：构建交易卡片（买红卖绿配色）

---

#### KlinePage - [kline_page.dart](file:///workspace/lib/pages/kline_page.dart)

**状态：** 8 个单条录入控制器 + 3 个批量录入控制器 + 选中股票 + 显示开关

**核心方法：**
- `_loadStocks()`：加载有 K 线数据的股票列表
- `_loadKline()`：加载选中股票最近 60 天 K 线，反转后展示
- `_addKline()`：单条录入，自动补全 high/low（缺省用 close）
- `_batchAddKline()`：**批量导入核心**
  - 按行分割，支持 `制表符/逗号/竖线/空格` 分隔
  - 格式：`日期 开盘 收盘 最高 最低 成交量`
  - 逐行解析并 `addKline`（replace 策略去重）
- `_buildViewCard()`：构建 `DataTable`，计算涨跌幅（与前一日收盘对比），红涨绿跌

---

#### PositionsPage - [positions_page.dart](file:///workspace/lib/pages/positions_page.dart)

**状态：** 4 个控制器（代码、名称、数量、成本价）

**核心方法：**
- `_savePosition()`：校验 → `upsertPosition` → 清空 → 刷新
- `_deletePosition(String code)`：确认对话框 → 删除
- `_posCard(p)`：持仓卡片，含 `_tag()` 标签组件

---

#### AnalysisPage - [analysis_page.dart](file:///workspace/lib/pages/analysis_page.dart)

**状态：** 持仓列表、分析日志、两个 loading/result 状态、LLM 配置（API Key、Base URL、Model、Temperature）

**核心方法：**

- `_callLLM(String prompt, {double temp})`：**LLM 调用核心**
  - 端点：`${baseUrl}/v1/chat/completions`（OpenAI 兼容协议）
  - 请求头：`Authorization: Bearer $apiKey`
  - 请求体：`{model, messages:[{role:user, content:prompt}], temperature, max_tokens:4096}`
  - 解析：`data['choices'][0]['message']['content']`
  - 错误处理：API 错误返回状态码+body，网络错误返回异常信息
  - 默认 baseUrl：`https://api.deepseek.com`，默认 model：`deepseek-chat`

- `_analyzeStyle()`：**操作风格分析**
  - 拉取最近 200 条交割单 + 统计
  - 构建 Markdown 表格 prompt（含交易统计 + 最近 50 条记录）
  - 7 维度分析：交易频率、仓位管理、盈亏特征、买入/卖出逻辑、风险偏好、改进建议
  - 写入 `analysis_log`（type=`style`）

- `_analyzeSuggestion()`：**持仓操作建议**
  - 取第一个持仓 + 最近 30 天 K 线 + 近 5 条该股交割单
  - 构建 prompt（持仓信息 + K线表 + 交易记录）
  - 5 维度分析：趋势判断、技术指标、操作建议、风险提示、关键观察点
  - 使用较低温度 `temp=0.5`（更稳定）
  - 写入 `analysis_log`（type=`suggestion`）

- `_showConfigDialog()`：LLM 配置对话框（API 地址、Key、模型、温度滑块）

> ⚠️ **安全提示：** LLM 配置（API Key）仅保存在 `TextEditingController` 内存中，未持久化存储。应用重启后需重新配置。这是当前版本的局限。

---

#### SettingsPage - [settings_page.dart](file:///workspace/lib/pages/settings_page.dart)

**参数：** `isRoot`（是否作为根页面显示，影响 AppBar 关闭按钮）

**核心方法：**
- `_loadDbInfo()`：获取数据库路径与文件大小
- `_backupDb()`：复制 db 文件到 Documents 目录 → 调用 `Share.shareXFiles()` 分享
  - 备份文件名：`stock_app_backup_${timestamp}.db`
  - 分享失败时回退为 SnackBar 提示本地路径
- `_restoreDb()`：确认对话框 → 提示用户将备份文件放至 Documents/`stock_app_restore.db` → 调用 `DatabaseHelper.restoreDb()`
- `_infoRow()` / `_tipItem()`：信息行与提示项 Widget 构建器

---

## 6. 数据模型与数据库设计

数据库文件：`stock_app.db`（位于 `getApplicationDocumentsDirectory()`），SQLite，版本 1。

### 表结构 ER 图

```
┌──────────────────┐     ┌──────────────────────────────┐
│     stocks       │     │           trades              │
├──────────────────┤     ├──────────────────────────────┤
│ code (PK) TEXT   │◄──┐ │ id (PK) AUTOINCREMENT        │
│ name TEXT        │   │ │ stock_code TEXT              │
│ market TEXT      │   └─│ stock_name TEXT              │
│ created_at TEXT  │     │ trade_type TEXT (buy/sell)   │
└──────────────────┘     │ trade_date TEXT              │
                         │ trade_time TEXT              │
┌──────────────────┐     │ price REAL                   │
│   positions      │     │ volume INTEGER               │
├──────────────────┤     │ amount REAL                   │
│ id (PK) AUTOINC  │     │ commission REAL              │
│ stock_code UNIQUE│─────│ stamp_tax REAL               │
│ stock_name TEXT  │     │ transfer_fee REAL            │
│ volume INTEGER   │     │ net_amount REAL              │
│ cost_price REAL  │     │ notes TEXT                   │
│ updated_at TEXT  │     │ created_at TEXT              │
└──────────────────┘     └──────────────────────────────┘
                                       索引:
┌────────────────────────────┐         idx_trades_stock
│        kline_data           │         idx_trades_date
├────────────────────────────┤
│ id (PK) AUTOINCREMENT      │ ┌──────────────────────────┐
│ stock_code TEXT            │ │     analysis_log          │
│ stock_name TEXT            │ ├──────────────────────────┤
│ kdate TEXT                 │ │ id (PK) AUTOINCREMENT    │
│ open REAL                  │ │ stock_code TEXT          │
│ close REAL                 │ │ analysis_type TEXT       │
│ high REAL                  │ │ prompt TEXT              │
│ low REAL                   │ │ response TEXT            │
│ volume REAL                │ │ created_at TEXT          │
│ amount REAL                │ └──────────────────────────┘
│ UNIQUE(stock_code, kdate)  │
└────────────────────────────┘
        索引: idx_kline_stock
```

### 字段说明

**trades 表（交割单）**
| 字段 | 类型 | 说明 |
|------|------|------|
| trade_type | TEXT | `buy` 或 `sell`（CHECK 约束） |
| price | REAL | 成交价 |
| volume | INTEGER | 成交量（股） |
| amount | REAL | 成交额（price × volume） |
| commission | REAL | 佣金 |
| stamp_tax | REAL | 印花税 |
| transfer_fee | REAL | 过户费 |
| net_amount | REAL | 净额（买入为负，卖出为正） |

**kline_data 表（K线）**
- `UNIQUE(stock_code, kdate)`：同一股票同一日期唯一，冲突时 replace
- `open/close/high/low`：OHLC 价格
- `volume`：成交量（手）

**positions 表（持仓）**
- `UNIQUE(stock_code)`：每股仅一条持仓记录
- upsert 实现：先 delete 再 insert

**analysis_log 表（分析日志）**
- `analysis_type`：`style`（风格分析）或 `suggestion`（操作建议）
- `prompt` / `response`：完整请求与响应文本

---

## 7. 依赖关系

### 直接依赖 ([pubspec.yaml](file:///workspace/pubspec.yaml))

| 依赖 | 版本 | 用途 |
|------|------|------|
| `flutter` | sdk | 框架核心 |
| `cupertino_icons` | ^1.0.8 | iOS 风格图标 |
| `sqflite` | ^2.3.0 | SQLite 数据库访问 |
| `path` | ^1.9.0 | 路径拼接（数据库文件路径） |
| `path_provider` | ^2.1.2 | 获取应用文档目录 |
| `http` | ^1.2.1 | HTTP 请求（调用 LLM API） |
| `intl` | ^0.19.0 | 日期/数字格式化（`DateFormat`、`NumberFormat`） |
| `share_plus` | ^9.0.0 | 系统分享（数据库备份文件分享） |

### 开发依赖

| 依赖 | 版本 | 用途 |
|------|------|------|
| `flutter_test` | sdk | Widget 测试框架 |
| `flutter_lints` | ^5.0.0 | Dart/Flutter 代码规范检查 |

### 模块间依赖关系图

```
main.dart
  ├── database/database_helper.dart  (强依赖，启动时初始化)
  └── pages/*
        ├── home_page.dart        → database_helper
        ├── trades_page.dart      → database_helper, intl
        ├── kline_page.dart       → database_helper, intl
        ├── positions_page.dart   → database_helper
        ├── analysis_page.dart    → database_helper, http, intl
        └── settings_page.dart    → database_helper, path_provider, share_plus
```

### 平台构建依赖

- **Android**：Gradle 8.3、AGP 8.1.0、Kotlin 1.8.22、Android SDK 34、build-tools 34.0.0、Java 17
- **阿里云 Maven 镜像**：`settings.gradle` 与 Dockerfile 中均配置了 `maven.aliyun.com` 加速国内依赖下载

---

## 8. 主题与视觉设计

应用采用 **深色金融风格** 主题，配色专业且一致。

### 色彩规范

| 色值 | 用途 |
|------|------|
| `#0F1923` | Scaffold 背景色（深蓝黑） |
| `#0A1929` | AppBar / NavigationBar 背景（更深） |
| `#1A2634` | Card 背景 / Dialog 背景 |
| `#0D1824` | 输入框填充 / 结果框背景 |
| `#2A3A4A` | 边框色（Card、Input） |
| `#00C896` | **主色调**（强调、买入按钮、选中态、品牌色） |
| `#EF5350` | **红色**（买入标记、上涨、删除） |
| `#8899AA` | 次要文字色（灰色） |
| `#4FC3F7` | 蓝色标签（数量） |
| `#FFA726` | 橙色标签（成本价、警告、操作建议） |
| `#66BB6A` | 绿色统计图标 |

> 📌 **色彩约定：** 遵循 A 股习惯，**红色代表上涨/买入**，**绿色代表下跌/卖出**（与欧美市场相反）。

### 主题配置（[main.dart](file:///workspace/lib/main.dart#L28-L79)）

- `brightness: Brightness.dark`
- `colorSchemeSeed: Color(0xFF00C896)`（Material 3 色彩生成种子）
- `useMaterial3: true`
- 自定义 `AppBarTheme`、`CardThemeData`、`InputDecorationTheme`、`ElevatedButtonThemeData`、`SnackBarThemeData`
- 圆角统一为 8-12px

---

## 9. 构建与部署

### 9.1 Docker 容器化编译（推荐）

**Dockerfile ([docker/Dockerfile](file:///workspace/docker/Dockerfile)) 构建内容：**
- 基础镜像：`ubuntu:22.04`
- 安装：curl、git、unzip、Java 17（openjdk-17-jdk-headless）
- Flutter SDK：3.27.4 stable（解压至 `/opt/flutter`）
- Android SDK：cmdline-tools latest + platforms;android-34 + build-tools;34.0.0 + platform-tools
- Gradle 阿里云镜像配置（`~/.gradle/init.d/mirrors.gradle`）
- `flutter doctor` 自动接受 Android licenses

**docker-compose.yml ([docker/docker-compose.yml](file:///workspace/docker/docker-compose.yml))**
- 服务名：`stock-builder`
- 挂载源码：`/vol1/@apphome/trim.openclaw/data/workspace/stock_app:/app`（⚠️ 需按实际路径修改）
- 编译完成自动退出

**编译入口 ([docker/build-entrypoint.sh](file:///workspace/docker/build-entrypoint.sh))**
1. 检查 `/app/pubspec.yaml` 是否存在
2. `flutter pub get` 安装依赖
3. `flutter build apk --debug` 编译 Debug APK
4. 输出 APK 路径：`/app/build/app/outputs/flutter-apk/app-debug.apk`

### 9.2 本地直连编译

**[build_apk.sh](file:///workspace/build_apk.sh)**（Linux/Mac）：
- 检查 Flutter 与 Java 17+ 环境
- `flutter pub get` → 接受 Android licenses → `flutter build apk --debug`
- 输出 APK 大小与路径

### 9.3 GitHub Actions CI/CD

**[.github/workflows/build-apk.yml](file:///workspace/.github/workflows/build-apk.yml)**

- **触发条件：** push 到 `master` 分支，或手动 `workflow_dispatch`
- **运行环境：** `ubuntu-latest`
- **步骤：**
  1. `actions/checkout@v4` 检出代码
  2. `subosito/flutter-action@v2` 安装 Flutter 3.27.4 stable
  3. `flutter pub get` 安装依赖
  4. `flutter build apk --debug` 编译
  5. `actions/upload-artifact@v4` 上传 artifact（名称：`stock-app-debug`）

### 9.4 编译产物

```
build/app/outputs/flutter-apk/app-debug.apk
```

> ⚠️ 当前仅构建 **Debug** 版本。Release 版本需在 [android/app/build.gradle](file:///workspace/android/app/build.gradle#L33-L39) 中配置正式签名（当前使用 debug 签名）。

---

## 10. 项目运行方式

### 10.1 环境要求

- **Flutter SDK**：3.27.4（stable），Dart ^3.6.2
- **Java**：JDK 17+
- **Android SDK**：compileSdk 34（minSdk/targetSdk 由 Flutter 默认值决定）
- **Gradle**：8.3

### 10.2 开发运行

```bash
# 1. 安装依赖
flutter pub get

# 2. 运行（连接设备/模拟器）
flutter run

# 3. 指定平台运行
flutter run -d chrome       # Web
flutter run -d android      # Android
flutter run -d windows      # Windows
```

### 10.3 编译 APK

**方式一：Docker（无需本地安装 Flutter）**
```bash
# 首次：构建镜像 + 编译
bash docker/build.sh

# 后续：仅编译
bash docker/build.sh build
```
Windows 用户：`docker\build.bat`

**方式二：本地直连编译**
```bash
bash build_apk.sh
```

**方式三：手动 Flutter 命令**
```bash
flutter pub get
flutter build apk --debug
```

### 10.4 数据库备份与恢复

- **备份**：设置页 → 「备份到...」→ 系统分享菜单导出 `.db` 文件
- **恢复**：将备份文件重命名为 `stock_app_restore.db` 放入应用 Documents 目录 → 设置页 → 「从备份恢复」→ 重启应用

### 10.5 AI 分析配置

1. 进入「分析」页 → 点击右上角 ⚙️ 设置图标
2. 填写：
   - API 地址（默认 `https://api.deepseek.com`）
   - API Key（如 DeepSeek 的 `sk-...`）
   - 模型名（默认 `deepseek-chat`）
   - 温度（0-2，默认 0.7）
3. 保存后即可使用「操作风格分析」与「操作建议」

> ⚠️ API Key 仅保存在内存中，应用重启需重新配置。

### 10.6 代码检查与测试

```bash
# 静态分析
flutter analyze

# 运行测试
flutter test
```

---

## 11. 已知问题与改进建议

### 已知问题

1. **Widget 测试失效**：[test/widget_test.dart](file:///workspace/test/widget_test.dart) 引用 `MyApp` 与计数器逻辑，但 `main.dart` 中根 Widget 已改为 `StockApp`，测试无法编译通过。需更新为针对 `StockApp` 的测试。

2. **页面数据不自动刷新**：`MainShell._pages` 为 `const` 列表，切换 tab 不触发 `initState`，导致在 A 页面录入数据后切到 B 页面可能看不到最新数据（需手动下拉刷新）。

3. **LLM 配置不持久化**：API Key 等配置仅存在内存中，应用重启丢失。建议使用 `shared_preferences` 或加密存储。

4. **交割单过滤器未实现**：[trades_page.dart](file:///workspace/lib/pages/trades_page.dart#L191-L194) 的 `PopupMenuButton` 仅包含"全部股票"一项，未动态加载股票列表。

5. **恢复流程繁琐**：数据库恢复需用户手动将文件放到指定目录并重命名，未使用文件选择器（如 `file_picker`）。

6. **Docker compose 路径硬编码**：[docker-compose.yml](file:///workspace/docker/docker-compose.yml#L13) 中 volumes 路径为绝对路径，需按实际环境修改。

7. **无 Release 签名配置**：仅 Debug 构建，无法发布到应用商店。

8. **`_onUpgrade` 空实现**：数据库版本升级时无迁移逻辑，若修改表结构会丢数据。

### 改进建议

- 引入轻量状态管理（如 `Provider`）解决跨页面数据同步问题
- 使用 `shared_preferences` 持久化 LLM 配置
- 引入 `file_picker` 改善备份恢复体验
- 补充单元测试与集成测试
- 配置 Release 签名以支持正式发布
- 实现数据库版本迁移逻辑
- K 线图表可视化（当前仅 DataTable 展示，可引入 `fl_chart` 绘制 candlestick）

---

> 📄 **文档版本：** v1.0 · 基于源码静态分析生成 · 最后更新：2026-07-15
