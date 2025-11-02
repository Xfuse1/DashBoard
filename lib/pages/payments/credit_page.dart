import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../theme/app_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/supabase_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/kashier_service.dart';
import 'kashier_checkout_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class CreditPage extends StatefulWidget {
  final String title;
  const CreditPage({super.key, required this.title});

  @override
  State<CreditPage> createState() => _CreditPageState();
}

class _CreditPageState extends State<CreditPage> {
  // Balances
  double _balance = 250.0;
  double _reserved = 30.0;
  double? _creditLimit = 500.0;

  // Filters/state
  DateTime? _from;
  DateTime? _to;
  String _type = 'All';
  String _method = 'All';
  String _search = '';

  // Pagination
  int _page = 0;
  final int _pageSize = 8;

  // Ledger rows (map shape flexible)
  List<Map<String, dynamic>> _ledger = [];
  // Receipt attachment state
  XFile? _pickedReceipt;
  static const String _receiptBucket = 'receipts';

  @override
  void initState() {
    super.initState();
    _loadMock();
    _loadLedgerFromSupabase();
  }

  String _sanitizeFileName(String name) {
    return name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
  }

  String _mimeTypeForFile(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    return 'image/jpeg';
  }

  void _loadMock() {
    // Small set of mock ledger entries so the UI shows content when offline
    _ledger = List.generate(12, (i) {
      final date = DateTime.now().subtract(Duration(days: i * 3));
      final type = i % 3 == 0 ? 'Top-up' : (i % 3 == 1 ? 'Spend' : 'Promo');
      final amount = type == 'Spend'
          ? -((i + 1) * 7).toDouble()
          : ((i + 1) * 10).toDouble();
      return {
        'date': date,
        'type': type,
        'amount': amount,
        'balanceAfter': (_balance + (i * 2)).toDouble(),
        'reference': 'REF-${1000 + i}',
        'method': type == 'Top-up' ? 'card' : 'wallet',
        'notes': type == 'Promo' ? 'Promo: SAVE10' : '',
        'receipt':
            type == 'Top-up' ? 'https://example.com/receipt/${1000 + i}' : null,
      };
    });
  }

  Future<void> _loadLedgerFromSupabase() async {
    try {
      // If user is authenticated, fetch only their ledger rows; otherwise try generic lookup
      final uid = SupabaseService.client.auth.currentUser?.id;
      final rows = (uid != null)
          ? await SupabaseService.fetchLedgerForUser(uid, limit: 500)
          : await SupabaseService.fetchLedger(limit: 500);
      if (rows.isEmpty) return; // keep mock

      final mapped = rows.map((r) {
        // tolerant parsing of a date field
        final d = r['date'] ?? r['created_at'] ?? r['timestamp'];
        DateTime date = DateTime.now();
        if (d is String) date = DateTime.tryParse(d) ?? DateTime.now();
        if (d is int) date = DateTime.fromMillisecondsSinceEpoch(d);

        return {
          'date': date,
          'type': r['type'] ?? r['kind'] ?? 'Adjustment',
          'amount': (r['amount'] is num)
              ? (r['amount'] as num).toDouble()
              : double.tryParse('${r['amount']}') ?? 0.0,
          'balanceAfter': (r['balance_after'] is num)
              ? (r['balance_after'] as num).toDouble()
              : double.tryParse(
                      '${r['balance_after'] ?? r['balanceAfter'] ?? 0}') ??
                  0.0,
          'reference': r['reference'] ?? r['invoice'] ?? '',
          'method': r['method'] ?? r['source'] ?? 'card',
          'notes': r['notes'] ?? r['note'] ?? '',
          'receipt': r['receipt'] ?? r['receipt_url'] ?? null,
        };
      }).toList();

      setState(() => _ledger = mapped);
    } catch (_) {
      // keep mock data on any error
    }
  }

  List<Map<String, dynamic>> get _filtered => _ledger.where((row) {
        if (_type != 'All' && row['type'] != _type) return false;
        if (_method != 'All' && row['method'] != _method) return false;
        if (_from != null && (row['date'] as DateTime).isBefore(_from!))
          return false;
        if (_to != null && (row['date'] as DateTime).isAfter(_to!))
          return false;
        if (_search.isNotEmpty &&
            !(row['reference'] as String)
                .toLowerCase()
                .contains(_search.toLowerCase())) return false;
        return true;
      }).toList();

  void _clearFilters() {
    setState(() {
      _from = null;
      _to = null;
      _type = 'All';
      _method = 'All';
      _search = '';
      _page = 0;
    });
  }

