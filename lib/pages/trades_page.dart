import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class TradesPage extends StatefulWidget {
  const TradesPage({super.key});

  @override
  State<TradesPage> createState() => _TradesPageState();
}

class _TradesPageState extends State<TradesPage> {
  List<Map<String, dynamic>> _trades = [];
  Map<String, dynamic> _stats = {};
  String? _filterStock;
  bool _loading = true;

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _volCtrl = TextEditingController();
  final _amtCtrl = TextEditingController();
  final _commCtrl = TextEditingController();
  final _stampCtrl = TextEditingController();
  final _transferCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _tradeType = 'buy';
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _useTime = false;

  @override
  void initState() {
    super.initState();
    _loadTrades();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _volCtrl.dispose();
    _amtCtrl.dispose();
    _commCtrl.dispose();
    _stampCtrl.dispose();
    _transferCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTrades() async {
    setState(() => _loading = true);
    try {
      final trades =
          await DatabaseHelper.instance.getTrades(stockCode: _filterStock);
      final stats =
          await DatabaseHelper.instance.getTradeStats(stockCode: _filterStock);
      if (mounted) {
        setState(() {
          _trades = trades;
          _stats = stats;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addTrade() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final vol = int.tryParse(_volCtrl.text) ?? 0;
    // 自动计算成交额
    var amt = double.tryParse(_amtCtrl.text) ?? 0;
    if (amt <= 0 && price > 0 && vol > 0) {
      amt = (price * vol * 100).round() / 100;
    }
    final comm = double.tryParse(_commCtrl.text) ?? 0;
    final stamp = double.tryParse(_stampCtrl.text) ?? 0;
    final transfer = double.tryParse(_transferCtrl.text) ?? 0;

    if (code.isEmpty || price <= 0 || vol <= 0) {
      _showSnack('请填写必填字段');
      return;
    }

    final net = _tradeType == 'buy'
        ? -(amt + comm + stamp + transfer)
        : (amt - comm - stamp - transfer);

    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final timeStr = _useTime
        ? '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00'
        : '';

    await DatabaseHelper.instance.addTrade({
      'stock_code': code,
      'stock_name': name,
      'trade_type': _tradeType,
      'trade_date': dateStr,
      'trade_time': timeStr,
      'price': price,
      'volume': vol,
      'amount': amt,
      'commission': comm,
      'stamp_tax': stamp,
      'transfer_fee': transfer,
      'net_amount': net,
      'notes': _notesCtrl.text,
    });

    // 自动保存到股票库
    await DatabaseHelper.instance.getOrCreateStock(code, name);

    // 清空
    _codeCtrl.clear();
    _nameCtrl.clear();
    _priceCtrl.clear();
    _volCtrl.clear();
    _amtCtrl.clear();
    _commCtrl.clear();
    _stampCtrl.clear();
    _transferCtrl.clear();
    _notesCtrl.clear();
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();
    _useTime = false;

    _showSnack('✅ 交割单已添加');
    _loadTrades();
  }

  Future<void> _deleteTrade(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2634),
        title: const Text('确认删除'),
        content: const Text('确定删除这条交割单？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Color(0xFFEF5350))),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseHelper.instance.deleteTrade(id);
      _showSnack('🗑️ 交割单已删除');
      _loadTrades();
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _calcAmount() {
    final p = double.tryParse(_priceCtrl.text) ?? 0;
    final v = int.tryParse(_volCtrl.text) ?? 0;
    if (p > 0 && v > 0) {
      _amtCtrl.text = ((p * v * 100).round() / 100).toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final buyCnt = _stats['buy_count'] ?? 0;
    final sellCnt = _stats['sell_count'] ?? 0;
    final buyAmt = (_stats['buy_amount'] as num?)?.toDouble() ?? 0;
    final sellAmt = (_stats['sell_amount'] as num?)?.toDouble() ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📋 交割单'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list, color: Color(0xFF8899AA)),
            onSelected: (v) {
              setState(() => _filterStock = v.isEmpty ? null : v);
              _loadTrades();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: '', child: Text('全部股票')),
              // 实际应该从数据库加载，简单起见只放这个
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00C896)))
          : RefreshIndicator(
              onRefresh: _loadTrades,
              color: const Color(0xFF00C896),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 快速统计
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text('买入',
                                    style: TextStyle(
                                        color: Color(0xFFEF5350),
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('$buyCnt 笔',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                                Text('¥${NumberFormat('#,##0').format(buyAmt)}',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 11)),
                              ],
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 40,
                            color: const Color(0xFF2A3A4A),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('卖出',
                                    style: TextStyle(
                                        color: Color(0xFF00C896),
                                        fontSize: 12)),
                                const SizedBox(height: 4),
                                Text('$sellCnt 笔',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18)),
                                Text('¥${NumberFormat('#,##0').format(sellAmt)}',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 录入表单
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('录入交割单',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 16),
                          // 股票代码+名称
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _codeCtrl,
                                  decoration: const InputDecoration(
                                      labelText: '代码',
                                      hintText: '000001.SZ'),
                                  style: const TextStyle(fontSize: 14),
                                  onChanged: (v) => _calcAmount(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(
                                      labelText: '名称',
                                      hintText: '自动补全'),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // 类型 + 日期 + 时间
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  value: _tradeType,
                                  decoration: const InputDecoration(
                                      labelText: '类型'),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'buy',
                                        child: Text('买入',
                                            style: TextStyle(
                                                color: Color(0xFFEF5350)))),
                                    DropdownMenuItem(
                                        value: 'sell',
                                        child: Text('卖出',
                                            style: TextStyle(
                                                color: Color(0xFF00C896)))),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _tradeType = v!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: InkWell(
                                  onTap: () async {
                                    final d = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate:
                                          DateTime(2000),
                                      lastDate: DateTime.now(),
                                      builder: (ctx, child) => Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme:
                                              const ColorScheme.dark(
                                            primary: Color(0xFF00C896),
                                          ),
                                        ),
                                        child: child!,
                                      ),
                                    );
                                    if (d != null) {
                                      setState(() => _selectedDate = d);
                                    }
                                  },
                                  child: InputDecorator(
                                    decoration: const InputDecoration(
                                        labelText: '日期'),
                                    child: Text(
                                      DateFormat('yyyy-MM-dd')
                                          .format(_selectedDate),
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // 价格 + 数量
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _priceCtrl,
                                  decoration: const InputDecoration(
                                      labelText: '价格',
                                      hintText: '0.000'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: const TextStyle(fontSize: 14),
                                  onChanged: (v) => _calcAmount(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _volCtrl,
                                  decoration: const InputDecoration(
                                      labelText: '数量(股)',
                                      hintText: '0'),
                                  keyboardType: TextInputType.number,
                                  style: const TextStyle(fontSize: 14),
                                  onChanged: (v) => _calcAmount(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _amtCtrl,
                                  decoration: const InputDecoration(
                                      labelText: '成交额',
                                      hintText: '自动计算'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // 费用
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _commCtrl,
                                  decoration: const InputDecoration(
                                      labelText: '佣金', hintText: '0'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _stampCtrl,
                                  decoration: const InputDecoration(
                                      labelText: '印花税', hintText: '0'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _transferCtrl,
                                  decoration: const InputDecoration(
                                      labelText: '过户费', hintText: '0'),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _notesCtrl,
                            decoration: const InputDecoration(
                                labelText: '备注(选填)',
                                hintText: '操作原因、策略等'),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _addTrade,
                              icon: const Icon(Icons.add),
                              label: Text(_tradeType == 'buy' ? '添加买入记录' : '添加卖出记录'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 交割单列表
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('交易记录',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      Text('共 ${_trades.length} 条',
                          style: const TextStyle(
                              color: Color(0xFF8899AA), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_trades.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 48, color: Colors.grey[600]),
                            const SizedBox(height: 12),
                            Text('还没有交割单记录',
                                style: TextStyle(color: Colors.grey[500])),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._trades.map((t) => _tradeCard(t)),
                ],
              ),
            ),
    );
  }

  Widget _tradeCard(Map<String, dynamic> t) {
    final isBuy = t['trade_type'] == 'buy';
    final color = isBuy ? const Color(0xFFEF5350) : const Color(0xFF00C896);
    final typeLabel = isBuy ? '买入' : '卖出';
    final date = t['trade_date'] ?? '';
    final time = t['trade_time'] ?? '';
    final price = (t['price'] as num?)?.toDouble() ?? 0;
    final vol = t['volume'] ?? 0;
    final amt = (t['amount'] as num?)?.toDouble() ?? 0;
    final code = t['stock_code'] ?? '';
    final name = t['stock_name'] ?? '';
    final notes = t['notes'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(typeLabel,
                      style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                Text('$code',
                    style:
                        const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (name.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(name,
                      style: const TextStyle(
                          color: Color(0xFF8899AA), fontSize: 12)),
                ],
                const Spacer(),
                Text('$date ${time.isNotEmpty ? time : ''}',
                    style: const TextStyle(
                        color: Color(0xFF8899AA), fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('¥${price.toStringAsFixed(3)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(width: 12),
                Text('$vol 股',
                    style: const TextStyle(
                        color: Color(0xFF8899AA), fontSize: 13)),
                const SizedBox(width: 12),
                Text('¥${NumberFormat('#,##0.00').format(amt)}',
                    style: const TextStyle(
                        color: Color(0xFF8899AA), fontSize: 13)),
                const Spacer(),
                InkWell(
                  onTap: () => _deleteTrade(t['id']),
                  child: const Icon(Icons.delete_outline,
                      color: Color(0xFFEF5350), size: 18),
                ),
              ],
            ),
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('📝 $notes',
                  style: const TextStyle(
                      color: Color(0xFF8899AA), fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}
