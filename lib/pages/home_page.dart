import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _recentStocks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final stats = await DatabaseHelper.instance.getDashboardStats();
      final recent = await DatabaseHelper.instance.getRecentTradesByStock();
      if (mounted) {
        setState(() {
          _stats = stats;
          _recentStocks = recent;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);
    final greet = now.hour < 12
        ? '早上好'
        : now.hour < 18
            ? '下午好'
            : '晚上好';
    final tradeCnt = _stats['trade_count'] ?? 0;
    final stockCnt = _stats['stock_count'] ?? 0;
    final klineCnt = _stats['kline_count'] ?? 0;
    final posCnt = _stats['position_count'] ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(greet,
                style: const TextStyle(color: Color(0xFF8899AA), fontSize: 16)),
            const SizedBox(width: 8),
            Text(timeStr,
                style: const TextStyle(
                    color: Color(0xFF00C896),
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF8899AA)),
            onPressed: _loadData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFF00C896),
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00C896)))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 欢迎卡片
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C896), Color(0xFF00A87E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00C896).withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.show_chart,
                                  color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('股票交易助手',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold)),
                                SizedBox(height: 4),
                                Text('记录 · 分析 · 成长',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 快捷统计卡片
                  Row(
                    children: [
                      _statCard('交易记录', tradeCnt.toString(), Icons.receipt_long,
                          const Color(0xFF4FC3F7)),
                      const SizedBox(width: 12),
                      _statCard('持仓股票', stockCnt.toString(), Icons.work,
                          const Color(0xFFFFA726)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statCard('K线数据', klineCnt.toString(), Icons.show_chart,
                          const Color(0xFF66BB6A)),
                      const SizedBox(width: 12),
                      _statCard('当前持仓', posCnt.toString(), Icons.inventory_2,
                          const Color(0xFFEF5350)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 最近交易股票
                  const Text('活跃股票',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const SizedBox(height: 12),
                  if (_recentStocks.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(Icons.inbox_outlined,
                                size: 48, color: Colors.grey[600]),
                            const SizedBox(height: 12),
                            Text('还没有交易记录',
                                style: TextStyle(color: Colors.grey[500])),
                            const SizedBox(height: 4),
                            Text('在「交割单」页面录入你的第一笔交易吧',
                                style: TextStyle(
                                    color: Colors.grey[600], fontSize: 12)),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._recentStocks.map((s) => _stockCard(s)),
                ],
              ),
      ),
    );
  }

  Widget _statCard(
      String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(value,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 2),
              Text(title,
                  style: const TextStyle(
                      color: Color(0xFF8899AA), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stockCard(Map<String, dynamic> s) {
    final buyAmt = (s['buy_amt'] as num?)?.toDouble() ?? 0;
    final sellAmt = (s['sell_amt'] as num?)?.toDouble() ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF00C896).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Center(
            child: Text('📈',
                style: TextStyle(fontSize: 20)),
          ),
        ),
        title: Text(s['stock_name'] ?? s['stock_code'] ?? '',
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${s['stock_code']}  ·  ${s['cnt']}笔交易',
            style: const TextStyle(color: Color(0xFF8899AA), fontSize: 12)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (buyAmt > 0)
              Text('买 ¥${NumberFormat('#,##0.00').format(buyAmt)}',
                  style: const TextStyle(
                      color: Color(0xFFEF5350), fontSize: 12)),
            if (sellAmt > 0)
              Text('卖 ¥${NumberFormat('#,##0.00').format(sellAmt)}',
                  style: const TextStyle(
                      color: Color(0xFF00C896), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