  Future<void> _openTopUp() async {
    final amountCtrl = TextEditingController();
    final provider = ValueNotifier<String>('card');
    final referenceCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final receiptCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final res = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Top-up credit'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount'),
                validator: (v) {
                  final a = double.tryParse(v ?? '');
                  if (a == null || a <= 0) return 'Enter a positive amount';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              ValueListenableBuilder<String>(
                valueListenable: provider,
                builder: (_, v, __) => DropdownButtonFormField<String>(
                  initialValue: v,
                  items: const [
                    DropdownMenuItem(value: 'card', child: Text('Card')),
                    DropdownMenuItem(value: 'bank', child: Text('Bank')),
                    DropdownMenuItem(value: 'wallet', child: Text('Wallet')),
                  ],
                  onChanged: (val) => provider.value = val ?? 'card',
                  decoration: const InputDecoration(labelText: 'Method'),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: referenceCtrl,
                decoration:
                    const InputDecoration(labelText: 'Reference (optional)'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: notesCtrl,
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)'),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: receiptCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Receipt URL (optional)'),
                    validator: (v) {
                      final txt = v ?? '';
                      if (txt.isEmpty) return null;
                      final ok = Uri.tryParse(txt) != null &&
                          (txt.startsWith('http://') ||
                              txt.startsWith('https://'));
                      return ok ? null : 'Invalid URL';
                    },
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final picker = ImagePicker();
                      final picked = await picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1600,
                        maxHeight: 1600,
                        imageQuality: 85,
                      );
                      if (picked == null) return;
                      if (!mounted) return;
                      setState(() {
                        _pickedReceipt = picked;
                      });
                    } catch (e) {
                      if (mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Pick failed: $e')));
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach'),
                )
              ]),
              if (_pickedReceipt != null) ...[
                const SizedBox(height: 8),
                Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Selected: ${_pickedReceipt!.name}')),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.pop(c, true);
                }
              },
              child: const Text('Continue')),
        ],
      ),
    );

    if (res == true) {
      final amt = double.tryParse(amountCtrl.text) ?? 0.0;
      if (amt <= 0) return;

      // Build ledger row
      final now = DateTime.now();
      final reference = referenceCtrl.text.trim().isEmpty
          ? 'TOPUP-${now.millisecondsSinceEpoch % 100000}'
          : referenceCtrl.text.trim();

      // Branch: If method is 'card' -> Kashier checkout; else keep current flow
      if (provider.value == 'card') {
        try {
          // Read Kashier config
          // Ensure dotenv loaded (already done in SupabaseService.init())
          final cfg = KashierConfig.fromEnv();
          final amountStr = KashierService.formatAmount(amt);

          // Use internal URLs for success/failure, only for navigation detection (no server).
          final successUrl = Uri.parse('https://success.kashier/callback');
          final failureUrl = Uri.parse('https://failure.kashier/callback');

          final hppUrl = KashierService.buildHostedPaymentUri(
            config: cfg,
            orderId: reference,
            amount: amountStr,
            currency: cfg.currency,
            mode: cfg.mode,
            merchantRedirect: successUrl.toString(),
            failureRedirect: failureUrl.toString(),
            allowedMethods: 'card',
            defaultMethod: 'card',
            redirectMethod: 'get',
          );

          KashierCheckoutResult? result;
          if (kIsWeb) {
            // On web, open in new tab. We cannot intercept reliably; ask user to confirm.
            await launchUrl(hppUrl, mode: LaunchMode.platformDefault);
            final confirmed = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Confirm Payment'),
                content: const Text(
                    'Complete the payment in the opened tab, then return here and press Confirm.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  ElevatedButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Confirm Paid')),
                ],
              ),
            );
            result = confirmed == true
                ? KashierCheckoutResult(success: true)
                : KashierCheckoutResult(success: false);
          } else {
            result = await Navigator.of(context).push<KashierCheckoutResult>(
              MaterialPageRoute(
                builder: (_) => KashierCheckoutPage(
                  checkoutUrl: hppUrl,
                  successUrl: successUrl,
                  failureUrl: failureUrl,
                ),
              ),
            );
          }

          if (result?.success == true) {
            // On success, record top-up (no receipt)
            final newRow = {
              'date': now.toIso8601String(),
              'type': 'Top-up',
              'amount': amt,
              'balance_after': (_balance + amt),
              'reference': reference,
              'method': 'card',
              'notes': notesCtrl.text.trim(),
            };

            bool savedToDb = false;
            try {
              final client = SupabaseService.client;
              final userId = client.auth.currentUser?.id;
              final insertRow = Map<String, dynamic>.from(newRow);
              if (userId != null) insertRow['user_id'] = userId;
              final resp = await client.from('credit_ledger').insert(insertRow).execute();
              if (resp.data != null) savedToDb = true;
            } catch (_) {}

            setState(() {
              _balance += amt;
              _ledger.insert(0, {
                'date': now,
                'type': 'Top-up',
                'amount': amt,
                'balanceAfter': _balance,
                'reference': reference,
                'method': 'card',
                'notes': notesCtrl.text.trim(),
                'receipt': null,
              });
            });

            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(savedToDb
                    ? 'Payment successful — top-up saved'
                    : 'Payment successful')));
          } else {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Payment canceled or failed')));
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Payment error: $e')));
        }
        return;
      }

      // Non-card methods: existing flow with optional receipt upload
      final newRow = {
        'date': now.toIso8601String(),
        'type': 'Top-up',
        'amount': amt,
        'balance_after': (_balance + amt),
        'reference': reference,
        'method': provider.value,
        'notes': notesCtrl.text.trim(),
      };

      String? receiptUrl;
      if (_pickedReceipt != null) {
        try {
          final client = SupabaseService.client;
          final userId = client.auth.currentUser?.id;
          if (userId == null) throw Exception('Sign in required to upload receipts');
          final sanitized = _sanitizeFileName(_pickedReceipt!.name.toLowerCase());
          final path = 'receipts/$userId/${DateTime.now().millisecondsSinceEpoch}_$sanitized';
          final bytes = await _pickedReceipt!.readAsBytes();
          final storage = client.storage.from(_receiptBucket);
          final options = FileOptions(contentType: _mimeTypeForFile(sanitized), upsert: true);
          try {
            await storage.uploadBinary(path, bytes, fileOptions: options);
          } catch (err) {
            if (err.toString().contains('already exists')) {
              await storage.updateBinary(path, bytes, fileOptions: options);
            } else {
              rethrow;
            }
          }
          receiptUrl = storage.getPublicUrl(path);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('Receipt upload failed: $e')));
          }
        }
      }

      bool savedToDb = false;
      try {
        final client = SupabaseService.client;
        final userId = client.auth.currentUser?.id;
        final insertRow = Map<String, dynamic>.from(newRow);
        if (userId != null) insertRow['user_id'] = userId;
        if (receiptUrl != null) {
          insertRow['receipt'] = receiptUrl;
        } else if (receiptCtrl.text.trim().isNotEmpty) {
          insertRow['receipt'] = receiptCtrl.text.trim();
        }
        final resp = await client.from('credit_ledger').insert(insertRow).execute();
        if (resp.data != null) {
          savedToDb = true;
        }
      } catch (_) {}

      setState(() {
        _balance += amt;
        _ledger.insert(0, {
          'date': now,
          'type': 'Top-up',
          'amount': amt,
          'balanceAfter': _balance,
          'reference': reference,
          'method': provider.value,
          'notes': notesCtrl.text.trim(),
          'receipt': receiptCtrl.text.trim().isEmpty ? null : receiptCtrl.text.trim(),
        });
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(savedToDb ? 'Top-up saved' : 'Done')));
    }
  }

  Future<void> _redeemPromo() async {
    final codeCtrl = TextEditingController();
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Redeem promo / voucher'),
        content: TextField(
            controller: codeCtrl,
            decoration: const InputDecoration(labelText: 'Code')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Apply')),
        ],
      ),
    );

    if (res == true) {
      final code = codeCtrl.text.trim();
      if (code.isEmpty) return;
      setState(() {
        final amt = 10.0;
        _balance += amt;
        _ledger.insert(0, {
          'date': DateTime.now(),
          'type': 'Promo',
          'amount': amt,
          'balanceAfter': _balance,
          'reference': 'PROMO-${code.toUpperCase()}',
          'method': 'promo',
          'notes': 'Redeemed $code',
          'receipt': null,
          'expires': DateTime.now().add(const Duration(days: 30)),
        });
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Promo applied (mock)')));
    }
  }

  void _openReceipt(String? url) {
    if (url == null) return;
    Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Receipt URL copied to clipboard')));
  }

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

  @override
  Widget build(BuildContext context) {
    final available = _balance - _reserved;
    final usageThisPeriod = _ledger
        .where((e) => e['type'] == 'Spend')
        .fold<double>(0, (p, e) => p + (e['amount'] as double).abs());
    final lifetimeAdded = _ledger
        .where((e) => e['type'] == 'Top-up' || e['type'] == 'Promo')
        .fold<double>(0, (p, e) => p + (e['amount'] as double));

    final filtered = _filtered;
    final pageItems = filtered.skip(_page * _pageSize).take(_pageSize).toList();
    final utilizationPct = (_creditLimit != null)
        ? ((_balance / _creditLimit!) * 100).clamp(0, 999)
        : 0.0;

    return Scaffold(
      backgroundColor: AppColors.secondary,
      appBar:
          AppBar(title: Text(widget.title), backgroundColor: AppColors.accent),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Balance header
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Credit Balance',
                              style: TextStyle(color: Colors.black54)),
                          const SizedBox(height: 6),
                          Text('\$${_balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          Text(
                              'Reserved: \$${_reserved.toStringAsFixed(2)} • Available: \$${available.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.black54)),
                        ]),
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (_creditLimit != null)
                            Text('Limit: \$${_creditLimit!.toStringAsFixed(2)}',
                                style: const TextStyle(color: Colors.black54)),
                          if (_creditLimit != null)
                            Text('${utilizationPct.toStringAsFixed(1)}% used',
                                style: const TextStyle(color: Colors.black54)),
                          const SizedBox(height: 8),
                          Row(children: [
                            ElevatedButton.icon(
                                onPressed: _openTopUp,
                                icon: const Icon(Icons.add_card),
                                label: const Text('Top up'),
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent)),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                                onPressed: _redeemPromo,
                                icon: const Icon(Icons.confirmation_num),
                                label: const Text('Redeem'),
                                style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.accent)),
                          ])
                        ])
                  ]),
            ),
          ),

          const SizedBox(height: 12),

          // Summary + rules
          Row(children: [
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Usage',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 8),
                        Text(
                            'This period spend: \$${usageThisPeriod.toStringAsFixed(2)}'),
                        Text(
                            'Lifetime added: \$${lifetimeAdded.toStringAsFixed(2)}'),
                      ]),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Credit rules',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(height: 8),
                        Text('Currency: USD'),
                        Text('Promos expire after 30 days (demo)'),
                        Text('Top-ups refundable within 7 days (demo)'),
                      ]),
                ),
              ),
            ),
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
                      value: _type,
                      items: [
                        'All',
                        'Top-up',
                        'Spend',
                        'Refund',
                        'Promo',
                        'Adjustment',
                        'Transfer'
                      ]
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _type = v ?? 'All')),
                  const SizedBox(width: 8),
                  DropdownButton<String>(
                      value: _method,
                      items: ['All', 'card', 'bank', 'wallet', 'promo']
                          .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)))
                          .toList(),
                      onChanged: (v) => setState(() => _method = v ?? 'All')),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: TextField(
                          decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Search by reference'),
                          onChanged: (v) => setState(() => _search = v))),
                  const SizedBox(width: 8),
                  TextButton(
                      onPressed: _clearFilters, child: const Text('Clear')),
                ])
              ]),
            ),
          ),

          const SizedBox(height: 12),

          // Ledger table
          Expanded(
            child: pageItems.isEmpty
                ? const Center(child: Text('No records for selected filters'))
                : Card(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Amount')),
                            DataColumn(label: Text('Balance after')),
                            DataColumn(label: Text('Reference')),
                            DataColumn(label: Text('Method')),
                            DataColumn(label: Text('Notes')),
                            DataColumn(label: Text('Receipt')),
                          ],
                          rows: pageItems.map((r) {
                            final date = (r['date'] as DateTime)
                                .toIso8601String()
                                .split('T')
                                .first;
                            final amt = (r['amount'] as double);
                            return DataRow(cells: [
                              DataCell(Text(date)),
                              DataCell(Text('${r['type'] ?? ''}')),
                              DataCell(Text(amt >= 0
                                  ? '+\$${amt.toStringAsFixed(2)}'
                                  : '-\$${amt.abs().toStringAsFixed(2)}')),
                              DataCell(Text(
                                  '\$${(r['balanceAfter'] as double).toStringAsFixed(2)}')),
                              DataCell(Text('${r['reference'] ?? ''}')),
                              DataCell(Text('${r['method'] ?? ''}')),
                              DataCell(Text('${r['notes'] ?? ''}')),
                              DataCell(r['receipt'] != null
                                  ? TextButton(
                                      onPressed: () =>
                                          _openReceipt(r['receipt']),
                                      child: const Text('View'))
                                  : const Text('-')),
                            ]);
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
          ),

          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
                'Showing ${_page * _pageSize + 1}–${_page * _pageSize + pageItems.length} of ${filtered.length}'),
            Row(children: [
              IconButton(
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_left)),
              IconButton(
                  onPressed: (_page + 1) * _pageSize < filtered.length
                      ? () => setState(() => _page++)
                      : null,
                  icon: const Icon(Icons.chevron_right)),
            ])
          ])
        ]),
      ),
      // Floating action button to quickly open the Top-up dialog
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openTopUp,
        icon: const Icon(Icons.add_card),
        label: const Text('Add Credit'),
        backgroundColor: AppColors.accent,
      ),
    );
  }
}
