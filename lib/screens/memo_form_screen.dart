import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/memo_model.dart';
import '../services/firestore_service.dart';
import '../services/memo_pdf.dart';
import '../utils/amount_in_words.dart';
import '../widgets/share_memo_sheet.dart';

class MemoFormScreen extends StatefulWidget {
  /// Memo being edited; null for a new memo.
  final MemoModel? memo;

  /// Memo to copy details from when creating a new one ("Duplicate").
  final MemoModel? copyFrom;

  /// Past memos, used to suggest transport names and fill their address.
  final List<MemoModel> history;

  /// Hire Fixed to start a new memo with (from a quotation).
  final double? prefillHire;

  const MemoFormScreen({
    super.key,
    this.memo,
    this.copyFrom,
    this.history = const [],
    this.prefillHire,
  });

  @override
  State<MemoFormScreen> createState() => _MemoFormScreenState();
}

class _MemoFormScreenState extends State<MemoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FirestoreService();
  final _dateFmt = DateFormat('dd MMM yyyy');

  late DateTime _date;
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _trailerNo = TextEditingController();
  final _transport = TextEditingController();
  final _address = TextEditingController();
  final _lrNo = TextEditingController();
  final _hire = TextEditingController();
  final _advance = TextEditingController();
  final _other = TextEditingController();
  final _otherNote = TextEditingController();
  final _balance = TextEditingController();
  final _words = TextEditingController();
  final _transportFocus = FocusNode();

  // Balance and words are auto-filled until the user types in them.
  bool _balanceEdited = false;
  bool _wordsEdited = false;
  bool _busy = false;
  int? _nextNo;

  bool get _isEdit => widget.memo != null;

  @override
  void initState() {
    super.initState();
    final src = widget.memo ?? widget.copyFrom;
    _date = _isEdit ? widget.memo!.date : DateTime.now();
    if (src != null) {
      _from.text = src.from;
      _to.text = src.to;
      _trailerNo.text = src.trailerNo;
      _transport.text = src.transportName;
      _address.text = src.address;
    }
    if (_isEdit) {
      final m = widget.memo!;
      _lrNo.text = m.lrNo;
      _hire.text = _num(m.hireFixed);
      _advance.text = _num(m.advance);
      _other.text = _num(m.otherCharges);
      _otherNote.text = m.otherChargesNote;
      _balance.text = _num(m.balance);
      _words.text = m.amountInWords;
      _balanceEdited = m.balance != m.hireFixed + m.otherCharges - m.advance;
      _wordsEdited = m.amountInWords != amountInWords(m.balance);
    } else {
      _service.getNextMemoNo().then((n) {
        if (mounted) setState(() => _nextNo = n);
      }).catchError((_) {});
    }
    for (final c in [_hire, _advance, _other]) {
      c.addListener(_recalc);
    }
    // Set after the listeners so balance and words fill in too.
    if (!_isEdit && widget.prefillHire != null) {
      _hire.text = _num(widget.prefillHire!);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _from, _to, _trailerNo, _transport, _address, _lrNo,
      _hire, _advance, _other, _otherNote, _balance, _words,
    ]) {
      c.dispose();
    }
    _transportFocus.dispose();
    super.dispose();
  }

  String _num(double v) =>
      v == 0 ? '' : (v == v.roundToDouble() ? v.toInt().toString() : '$v');

  double _parse(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '').trim()) ?? 0;

  void _recalc() {
    if (!_balanceEdited) {
      final b = _parse(_hire) + _parse(_other) - _parse(_advance);
      _balance.text = _num(b);
    }
    _updateWords();
  }

  void _updateWords() {
    if (_wordsEdited) return;
    final b = _parse(_balance);
    _words.text = b == 0 ? '' : amountInWords(b);
  }

  MemoModel _collect() {
    return MemoModel(
      id: widget.memo?.id ?? '',
      memoNo: widget.memo?.memoNo ?? 0,
      date: _date,
      from: _from.text.trim(),
      to: _to.text.trim(),
      trailerNo: _trailerNo.text.trim().toUpperCase(),
      transportName: _transport.text.trim(),
      address: _address.text.trim(),
      lrNo: _lrNo.text.trim(),
      hireFixed: _parse(_hire),
      advance: _parse(_advance),
      otherCharges: _parse(_other),
      otherChargesNote: _otherNote.text.trim(),
      balance: _parse(_balance),
      amountInWords: _words.text.trim(),
      createdAt: widget.memo?.createdAt,
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _preview() async {
    final m = _collect();
    if (!_isEdit) m.memoNo = _nextNo ?? 0;
    await Printing.layoutPdf(
      name: memoFileName(m),
      onLayout: (_) => buildMemoPdf(m),
    );
  }

  Future<void> _saveAndShare() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      var m = _collect();
      if (_isEdit) {
        await _service.updateMemo(m);
      } else {
        m = await _service.createMemo(m);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Memo No. ${m.memoNoText} saved')),
      );
      await showShareMemoSheet(context, m);
      if (mounted) Navigator.pop(context, m);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save memo: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Unique past transport names (latest first) for suggestions.
  List<MemoModel> get _pastParties {
    final seen = <String>{};
    return widget.history
        .where((m) => m.transportName.trim().isNotEmpty)
        .where((m) => seen.add(m.transportName.trim().toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noLabel = _isEdit
        ? 'Memo No. ${widget.memo!.memoNoText}'
        : (_nextNo != null
              ? 'New Memo · No. ${_nextNo.toString().padLeft(4, '0')}'
              : 'New Memo');

    return Scaffold(
      appBar: AppBar(title: Text(noLabel)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              _section(theme, 'Trip'),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded),
                title: const Text('Date'),
                subtitle: Text(_dateFmt.format(_date)),
                trailing: const Icon(Icons.edit_calendar_rounded),
                onTap: _pickDate,
              ),
              Row(
                children: [
                  Expanded(child: _field(_from, 'From', required: true)),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_to, 'To', required: true)),
                ],
              ),
              _field(
                _trailerNo,
                'Trailer No.',
                caps: TextCapitalization.characters,
              ),
              _section(theme, 'Party'),
              _transportField(),
              _field(_address, 'Address', maxLines: 2),
              _field(_lrNo, 'L.R. No.'),
              _section(theme, 'Amount (Rs.)'),
              _field(_hire, 'Hire Fixed', money: true, required: true),
              _field(_advance, 'Advance', money: true),
              _field(_other, 'Other Charges', money: true),
              _field(
                _otherNote,
                'Other Charges Description',
                helper: 'e.g. Halting: One Day',
                caps: TextCapitalization.sentences,
              ),
              _field(
                _balance,
                'Balance',
                money: true,
                helper: _balanceEdited ? null : 'Hire + Other − Advance',
                onChanged: (_) {
                  _balanceEdited = true;
                  _updateWords();
                },
              ),
              _field(
                _words,
                'Rupees in Words',
                maxLines: 2,
                onChanged: (_) => _wordsEdited = true,
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _preview,
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Preview'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _saveAndShare,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.share_rounded),
                  label: Text(_isEdit ? 'Update & Share' : 'Save & Share'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(ThemeData theme, String title) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 8),
    child: Text(
      title,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _field(
    TextEditingController c,
    String label, {
    bool required = false,
    bool money = false,
    int maxLines = 1,
    String? helper,
    TextCapitalization caps = TextCapitalization.words,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        minLines: 1,
        onChanged: onChanged,
        textCapitalization: money ? TextCapitalization.none : caps,
        keyboardType: money
            ? const TextInputType.numberWithOptions(decimal: true)
            : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          prefixText: money ? '₹ ' : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        validator: (v) {
          final t = (v ?? '').trim();
          if (required && t.isEmpty) return 'Required';
          if (money && t.isNotEmpty &&
              double.tryParse(t.replaceAll(',', '')) == null) {
            return 'Enter a number';
          }
          return null;
        },
      ),
    );
  }

  // Transport name with suggestions from past memos; picking one fills the address.
  Widget _transportField() {
    final parties = _pastParties;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RawAutocomplete<MemoModel>(
        textEditingController: _transport,
        focusNode: _transportFocus,
        displayStringForOption: (m) => m.transportName,
        optionsBuilder: (value) {
          final q = value.text.trim().toLowerCase();
          if (q.isEmpty) return const [];
          return parties
              .where((m) => m.transportName.toLowerCase().contains(q))
              .take(6);
        },
        onSelected: (m) => _address.text = m.address,
        fieldViewBuilder: (context, controller, focusNode, onSubmit) {
          return TextFormField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Transport Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Required' : null,
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
                child: ListView(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  children: options
                      .map(
                        (m) => ListTile(
                          title: Text(m.transportName),
                          subtitle: m.address.isEmpty
                              ? null
                              : Text(
                                  m.address,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                          onTap: () => onSelected(m),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
