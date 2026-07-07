import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class PositionsPage extends StatefulWidget {
  const PositionsPage({super.key});

  @override
  State<PositionsPage> createState() => _PositionsPageState();
}

class _PositionsPageState extends State<PositionsPage> {
  List<Map<String, dynamic>> _positions = [];
  bool _loading = true;

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _volCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPositions();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _volCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPositions() async {
    setState(() => _loading = true);
    final data = await DatabaseHelper.instance.getPositions();
    if (mounted) setState(() { _positions = data; _loading = false; });
  }

  Future<void> _savePosition() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();
    final vol = int.tryParse(_volCtrl.text) ?? 0;
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    if (code.isEmpty || vol <= 0 || cost <= 0) {
      _showSnack('请完整填写持仓信息');
      return;
    }
    await DatabaseHelper.instance.upsertPosition({
      'stock_code': code,
      'stock_name': name,
      'volume': vol,
      'cost_price': cost,
    });
    _codeCtrl.clear();
    _nameCtrl.clear();
    _volCtrl.clear();
    _costCtrl.clear();
    _showSnack('✅ 持仓已保存');
    _loadPositions();
  }

  Future<void> _deletePosition(String code) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2634),
        title: const Text('确认删除'),
        content: Text('确定删除 $code 的持仓记录？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFEF5350))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deletePosition(code);
      _showSnack('🗑️ 持仓已删除');
      _loadPositions();
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('💼 持仓管理')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C896)))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 添加表单
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('录入/更新持仓',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _codeCtrl,
                                decoration: const InputDecoration(
                                    labelText: '代码', hintText: '000001.SZ'),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                    labelText: '名称', hintText: '股票名称'),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _volCtrl,
                                decoration: const InputDecoration(
                                    labelText: '数量(股)',
                                    hintText: '0'),
                                keyboardType: TextInputType.number,
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _costCtrl,
                                decoration: const InputDecoration(
                                    labelText: '成本价',
                                    hintText: '0.000'),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _savePosition,
                            icon: const Icon(Icons.save),
                            label: const Text('保存持仓'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 持仓列表
                const Text('当前持仓',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (_positions.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(Icons.work_outline,
                              size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 12),
                          Text('暂无持仓记录',
                              style: TextStyle(color: Colors.grey[500])),
                        ],
                      ),
                    ),
                  )
                else
                  ..._positions.map((p) => _posCard(p)),
              ],
            ),
    );
  }

  Widget _posCard(Map<String, dynamic> p) {
    final code = p['stock_code'] ?? '';
    final name = p['stock_name'] ?? '';
    final vol = p['volume'] ?? 0;
    final cost = (p['cost_price'] as num?)?.toDouble() ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(code,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      if (name.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(name,
                            style: const TextStyle(
                                color: Color(0xFF8899AA), fontSize: 13)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _tag('${vol}股',
                          const Color(0xFF4FC3F7)),
                      const SizedBox(width: 8),
                      _tag('成本 ¥${cost.toStringAsFixed(3)}',
                          const Color(0xFFFFA726)),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Color(0xFFEF5350), size: 20),
              onPressed: () => _deletePosition(code),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }
}
