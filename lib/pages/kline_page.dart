import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class KlinePage extends StatefulWidget {
  const KlinePage({super.key});

  @override
  State<KlinePage> createState() => _KlinePageState();
}

class _KlinePageState extends State<KlinePage> {
  List<Map<String, dynamic>> _klineData = [];
  List<Map<String, dynamic>> _stockList = [];
  String? _selectedStock;
  bool _loading = true;
  bool _showForm = true;
  bool _showBatch = false;

  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _openCtrl = TextEditingController();
  final _closeCtrl = TextEditingController();
  final _highCtrl = TextEditingController();
  final _lowCtrl = TextEditingController();
  final _volCtrl = TextEditingController();

  final _batchCodeCtrl = TextEditingController();
  final _batchNameCtrl = TextEditingController();
  final _batchDataCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _loadStocks();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _dateCtrl.dispose();
    _openCtrl.dispose();
    _closeCtrl.dispose();
    _highCtrl.dispose();
    _lowCtrl.dispose();
    _volCtrl.dispose();
    _batchCodeCtrl.dispose();
    _batchNameCtrl.dispose();
    _batchDataCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStocks() async {
    _stockList = await DatabaseHelper.instance.getDistinctKlineStocks();
    if (mounted) setState(() {});
    if (_selectedStock != null) _loadKline();
  }

  Future<void> _loadKline() async {
    if (_selectedStock == null) return;
    setState(() => _loading = true);
    final data = await DatabaseHelper.instance.getKline(_selectedStock!, 60);
    if (mounted) {
      setState(() {
        _klineData = data.reversed.toList();
        _loading = false;
      });
    }
  }

  Future<void> _addKline() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    final name = _nameCtrl.text.trim();
    final kdate = _dateCtrl.text;
    final open = double.tryParse(_openCtrl.text) ?? 0;
    final close = double.tryParse(_closeCtrl.text) ?? 0;
    final high = double.tryParse(_highCtrl.text) ?? 0;
    final low = double.tryParse(_lowCtrl.text) ?? 0;
    final vol = double.tryParse(_volCtrl.text) ?? 0;

    if (code.isEmpty || kdate.isEmpty || open <= 0 || close <= 0) {
      _showSnack('请填写必填字段（代码、日期、开盘、收盘）');
      return;
    }

    await DatabaseHelper.instance.addKline({
      'stock_code': code,
      'stock_name': name,
      'kdate': kdate,
      'open': open,
      'close': close,
      'high': high > 0 ? high : close,
      'low': low > 0 ? low : close,
      'volume': vol,
    });

    // 自动保存到股票库
    await DatabaseHelper.instance.getOrCreateStock(code, name);

    _codeCtrl.clear();
    _nameCtrl.clear();
    _dateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _openCtrl.clear();
    _closeCtrl.clear();
    _highCtrl.clear();
    _lowCtrl.clear();
    _volCtrl.clear();

