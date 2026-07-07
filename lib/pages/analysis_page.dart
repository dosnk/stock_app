import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';

class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  List<Map<String, dynamic>> _positions = [];
  List<Map<String, dynamic>> _logs = [];
  bool _styleLoading = false;
  bool _suggestLoading = false;
  String? _styleResult;
  String? _suggestResult;

  // LLM 配置
  final _apiKeyCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController(text: 'https://api.deepseek.com');
  final _modelCtrl = TextEditingController(text: 'deepseek-chat');
  double _temperature = 0.7;
  bool _configSaved = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    _positions = await DatabaseHelper.instance.getPositions();
    _logs = await DatabaseHelper.instance.getAnalysisLog(limit: 10);
    if (mounted) setState(() {});
  }

  Future<String?> _callLLM(String prompt, {double temp = 0.7}) async {
    final apiKey = _apiKeyCtrl.text.trim();
    final baseUrl = _baseUrlCtrl.text.trim();
    final model = _modelCtrl.text.trim();

    if (apiKey.isEmpty || baseUrl.isEmpty || model.isEmpty) {
      return '⚠️ 请先配置大模型（点击右上角 ⚙️）';
    }

    try {
      final uri = Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/v1/chat/completions');
      final resp = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': [{'role': 'user', 'content': prompt}],
          'temperature': temp,
          'max_tokens': 4096,
        }),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        return data['choices']?[0]?['message']?['content'] ?? '（无返回内容）';
      } else {
        return '❌ API 错误 (${resp.statusCode}): ${resp.body}';
      }
    } catch (e) {
      return '❌ 网络错误: $e';
    }
  }

  Future<void> _analyzeStyle() async {
    setState(() {
      _styleLoading = true;
      _styleResult = null;
    });

    final trades = await DatabaseHelper.instance.getTrades(limit: 200);
    if (trades.isEmpty) {
      setState(() {
        _styleLoading = false;
        _styleResult = '⚠️ 没有交割单数据，请先录入交易记录';
      });
      return;
    }

    final stats = await DatabaseHelper.instance.getTradeStats();
    final buyCnt = stats['buy_count'] ?? 0;
    final sellCnt = stats['sell_count'] ?? 0;

    // 构建交割单摘要
    final lines = StringBuffer();
    lines.writeln('## 交易统计');
    lines.writeln('- 总交易次数: ${buyCnt + sellCnt} (买入$buyCnt, 卖出$sellCnt)');
    lines.writeln('');
    lines.writeln('## 最近交割单记录');
    lines.writeln('');
    lines.writeln('| 日期 | 类型 | 股票 | 价格 | 数量 | 金额 |');
    lines.writeln('|------|------|------|------|------|------|');
    for (final t in trades.take(50)) {
      final type = t['trade_type'] == 'buy' ? '买入' : '卖出';
      final code = t['stock_code'] ?? '';
      final name = t['stock_name'] ?? '';
      lines.writeln(
          '| ${t['trade_date']} | $type | $code-$name | ${t['price']} | ${t['volume']} | ${(t['amount'] as num?)?.toStringAsFixed(2) ?? ''} |');
    }

    final prompt = '''
${lines.toString()}

请分析以上股票交割单，从以下维度总结该交易者的操作风格：

1. **交易频率**：是短线/中线/长线？平均持股时间估计
2. **仓位管理**：是否分批建仓？仓位控制如何？
3. **盈亏特征**：盈利交易和亏损交易的特点
4. **买入逻辑**：买入时机的特点
5. **卖出逻辑**：卖出时机的特点（止盈/止损/追涨/杀跌）
6. **风险偏好**：激进/稳健/保守？
7. **改进建议**：基于数据给出 3-5 条具体改进建议

请用中文回答，专业但易懂。
''';

    final result = await _callLLM(prompt);
    setState(() {
      _styleLoading = false;
      _styleResult = result;
    });

    // 记录日志
    if (result != null) {
      await DatabaseHelper.instance.addAnalysisLog({
        'stock_code': '',
        'analysis_type': 'style',
        'prompt': prompt,
        'response': result,
      });
      _logs = await DatabaseHelper.instance.getAnalysisLog(limit: 10);
      if (mounted) setState(() {});
    }
  }

  Future<void> _analyzeSuggestion() async {
    setState(() {
      _suggestLoading = true;
      _suggestResult = null;
    });

    if (_positions.isEmpty) {
      setState(() {
        _suggestLoading = false;
        _suggestResult = '⚠️ 没有持仓数据，请先在「持仓」页面录入持仓';
      });
      return;
    }

    // 用第一个持仓股票分析
    final pos = _positions.first;
    final code = pos['stock_code'] ?? '';
    final name = pos['stock_name'] ?? '';
    final vol = pos['volume'] ?? 0;
    final cost = (pos['cost_price'] as num?)?.toDouble() ?? 0;

    final klineData =
        await DatabaseHelper.instance.getKline(code, 30);
    if (klineData.isEmpty) {
      setState(() {
        _suggestLoading = false;
        _suggestResult = '⚠️ $code 没有K线数据，请先录入K线';
      });
      return;
    }
    klineData.sort((a, b) => a['kdate'].compareTo(b['kdate']));

    // 最近交易
    final trades = await DatabaseHelper.instance
        .getTrades(stockCode: code, limit: 5);

    final klineLines = StringBuffer();
    klineLines.writeln('## 最近30个交易日K线数据');
    klineLines.writeln('');
    klineLines.writeln('| 日期 | 开盘 | 收盘 | 最高 | 最低 | 成交量 |');
    klineLines.writeln('|------|------|------|------|------|--------|');
    for (final k in klineData) {
      klineLines.writeln(
          '| ${k['kdate']} | ${(k['open'] as num?)?.toStringAsFixed(3)} | ${(k['close'] as num?)?.toStringAsFixed(3)} | ${(k['high'] as num?)?.toStringAsFixed(3)} | ${(k['low'] as num?)?.toStringAsFixed(3)} | ${(k['volume'] as num?)?.toInt()} |');
    }

    final lastClose = (klineData.last['close'] as num?)?.toDouble() ?? 0;

    String tradesText = '';
    if (trades.isNotEmpty) {
      final tLines = StringBuffer();
      tLines.writeln('\n## 近期交割单');
      for (final t in trades) {
        final type = t['trade_type'] == 'buy' ? '买入' : '卖出';
        tLines.writeln(
            '- ${t['trade_date']} $type ${t['price']}元 × ${t['volume']}股 (${(t['amount'] as num?)?.toStringAsFixed(0)}元)');
      }
      tradesText = tLines.toString();
    }

    final prompt = '''
## 持仓信息
- 股票: $code $name
- 持仓数量: ${vol}股
- 成本价: ${cost}元
- 最新收盘价: ${lastClose}元
${klineLines.toString()}${tradesText}

请基于以上持仓和K线数据，给出专业操作建议，包括：

1. **趋势判断**：当前处于上升/下降/震荡趋势？
2. **技术指标参考**：基于近期的价格走势，简单分析支撑位和压力位
3. **操作建议**：持有/加仓/减仓/止损？具体操作价位建议
4. **风险提示**：需要注意的风险点
5. **关键观察点**：未来几天需要关注的价格点位

请用中文回答，专业但不过度复杂。
''';

    final result = await _callLLM(prompt, temp: 0.5);
    setState(() {
      _suggestLoading = false;
      _suggestResult = result;
    });

    if (result != null) {
      await DatabaseHelper.instance.addAnalysisLog({
        'stock_code': code,
        'analysis_type': 'suggestion',
        'prompt': prompt,
        'response': result,
      });
      _logs = await DatabaseHelper.instance.getAnalysisLog(limit: 10);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🤖 AI分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Color(0xFF8899AA)),
            onPressed: _showConfigDialog,
            tooltip: 'LLM 配置',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 风格分析
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.person_search, color: Color(0xFF00C896)),
                      SizedBox(width: 8),
                      Text('🎯 操作风格分析',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('基于交割单数据，分析你的交易风格',
                      style:
                          TextStyle(color: Color(0xFF8899AA), fontSize: 12)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _styleLoading ? null : _analyzeStyle,
                      icon: _styleLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF0A1929)))
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                          _styleLoading ? '分析中...' : '🔍 开始分析'),
                    ),
                  ),
                  if (_styleResult != null) ...[
                    const SizedBox(height: 16),
                    _buildResultBox(_styleResult!),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 操作建议
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          color: Color(0xFFFFA726)),
                      SizedBox(width: 8),
                      Text('💡 操作建议',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text('基于持仓 + K线数据，给出操作建议',
                      style:
                          TextStyle(color: Color(0xFF8899AA), fontSize: 12)),
                  const SizedBox(height: 16),
                  if (_positions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1824),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Color(0xFFFFA726), size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('暂无持仓数据，请先在「持仓」页面录入',
                                style: TextStyle(
                                    color: Color(0xFF8899AA), fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  if (_positions.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1824),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _positions.map((p) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Text('${p['stock_code']} ',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13)),
                                Text('${p['stock_name'] ?? ''} ',
                                    style: const TextStyle(
                                        color: Color(0xFF8899AA),
                                        fontSize: 12)),
                                Text('${p['volume']}股',
                                    style: const TextStyle(
                                        color: Color(0xFF4FC3F7),
                                        fontSize: 12)),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _suggestLoading ? null : _analyzeSuggestion,
                        icon: _suggestLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF0A1929)))
                            : const Icon(Icons.lightbulb),
                        label: Text(_suggestLoading
                            ? '分析中...'
                            : '💡 获取操作建议'),
                      ),
                    ),
                  ],
                  if (_suggestResult != null) ...[
                    const SizedBox(height: 16),
                    _buildResultBox(_suggestResult!),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 分析历史
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('📜 分析历史',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 18,
                            color: Color(0xFF8899AA)),
                        onPressed: _loadData,
                      ),
                    ],
                  ),
                  if (_logs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('暂无分析记录',
                          style: TextStyle(color: Color(0xFF8899AA))),
                    )
                  else
                    ..._logs.map((l) {
                      final type = l['analysis_type'] == 'style'
                          ? '🎯 风格分析'
                          : '💡 操作建议';
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: l['analysis_type'] == 'style'
                                ? const Color(0xFF00C896)
                                : const Color(0xFFFFA726),
                          ),
                        ),
                        title: Text(type,
                            style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          l['created_at'] ?? '',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            size: 16, color: Color(0xFF8899AA)),
                        onTap: () {
                          final resp = l['response'] ?? '';
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1A2634),
                              content: SingleChildScrollView(
                                child: Text(resp),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text('关闭'),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBox(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1824),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF2A3A4A)),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontSize: 13, height: 1.6),
      ),
    );
  }

  void _showConfigDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A2634),
        title: const Text('⚙️ 大模型配置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _baseUrlCtrl,
                decoration: const InputDecoration(
                    labelText: 'API 地址',
                    hintText: 'https://api.deepseek.com'),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _apiKeyCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                    labelText: 'API Key', hintText: 'sk-...'),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _modelCtrl,
                decoration: const InputDecoration(
                    labelText: '模型', hintText: 'deepseek-chat'),
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text('温度', style: TextStyle(fontSize: 13)),
                  Expanded(
                    child: Slider(
                      value: _temperature,
                      min: 0,
                      max: 2,
                      divisions: 20,
                      activeColor: const Color(0xFF00C896),
                      label: _temperature.toStringAsFixed(1),
                      onChanged: (v) =>
                          setState(() => _temperature = v),
                    ),
                  ),
                  Text(_temperature.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _configSaved = true);
              Navigator.pop(ctx);
            },
            child: const Text('💾 保存'),
          ),
        ],
      ),
    );
  }
}
