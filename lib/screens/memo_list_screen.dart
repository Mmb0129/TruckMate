import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/memo_model.dart';
import '../services/firestore_service.dart';
import '../services/memo_pdf.dart';
import '../widgets/month_selector.dart';
import '../widgets/share_memo_sheet.dart';
import 'memo_form_screen.dart';

class MemoListScreen extends StatefulWidget {
  const MemoListScreen({super.key});

  @override
  State<MemoListScreen> createState() => _MemoListScreenState();
}

class _MemoListScreenState extends State<MemoListScreen> {
  final _service = FirestoreService();
  final _search = TextEditingController();
  final _dateFmt = DateFormat('dd-MM-yyyy');
  final _moneyFmt = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  late final Stream<List<MemoModel>> _memos = _service.getMemos();
  List<MemoModel> _all = [];
  List<DateTime> _months = []; // empty = all months
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MemoModel> _filter(List<MemoModel> memos) {
    final q = _query.trim().toLowerCase();
    return memos.where((m) {
      if (_months.isNotEmpty &&
          !_months.any(
            (x) => x.month == m.date.month && x.year == m.date.year,
          )) {
        return false;
      }
      if (q.isEmpty) return true;
      return int.tryParse(q) == m.memoNo ||
          m.transportName.toLowerCase().contains(q) ||
          m.trailerNo.toLowerCase().contains(q) ||
          m.lrNo.toLowerCase().contains(q) ||
          m.from.toLowerCase().contains(q) ||
          m.to.toLowerCase().contains(q);
    }).toList();
  }

  void _openForm({MemoModel? memo, MemoModel? copyFrom}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MemoFormScreen(memo: memo, copyFrom: copyFrom, history: _all),
      ),
    );
  }

  Future<void> _openFilter() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => MonthSelector(
        selected: _months,
        onChanged: (list) => setState(() => _months = list),
      ),
    );
  }

  Future<void> _setNextNumber() async {
    int current;
    try {
      current = await _service.getNextMemoNo();
    } catch (e) {
      _showError('Could not read memo number: $e');
      return;
    }
    if (!mounted) return;
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => _NextNumberDialog(current: current),
    );
    if (value == null || value < 1) return;
    try {
      await _service.setNextMemoNo(value);
    } catch (e) {
      _showError('Could not save memo number: $e');
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Next memo will be No. ${value.toString().padLeft(4, '0')}',
          ),
        ),
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _confirmDelete(MemoModel m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Memo No. ${m.memoNoText}?'),
        content: const Text('This memo record will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
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
      await _service.deleteMemo(m.id);
    } catch (e) {
      _showError('Could not delete memo: $e');
    }
  }

  void _showActions(MemoModel m) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        void run(VoidCallback action) {
          Navigator.pop(ctx);
          action();
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Memo No. ${m.memoNoText} · ${_dateFmt.format(m.date)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${m.transportName}\n${m.from} → ${m.to}'
                  '${m.lrNo.isEmpty ? '' : '\nL.R. No. ${m.lrNo}'}',
                ),
                isThreeLine: true,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.share_rounded),
                title: const Text('Share'),
                subtitle: const Text('As PDF or image (JPG)'),
                onTap: () => run(() => showShareMemoSheet(context, m)),
              ),
              ListTile(
                leading: const Icon(Icons.print_rounded),
                title: const Text('View / Print'),
                onTap: () => run(
                  () => Printing.layoutPdf(
                    name: memoFileName(m),
                    onLayout: (_) => buildMemoPdf(m),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit'),
                onTap: () => run(() => _openForm(memo: m)),
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('New memo from this'),
                subtitle: const Text('Copies route, trailer and party'),
                onTap: () => run(() => _openForm(copyFrom: m)),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () => run(() => _confirmDelete(m)),
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
        title: const Text('Memos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_rounded),
            tooltip: 'Filter Months',
            onPressed: _openFilter,
          ),
          IconButton(
            icon: const Icon(Icons.numbers),
            tooltip: 'Set next memo number',
            onPressed: _setNextNumber,
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<MemoModel>>(
          stream: _memos,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            _all = snapshot.data ?? [];
            final memos = _filter(_all);
            final total = memos.fold<double>(0, (s, m) => s + m.hireFixed);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search memo no, transport, trailer, L.R. no',
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
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                  ),
                ),
                if (_months.isNotEmpty)
                  SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final mo in _months)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: InputChip(
                              avatar: const Icon(Icons.calendar_today, size: 16),
                              label: Text(DateFormat('MMM yyyy').format(mo)),
                              onDeleted: () => setState(
                                () => _months.removeWhere(
                                  (x) =>
                                      x.month == mo.month && x.year == mo.year,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                  child: Row(
                    children: [
                      Text(
                        '${memos.length} memo${memos.length == 1 ? '' : 's'}',
                        style: theme.textTheme.labelLarge,
                      ),
                      const Spacer(),
                      Text(
                        'Hire total ${_moneyFmt.format(total)}',
                        style: theme.textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: memos.isEmpty
                      ? Center(
                          child: Text(
                            _all.isEmpty
                                ? 'No memos yet.\nTap "New Memo" to create one.'
                                : 'No memos match.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          itemCount: memos.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _MemoCard(
                            memo: memos[i],
                            dateFmt: _dateFmt,
                            moneyFmt: _moneyFmt,
                            onTap: () => _showActions(memos[i]),
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
        icon: const Icon(Icons.note_add_rounded),
        label: const Text('New Memo'),
      ),
    );
  }
}

class _MemoCard extends StatelessWidget {
  final MemoModel memo;
  final DateFormat dateFmt;
  final NumberFormat moneyFmt;
  final VoidCallback onTap;

  const _MemoCard({
    required this.memo,
    required this.dateFmt,
    required this.moneyFmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                backgroundColor: theme.colorScheme.primaryContainer,
                child: FittedBox(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Text(
                      memo.memoNoText,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onPrimaryContainer,
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
                      memo.transportName.isEmpty ? '—' : memo.transportName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${memo.from} → ${memo.to}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        dateFmt.format(memo.date),
                        if (memo.trailerNo.isNotEmpty) memo.trailerNo,
                        if (memo.lrNo.isNotEmpty) 'LR ${memo.lrNo}',
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
                    moneyFmt.format(memo.hireFixed),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Bal ${moneyFmt.format(memo.balance)}',
                    style: theme.textTheme.bodySmall,
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
      title: const Text('Next memo number'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          helperText: 'The next new memo will get this number',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(context, int.tryParse(_ctrl.text.trim())),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
