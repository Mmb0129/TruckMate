import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/memo_model.dart';
import '../models/quote_model.dart';
import '../services/firestore_service.dart';
import '../widgets/share_quote_sheet.dart';
import 'memo_form_screen.dart';
import 'quote_form_screen.dart';

class QuoteListScreen extends StatefulWidget {
  const QuoteListScreen({super.key});

  @override
  State<QuoteListScreen> createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends State<QuoteListScreen> {
  final _service = FirestoreService();
  final _search = TextEditingController();
  final _dateFmt = DateFormat('dd-MM-yyyy');
  final _moneyFmt = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

  late final Stream<List<QuoteModel>> _quotes = _service.getQuotes();
  StreamSubscription<List<MemoModel>>? _memoSub;
  List<QuoteModel> _all = [];
  List<MemoModel> _memos = []; // for rate hints and Convert to Memo
  QuoteStatus? _statusFilter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _memoSub = _service.getMemos().listen((m) => _memos = m, onError: (_) {});
  }

  @override
  void dispose() {
    _memoSub?.cancel();
    _search.dispose();
    super.dispose();
  }

  List<QuoteModel> _filter(List<QuoteModel> quotes) {
    final t = _query.trim().toLowerCase();
    return quotes.where((q) {
      if (_statusFilter != null && q.status != _statusFilter) return false;
      if (t.isEmpty) return true;
      return int.tryParse(t.replaceAll(RegExp(r'^q-?', caseSensitive: false), '')) ==
              q.quoteNo ||
          q.customerName.toLowerCase().contains(t) ||
          q.customerPhone.contains(t) ||
          q.from.toLowerCase().contains(t) ||
          q.to.toLowerCase().contains(t) ||
          q.cargo.toLowerCase().contains(t);
    }).toList();
  }

  // Otherwise the search box regains focus (and the keyboard) on return.
  void _dropSearchFocus() => FocusManager.instance.primaryFocus?.unfocus();

  void _openForm({QuoteModel? quote, QuoteModel? copyFrom}) {
    _dropSearchFocus();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuoteFormScreen(
          quote: quote,
          copyFrom: copyFrom,
          quotes: _all,
          memos: _memos,
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _setStatus(QuoteModel q, QuoteStatus s) async {
    q.status = s;
    try {
      await _service.updateQuote(q);
    } catch (e) {
      _showError('Could not update status: $e');
    }
  }

  /// Opens a new memo pre-filled from the quote (one memo per vehicle).
  Future<void> _convertToMemo(QuoteModel q) async {
    final perVehicle = (q.total / q.vehicles).roundToDouble();
    final seed = MemoModel(
      date: DateTime.now(),
      from: q.from,
      to: q.to,
      trailerNo: '',
      transportName: q.customerName,
      address: q.address,
      lrNo: '',
      hireFixed: 0,
      advance: 0,
      otherCharges: 0,
      balance: 0,
      amountInWords: '',
    );
    final memo = await Navigator.push<MemoModel>(
      context,
      MaterialPageRoute(
        builder: (_) => MemoFormScreen(
          copyFrom: seed,
          history: _memos,
          prefillHire: perVehicle,
        ),
      ),
    );
    if (memo == null || memo.id.isEmpty) return;
    q.memoIds = [...q.memoIds, memo.id];
    q.status = QuoteStatus.accepted;
    try {
      await _service.updateQuote(q);
    } catch (e) {
      _showError('Memo saved, but could not link it to the quote: $e');
      return;
    }
    if (mounted && q.memoIds.length < q.vehicles) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Memo ${q.memoIds.length} of ${q.vehicles} created. '
            'Use Convert to Memo again for the next vehicle.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(QuoteModel q) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Quotation ${q.quoteNoText}?'),
        content: Text(
          q.memoIds.isEmpty
              ? 'This quotation will be removed permanently.'
              : 'This quotation will be removed permanently. '
                    'Its ${q.memoIds.length} memo(s) are kept.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteQuote(q.id);
    } catch (e) {
      _showError('Could not delete quotation: $e');
    }
  }

  Future<void> _setNextNumber() async {
    int current;
    try {
      current = await _service.getNextQuoteNo();
    } catch (e) {
      _showError('Could not read quotation number: $e');
      return;
    }
    if (!mounted) return;
    final value = await showDialog<int>(
      context: context,
      builder: (_) => _NextNumberDialog(current: current),
    );
    if (value == null || value < 1) return;
    try {
      await _service.setNextQuoteNo(value);
    } catch (e) {
      _showError('Could not save quotation number: $e');
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Next quotation will be Q-${value.toString().padLeft(4, '0')}')),
      );
    }
  }

