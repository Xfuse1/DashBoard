import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_colors.dart';
import '../../services/supabase_service.dart';

class PaymentsPage extends StatefulWidget {
  final String title;
  const PaymentsPage({super.key, required this.title});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  // Dummy invoices
  List<Map<String, dynamic>> _all = List.generate(23, (i) {
    final date = DateTime.now().subtract(Duration(days: i * 3));
    return {
      'date': date,
      'amount': (50 + i * 10).toDouble(),
      'currency': 'USD',
      'status': i % 4 == 0
          ? 'succeeded'
          : (i % 4 == 1 ? 'failed' : (i % 4 == 2 ? 'refunded' : 'pending')),
      'method': i % 3 == 0 ? 'card' : (i % 3 == 1 ? 'bank' : 'wallet'),
      'last4': '424${i % 10}${(i + 3) % 10}${(i + 7) % 10}',
      'invoice': 'INV-2025-${1000 + i}',
    };
  });

  // Filters
  DateTime? _from;
  DateTime? _to;
  String _status = 'All';
  String _method = 'All';
  String _search = '';

  // Pagination
  int _page = 0;
  final int _pageSize = 8;

  @override
  void initState() {
    super.initState();
    _loadPaymentsFromSupabase();
  }

  Future<void> _loadPaymentsFromSupabase() async {
    try {
      final rows = await SupabaseService.fetchPayments(limit: 200);
      if (rows.isEmpty) return;
      final mapped = rows.map((r) {
        DateTime date;
        final d = r['date'] ?? r['created_at'] ?? r['timestamp'];
        if (d is String) {
          date = DateTime.tryParse(d) ?? DateTime.now();
        } else if (d is int) {
          date = DateTime.fromMillisecondsSinceEpoch(d);
        } else {
          date = DateTime.now();
        }
        return {
          'date': date,
          'amount': (r['amount'] is num)
              ? (r['amount'] as num).toDouble()
              : double.tryParse('${r['amount']}') ?? 0.0,
          'currency': r['currency'] ?? 'USD',
          'status': r['status'] ?? 'succeeded',
          'method': r['method'] ?? 'card',
          'last4': r['last4'] ?? '',
          'invoice': r['invoice'] ?? r['reference'] ?? '',
        };
      }).toList();
      setState(() => _all = mapped);
    } catch (_) {
      // ignore and keep mock data
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _all.where((inv) {
      if (_status != 'All' && inv['status'] != _status) return false;
      if (_method != 'All' && inv['method'] != _method) return false;
      if (_from != null && (inv['date'] as DateTime).isBefore(_from!))
        return false;
      if (_to != null && (inv['date'] as DateTime).isAfter(_to!)) return false;
      if (_search.isNotEmpty && !(inv['invoice'] as String).contains(_search))
        return false;
      return true;
    }).toList();
    return list;
  }

  void _clearFilters() {
    setState(() {
      _from = null;
      _to = null;
      _status = 'All';
      _method = 'All';
      _search = '';
      _page = 0;
    });
  }

  void _exportCsv() async {
    final rows = [_headers(), ..._filtered.map(_toCsvRow)];
    final csv = rows
        .map((r) =>
            r.map((e) => '"${e.toString().replaceAll('"', '""')}"').join(','))
        .join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('CSV copied to clipboard')));
  }

  List<String> _headers() =>
      ['Date', 'Amount', 'Currency', 'Status', 'Method', 'Last4', 'Invoice'];
  List<Object?> _toCsvRow(Map<String, dynamic> r) => [
        (r['date'] as DateTime).toIso8601String(),
        r['amount'],
        r['currency'],
        r['status'],
        r['method'],
        r['last4'],
        r['invoice'],
      ];

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final totalPaid = filtered
        .where((e) => e['status'] == 'succeeded')
        .fold<double>(0, (p, e) => p + (e['amount'] as double));
    final outstanding = filtered
        .where((e) => e['status'] == 'pending')
        .fold<double>(0, (p, e) => p + (e['amount'] as double));
    final nextDue = filtered
        .where((e) => e['status'] == 'pending')
        .map((e) => e['date'] as DateTime)
        .fold<DateTime?>(
            null, (prev, d) => prev == null || d.isBefore(prev) ? d : prev);

    final pageItems = filtered.skip(_page * _pageSize).take(_pageSize).toList();

    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar:
          AppBar(title: Text(widget.title), backgroundColor: AppColors.accent),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Summary
          Row(children: [
            _summaryCard('Total Paid', '\$${totalPaid.toStringAsFixed(2)}',
                AppColors.accent),
            const SizedBox(width: 12),
            _summaryCard('Outstanding', '\$${outstanding.toStringAsFixed(2)}',
                AppColors.accent),
            const SizedBox(width: 12),
            _summaryCard(
                'Next Due',
                nextDue == null
                    ? '-'
                    : '${nextDue.year}-${nextDue.month.toString().padLeft(2, '0')}-${nextDue.day.toString().padLeft(2, '0')}',
                AppColors.accent),
          ]),
          const SizedBox(height: 12),

          // Filters
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(children: [
                Row(children: [
                  Expanded(
                      child: _buildDatePicker(
                          'From', _from, (d) => setState(() => _from = d))),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _buildDatePicker(
                          'To', _to, (d) => setState(() => _to = d))),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _status,
                    items: ['All', 'succeeded', 'failed', 'refunded', 'pending']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _status = v ?? 'All'),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                    value: _method,
                    items: ['All', 'card', 'bank', 'wallet']
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _method = v ?? 'All'),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Search invoice #'),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          foregroundColor: Colors.white),
                      onPressed: _exportCsv,
                      icon: const Icon(Icons.download),
                      label: const Text('Export CSV')),
                  const SizedBox(width: 8),
                  TextButton(
                      onPressed: _clearFilters, child: const Text('Clear')),
                ])
              ]),
            ),
          ),
          const SizedBox(height: 12),

          // Table
          Expanded(
            child: pageItems.isEmpty
                ? const Center(child: Text('No invoices for selected filters'))
                : Card(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        DataTable(
                          columns: const [
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Amount')),
                            DataColumn(label: Text('Currency')),
                            DataColumn(label: Text('Status')),
                            DataColumn(label: Text('Method')),
                            DataColumn(label: Text('Invoice')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: pageItems.map((inv) {
                            return DataRow(cells: [
                              DataCell(Text((inv['date'] as DateTime)
                                  .toIso8601String()
                                  .split('T')
                                  .first)),
                              DataCell(Text(
                                  '\$${(inv['amount'] as double).toStringAsFixed(2)}')),
                              DataCell(Text(inv['currency'])),
                              DataCell(Text(inv['status'])),
                              DataCell(
                                  Text('${inv['method']} • ${inv['last4']}')),
                              DataCell(Text(inv['invoice'])),
                              DataCell(Row(children: [
                                IconButton(
                                  color: AppColors.accent,
                                  icon: const Icon(Icons.receipt_long),
                                  tooltip: 'View',
                                  onPressed: () => _viewReceipt(inv),
                                ),
                                IconButton(
                                  color: AppColors.accent,
                                  icon: const Icon(Icons.download),
                                  tooltip: 'Download',
                                  onPressed: () => ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                          content: Text('Downloading PDF...'))),
                                ),
                              ])),
                            ]);
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  'Showing ${_page * _pageSize + 1}–${_page * _pageSize + pageItems.length} of ${filtered.length}'),
                              Row(children: [
                                IconButton(
                                    onPressed: _page > 0
                                        ? () => setState(() => _page--)
                                        : null,
                                    icon: const Icon(Icons.chevron_left)),
                                IconButton(
                                    onPressed: (_page + 1) * _pageSize <
                                            filtered.length
                                        ? () => setState(() => _page++)
                                        : null,
                                    icon: const Icon(Icons.chevron_right)),
                              ])
                            ])
                      ]),
                    ),
                  ),
          ),
        ]),
      ),
    );
  }

  Widget _summaryCard(String title, String value, Color color) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Colors.black54)),
              const SizedBox(height: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            ]),
          ),
        ),
      );

  Widget _buildDatePicker(
          String label, DateTime? value, ValueChanged<DateTime?> onChanged) =>
      InkWell(
        onTap: () async {
          final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100));
          onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          child: Text(value == null
              ? '-'
              : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}'),
        ),
      );

  void _viewReceipt(Map<String, dynamic> inv) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Invoice ${inv['invoice']}'),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Date: ${(inv['date'] as DateTime).toIso8601String().split('T').first}'),
              Text(
                  'Amount: \$${(inv['amount'] as double).toStringAsFixed(2)} ${inv['currency']}'),
              Text('Status: ${inv['status']}'),
              Text('Method: ${inv['method']} • ${inv['last4']}'),
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c), child: const Text('Close'))
        ],
      ),
    );
  }
}