    _showSnack('✅ K线数据已添加');
    _loadStocks();
    _selectedStock = code;
    _loadKline();
  }

  Future<void> _batchAddKline() async {
    final code = _batchCodeCtrl.text.trim().toUpperCase();
    final name = _batchNameCtrl.text.trim();
    final raw = _batchDataCtrl.text.trim();

    if (code.isEmpty || raw.isEmpty) {
      _showSnack('请填写股票代码和数据');
      return;
    }

    final lines = raw.split('\n');
    int added = 0;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final parts = trimmed.split(RegExp(r'[\t,| ]+'));
      if (parts.length < 5) continue;
      final kdate = parts[0];
      final open = double.tryParse(parts[1]) ?? 0;
      final close = double.tryParse(parts[2]) ?? 0;
      final high = double.tryParse(parts[3]) ?? 0;
      final low = double.tryParse(parts[4]) ?? 0;
      final vol = parts.length > 5 ? (double.tryParse(parts[5]) ?? 0) : 0;
      if (kdate.isEmpty || open <= 0 || close <= 0) continue;

      await DatabaseHelper.instance.addKline({
        'stock_code': code,
        'stock_name': name,
        'kdate': kdate,
        'open': open,
        'close': close,
        'high': high > 0 ? high : close,
        'low': low > 0 ? low : close,
        'volume': vol,
      });
      added++;
    }

    if (name.isNotEmpty) {
      await DatabaseHelper.instance.getOrCreateStock(code, name);
    }

    _showSnack('✅ 成功导入 $added 条K线数据');
    setState(() => _showBatch = false);
    _batchCodeCtrl.clear();
    _batchNameCtrl.clear();
    _batchDataCtrl.clear();
    _loadStocks();
    _selectedStock = code;
    _loadKline();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 K线数据'),
        actions: [
          IconButton(
            icon: Icon(_showBatch ? Icons.edit_note : Icons.paste,
                color: const Color(0xFF8899AA)),
            onPressed: () => setState(() => _showBatch = !_showBatch),
            tooltip: '批量录入',
          ),
          IconButton(
            icon: Icon(_showForm ? Icons.unfold_less : Icons.unfold_more,
                color: const Color(0xFF8899AA)),
            onPressed: () => setState(() => _showForm = !_showForm),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 批量录入
          if (_showBatch) _buildBatchForm(),

          // 单条录入
          if (_showForm) _buildSingleForm(),

          const SizedBox(height: 16),

          // 查看
          _buildViewCard(),
        ],
      ),
    );
  }

  Widget _buildSingleForm() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('单条录入',
                style:
                    TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
            TextField(
              controller: _dateCtrl,
              decoration: const InputDecoration(
                  labelText: '日期',
                  hintText: 'YYYY-MM-DD',
                  suffixIcon: Icon(Icons.calendar_today, size: 18)),
              style: const TextStyle(fontSize: 14),
              readOnly: true,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                  builder: (ctx, child) => Theme(
                    data: Theme.of(context)
                        .copyWith(colorScheme: const ColorScheme.dark(
                            primary: Color(0xFF00C896))),
                    child: child!,
                  ),
                );
                if (d != null) {
                  _dateCtrl.text = DateFormat('yyyy-MM-dd').format(d);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _openCtrl,
                        decoration: const InputDecoration(
                            labelText: '开盘', hintText: '0.000'),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _closeCtrl,
                        decoration: const InputDecoration(
                            labelText: '收盘', hintText: '0.000'),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _highCtrl,
                        decoration: const InputDecoration(
                            labelText: '最高', hintText: '0.000'),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14))),
                const SizedBox(width: 8),
                Expanded(
                    child: TextField(
                        controller: _lowCtrl,
                        decoration: const InputDecoration(
                            labelText: '最低', hintText: '0.000'),
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 14))),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _volCtrl,
                    decoration: const InputDecoration(
                        labelText: '成交量(手)', hintText: '0'),
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _addKline,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('添加'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBatchForm() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📥 批量录入',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF8899AA)),
                  onPressed: () => setState(() => _showBatch = false),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _batchCodeCtrl,
                    decoration: const InputDecoration(
                        labelText: '代码', hintText: '000001.SZ'),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _batchNameCtrl,
                    decoration: const InputDecoration(
                        labelText: '名称', hintText: '股票名称'),
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _batchDataCtrl,
              maxLines: 8,
              decoration: const InputDecoration(
                hintText:
                    '一行一条，制表符/逗号/空格分隔\n日期  开盘  收盘  最高  最低  成交量\n2026-01-02  10.50  10.80  10.90  10.40  20000\n2026-01-03  10.80  10.60  11.00  10.50  18000',
                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF556677)),
              ),
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _batchAddKline,
                icon: const Icon(Icons.paste),
                label: const Text('批量导入'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('K线数据',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _selectedStock,
                decoration: const InputDecoration(
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                hint: const Text('选择股票', style: TextStyle(fontSize: 13)),
                isExpanded: true,
                items: _stockList
                    .map((s) => DropdownMenuItem(
                          value: s['stock_code'],
                          child: Text(
                            '${s['stock_code']} ${s['stock_name'] ?? ''}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ))
                    .cast<DropdownMenuItem<String>>()
                .toList(),
                onChanged: (v) {
                  setState(() => _selectedStock = v);
                  _loadKline();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_selectedStock == null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.show_chart_outlined,
                      size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 12),
                  Text('选择股票查看K线数据',
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          )
        else if (_loading)
          const Center(
              child:
                  Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: Color(0xFF00C896))))
        else if (_klineData.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined,
                      size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 12),
                  Text('暂无K线数据',
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                      const Color(0xFF0D1824)),
                  columns: const [
                    DataColumn(label: Text('日期', style: TextStyle(fontSize: 11))),
                    DataColumn(label: Text('开盘', style: TextStyle(fontSize: 11))),
                    DataColumn(label: Text('收盘', style: TextStyle(fontSize: 11))),
                    DataColumn(label: Text('最高', style: TextStyle(fontSize: 11))),
                    DataColumn(label: Text('最低', style: TextStyle(fontSize: 11))),
                    DataColumn(label: Text('涨跌幅', style: TextStyle(fontSize: 11))),
                    DataColumn(label: Text('成交量', style: TextStyle(fontSize: 11))),
                  ],
                  rows: _klineData.asMap().entries.map((entry) {
                    final i = entry.key;
                    final k = entry.value;
                    final prev = i > 0 ? _klineData[i - 1] : null;
                    final prevClose =
                        (prev?['close'] as num?)?.toDouble() ?? 0;
                    final curClose =
                        (k['close'] as num?)?.toDouble() ?? 0;
                    final change = prevClose > 0
                        ? ((curClose - prevClose) / prevClose * 100)
                        : 0.0;
                    final isUp = curClose >= ((k['open'] as num?)?.toDouble() ?? 0);

                    return DataRow(cells: [
                      DataCell(Text(k['kdate'] ?? '',
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(
                          (k['open'] as num?)?.toStringAsFixed(3) ?? '',
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(
                          (k['close'] as num?)?.toStringAsFixed(3) ?? '',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isUp
                                  ? const Color(0xFFEF5350)
                                  : const Color(0xFF00C896)))),
                      DataCell(Text(
                          (k['high'] as num?)?.toStringAsFixed(3) ?? '',
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(
                          (k['low'] as num?)?.toStringAsFixed(3) ?? '',
                          style: const TextStyle(fontSize: 11))),
                      DataCell(Text(
                          change == 0 ? '-' : '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%',
                          style: TextStyle(
                              fontSize: 11,
                              color: change >= 0
                                  ? const Color(0xFFEF5350)
                                  : const Color(0xFF00C896)))),
                      DataCell(Text(
                          '${(k['volume'] as num?)?.toInt() ?? 0}',
                          style: const TextStyle(fontSize: 11))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