  void _showActions(QuoteModel q) {
    _dropSearchFocus();
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        void run(VoidCallback action) {
          Navigator.pop(ctx);
          action();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  '${q.quoteNoText} · ${_dateFmt.format(q.date)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${q.customerName}\n${q.from} → ${q.to} · ${_moneyFmt.format(q.total)}',
                ),
                isThreeLine: true,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<QuoteStatus>(
                  showSelectedIcon: false,
                  segments: [
                    for (final s in QuoteStatus.values)
                      ButtonSegment(value: s, label: Text(s.label, style: const TextStyle(fontSize: 12))),
                  ],
                  selected: {q.status},
                  onSelectionChanged: (s) => run(() => _setStatus(q, s.first)),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.send_rounded),
                title: const Text('Send'),
                subtitle: const Text('Email, WhatsApp image, PDF, text, print'),
                onTap: () => run(() => showShareQuoteSheet(context, q)),
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit'),
                onTap: () => run(() => _openForm(quote: q)),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('New quotation from this'),
                onTap: () => run(() => _openForm(copyFrom: q)),
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_rounded),
                title: const Text('Convert to Memo'),
                subtitle: Text(
                  q.vehicles > 1
                      ? 'One memo per vehicle · ${q.memoIds.length} of ${q.vehicles} done'
                      : (q.memoIds.isEmpty ? 'Fills route, party and hire' : 'Memo already created'),
                ),
                onTap: () => run(() => _convertToMemo(q)),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () => run(() => _confirmDelete(q)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quotations'),
        actions: [
          IconButton(
            icon: const Icon(Icons.numbers),
            tooltip: 'Set next quotation number',
            onPressed: _setNextNumber,
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<QuoteModel>>(
          stream: _quotes,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            _all = snapshot.data ?? [];
            final quotes = _filter(_all);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search number, customer, phone, route',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                            ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      for (final s in [null, ...QuoteStatus.values])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              '${s?.label ?? 'All'} '
                              '(${s == null ? _all.length : _all.where((q) => q.status == s).length})',
                            ),
                            selected: _statusFilter == s,
                            onSelected: (_) => setState(() => _statusFilter = s),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: quotes.isEmpty
                      ? Center(
                          child: Text(
                            _all.isEmpty
                                ? 'No quotations yet.\nTap "New Quotation" to create one.'
                                : 'No quotations match.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          itemCount: quotes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _QuoteCard(
                            quote: quotes[i],
                            dateFmt: _dateFmt,
                            moneyFmt: _moneyFmt,
                            theme: theme,
                            onTap: () => _showActions(quotes[i]),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.request_quote_rounded),
        label: const Text('New Quotation'),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final QuoteModel quote;
  final DateFormat dateFmt;
  final NumberFormat moneyFmt;
  final ThemeData theme;
  final VoidCallback onTap;

  const _QuoteCard({
    required this.quote,
    required this.dateFmt,
    required this.moneyFmt,
    required this.theme,
    required this.onTap,
  });

  Color get _statusColor => switch (quote.status) {
    QuoteStatus.draft => Colors.grey,
    QuoteStatus.sent => Colors.blue,
    QuoteStatus.accepted => Colors.green,
    QuoteStatus.rejected => Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    final q = quote;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: theme.colorScheme.tertiaryContainer,
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      q.quoteNoText,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      q.customerName.isEmpty ? '—' : q.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text('${q.from} → ${q.to}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [
                        dateFmt.format(q.date),
                        q.pricing == PricingMode.perTon ? 'Per ton' : 'Per vehicle',
                        if (q.sentVia.isNotEmpty) 'via ${q.sentVia}',
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    moneyFmt.format(q.total),
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      q.status.label,
                      style: TextStyle(fontSize: 11, color: _statusColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Owns its text controller so it is disposed only after the dialog has closed.
class _NextNumberDialog extends StatefulWidget {
  final int current;
  const _NextNumberDialog({required this.current});

  @override
  State<_NextNumberDialog> createState() => _NextNumberDialogState();
}

class _NextNumberDialogState extends State<_NextNumberDialog> {
  late final _ctrl = TextEditingController(text: '${widget.current}');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Next quotation number'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          helperText: 'The next new quotation will get this number',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.pop(context, int.tryParse(_ctrl.text.trim())),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
