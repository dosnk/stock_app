import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';

class SettingsPage extends StatefulWidget {
  final bool isRoot;
  const SettingsPage({super.key, this.isRoot = false});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? _dbPath;
  int? _dbSize;
  bool _backingUp = false;
  bool _restoring = false;

  @override
  void initState() {
    super.initState();
    _loadDbInfo();
  }

  Future<void> _loadDbInfo() async {
    try {
      final path = await DatabaseHelper.instance.getDbPath();
      final file = File(path);
      setState(() {
        _dbPath = path;
        _dbSize = file.lengthSync();
      });
    } catch (_) {}
  }

  Future<void> _backupDb() async {
    setState(() => _backingUp = true);
    try {
      final path = await DatabaseHelper.instance.getDbPath();
      final file = File(path);
      final dir = await getApplicationDocumentsDirectory();
      final backupName =
          'stock_app_backup_${DateTime.now().millisecondsSinceEpoch}.db';
      final backupPath = '${dir.path}/$backupName';
      await file.copy(backupPath);

      // 尝试直接分享
      try {
        await Share.shareXFiles(
          [XFile(backupPath)],
          text: '📈 股票交易助手 - 数据库备份',
        );
      } catch (_) {
        // 如果分享失败，至少备份到本地
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ 备份到: $backupPath')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 备份失败: $e')),
        );
      }
    }
    setState(() => _backingUp = false);
  }

  Future<void> _restoreDb() async {
    setState(() => _restoring = true);
    try {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A2634),
          title: const Text('⚠️ 恢复数据库'),
          content: const Text(
              '恢复操作将覆盖当前所有数据，且不可撤销。\n确定继续？'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('恢复',
                  style: TextStyle(color: Color(0xFFFFA726))),
            ),
          ],
        ),
      );
      if (confirm != true) {
        setState(() => _restoring = false);
        return;
      }

      // 通过文件选择器选择备份文件
      // 使用 file_picker 或者简单的路径输入
      // 这里简化：提示用户使用 file_picker（实际需要额外权限）
      // 先提示手动操作
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A2634),
            title: const Text('📂 选择备份文件'),
            content: const Text(
              '请将备份的 .db 文件放到手机存储的 Downloads 目录下，\n命名为 stock_app_restore.db，然后点击确认。',
              style: TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('取消')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    final dir = await getApplicationDocumentsDirectory();
                    final restoreFile =
                        File('${dir.path}/stock_app_restore.db');
                    if (!restoreFile.existsSync()) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('❌ 未找到恢复文件')),
                        );
                      }
                      setState(() => _restoring = false);
                      return;
                    }
                    await DatabaseHelper.instance.restoreDb(
                        restoreFile.path);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('✅ 数据库已恢复，请重启应用')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('❌ 恢复失败: $e')),
                      );
                    }
                  }
                  setState(() => _restoring = false);
                },
                child: const Text('确认恢复'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 恢复失败: $e')),
        );
      }
      setState(() => _restoring = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sizeStr = _dbSize != null
        ? '${(_dbSize! / 1024).toStringAsFixed(1)} KB'
        : '未知';

    return Scaffold(
      appBar: AppBar(
        title: const Text('⚙️ 设置'),
        actions: widget.isRoot
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF8899AA)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 数据库信息
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🗄️ 数据库',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _infoRow('存储位置', _dbPath ?? '加载中...'),
                  _infoRow('数据库大小', sizeStr),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 备份与恢复
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💾 备份与恢复',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('备份数据库到其他位置，或从备份恢复',
                      style:
                          TextStyle(color: Color(0xFF8899AA), fontSize: 12)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _backingUp ? null : _backupDb,
                      icon: _backingUp
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0A1929)))
                          : const Icon(Icons.backup),
                      label: Text(_backingUp ? '备份中...' : '📤 备份到...'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _restoring ? null : _restoreDb,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFFA726),
                        side: const BorderSide(color: Color(0xFFFFA726)),
                      ),
                      icon: _restoring
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFFFA726)))
                          : const Icon(Icons.restore),
                      label: Text(_restoring ? '恢复中...' : '📥 从备份恢复'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 关于
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ℹ️ 关于',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _infoRow('应用名称', '📈 股票交易助手'),
                  _infoRow('版本', 'v1.0.0'),
                  _infoRow('数据存储', '本地 SQLite（不上传云端）'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 提示
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 使用提示',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  _tipItem('1', '录入交割单时，成交额会自动计算'),
                  _tipItem('2', 'K线数据支持批量粘贴导入'),
                  _tipItem('3', 'AI分析需要先配置LLM API'),
                  _tipItem('4', '定期备份数据库到NAS或电脑'),
                  _tipItem('5', '所有数据仅在本地，安全可靠'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label,
                style: const TextStyle(
                    color: Color(0xFF8899AA), fontSize: 13)),
          ),
          Expanded(
            child: SelectableText(value,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _tipItem(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFF00C896).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(num,
                  style: const TextStyle(
                      color: Color(0xFF00C896),
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
