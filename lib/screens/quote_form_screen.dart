import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';

import '../models/memo_model.dart';
import '../models/quote_model.dart';
import '../services/firestore_service.dart';
import '../services/memo_pdf.dart' show formatRupees;
import '../services/quote_pdf.dart';
import '../widgets/share_quote_sheet.dart';

class QuoteFormScreen extends StatefulWidget {
  /// Quote being edited; null for a new quote.
  final QuoteModel? quote;

  /// Quote to copy details from when creating a new one ("Duplicate").
  final QuoteModel? copyFrom;

  /// Past quotes and memos: customer suggestions and last rate for a route.
  final List<QuoteModel> quotes;
  final List<MemoModel> memos;

  const QuoteFormScreen({
    super.key,
    this.quote,
    this.copyFrom,
    this.quotes = const [],
    this.memos = const [],
  });

  @override
  State<QuoteFormScreen> createState() => _QuoteFormScreenState();
}

class _Customer {
  final String name, phone, email, address;
  const _Customer(this.name, this.phone, this.email, this.address);
}

class _ChargeRow {
  final desc = TextEditingController();
  final amount = TextEditingController();
  ChargeMode mode;
  _ChargeRow(String d, this.mode, double a) {
    desc.text = d;
    amount.text = _num(a);
  }
  void dispose() {
    desc.dispose();
    amount.dispose();
  }
}

String _num(double v) =>
    v == 0 ? '' : (v == v.roundToDouble() ? v.toInt().toString() : '$v');

double _parse(String t) => double.tryParse(t.replaceAll(',', '').trim()) ?? 0;

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

class _QuoteFormScreenState extends State<QuoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = FirestoreService();
  final _dateFmt = DateFormat('dd MMM yyyy');
  final _shortDate = DateFormat('dd-MM-yyyy');

  late DateTime _date;
  late PricingMode _pricing;
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _cc = TextEditingController();
  final _address = TextEditingController();
  final _from = TextEditingController();
  final _to = TextEditingController();
  final _cargo = TextEditingController();
  final _vehicleType = TextEditingController();
  final _vehicles = TextEditingController();
  final _rate = TextEditingController();
  final _weight = TextEditingController();
  final _advancePct = TextEditingController();
  final _halting = TextEditingController();
  final _freeDays = TextEditingController();
  final _otherTerms = TextEditingController();
  final _advanceAmt = TextEditingController();
  final _note = TextEditingController();
  bool _showPayment = true;
  // After-loading amount follows the % until the user types their own figure.
  bool _advanceEdited = false;
  final _nameFocus = FocusNode();
  final List<_ChargeRow> _charges = [];

  bool _busy = false;
  int? _nextNo;

  bool get _isEdit => widget.quote != null;

  @override
  void initState() {
    super.initState();
    final src = widget.quote ?? widget.copyFrom;
    final last = widget.quotes.isEmpty ? null : widget.quotes.first;
    _date = _isEdit ? widget.quote!.date : DateTime.now();
    _pricing = src?.pricing ?? PricingMode.perVehicle;
    _name.text = src?.customerName ?? '';
    _phone.text = src?.customerPhone ?? '';
    _email.text = src?.customerEmail ?? '';
    _cc.text = src != null ? src.ccEmail : bizEmail;
    _address.text = src?.address ?? '';
    _from.text = src?.from ?? '';
    _to.text = src?.to ?? '';
    _cargo.text = src?.cargo ?? '';
    _vehicleType.text = src?.vehicleType ?? '40 ft Trailer';
    _vehicles.text = '${src?.vehicles ?? 1}';
    _rate.text = _num(src?.rate ?? 0);
    _weight.text = _num(src?.weightTons ?? 0);
    _advancePct.text = _num(src?.advancePercent ?? 90);
    _halting.text = _num(src?.haltingPerDay ?? 0);
    _freeDays.text = (src?.haltingFreeDays ?? 0) == 0
        ? ''
        : '${src!.haltingFreeDays}';
    // New quotes reuse the other terms from the latest quote.
    _otherTerms.text = src?.otherTerms ?? last?.otherTerms ?? '';
    _note.text = src?.note ?? '';
    _showPayment = src?.showPayment ?? true;
    for (final c in src?.charges ?? const <QuoteCharge>[]) {
      _addCharge(c.desc, c.mode, c.amount);
    }
    _advanceEdited = src?.advanceOverride != null;
    _advanceAmt.text = _num(src?.advanceOverride ?? 0);
    _syncAdvance();
    if (!_isEdit) {
      _service
          .getNextQuoteNo()
          .then((n) {
            if (mounted) setState(() => _nextNo = n);
          })
          .catchError((_) {});
    }
    for (final c in [_vehicles, _rate, _weight, _advancePct, _from, _to]) {
      c.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _phone,
      _email,
      _cc,
      _address,
      _from,
      _to,
      _cargo,
      _vehicleType,
      _vehicles,
      _rate,
      _weight,
      _advancePct,
      _halting,
      _freeDays,
      _otherTerms,
      _advanceAmt,
      _note,
    ]) {
      c.dispose();
    }
    for (final r in _charges) {
      r.dispose();
    }
    _nameFocus.dispose();
    super.dispose();
  }

  void _syncAdvance() {
    if (_advanceEdited) return;
    final t = _num(_collect().percentAdvance);
    if (_advanceAmt.text != t) _advanceAmt.text = t;
  }

  void _refresh() {
    _syncAdvance();
    setState(() {});
  }

  void _resetAdvance() {
    _advanceEdited = false;
    _refresh();
  }

  void _addCharge(
    String desc, [
    ChargeMode mode = ChargeMode.amount,
    double amount = 0,
  ]) {
    final row = _ChargeRow(desc, mode, amount);
    row.amount.addListener(_refresh);
    _charges.add(row);
    _refresh();
  }

  void _removeCharge(_ChargeRow row) {
    _charges.remove(row);
    row.dispose();
    _refresh();
  }

  QuoteModel _collect() {
    final old = widget.quote;
    final q = QuoteModel(
      id: old?.id ?? '',
      quoteNo: old?.quoteNo ?? 0,
      date: _date,
      customerName: _name.text.trim(),
      customerPhone: _phone.text.trim(),
      customerEmail: _email.text.trim(),
      ccEmail: _cc.text.trim(),
      address: _address.text.trim(),
      from: _from.text.trim(),
      to: _to.text.trim(),
      cargo: _cargo.text.trim(),
      vehicleType: _vehicleType.text.trim(),
      vehicles: int.tryParse(_vehicles.text.trim()) ?? 1,
      pricing: _pricing,
      rate: _parse(_rate.text),
      weightTons: _pricing == PricingMode.perTon ? _parse(_weight.text) : 0,
      charges: [
        for (final r in _charges)
          if (r.desc.text.trim().isNotEmpty)
            QuoteCharge(
              desc: r.desc.text.trim(),
              mode: r.mode,
              amount: r.mode == ChargeMode.amount ? _parse(r.amount.text) : 0,
            ),
      ],
      haltingPerDay: _parse(_halting.text),
      haltingFreeDays: int.tryParse(_freeDays.text.trim()) ?? 0,
      showPayment: _showPayment,
      advancePercent: _advancePct.text.trim().isEmpty
          ? 90
          : _parse(_advancePct.text),
      otherTerms: _otherTerms.text.trim(),
      note: _note.text.trim(),
      status: old?.status ?? QuoteStatus.draft,
      memoIds: old?.memoIds,
      sentVia: old?.sentVia ?? '',
      sentAt: old?.sentAt,
      createdAt: old?.createdAt,
    );
    // Typing the same figure the % gives is not a custom amount.
    final typed = _parse(_advanceAmt.text);
    if (_advanceEdited && typed != q.percentAdvance) q.advanceOverride = typed;
    return q;
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
    final q = _collect();
    if (!_isEdit) q.quoteNo = _nextNo ?? 0;
    await Printing.layoutPdf(
      name: quoteFileName(q),
      onLayout: (_) => buildQuotePdf(q),
    );
  }

  Future<void> _save({required bool send}) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill the fields marked in red')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      var q = _collect();
      if (_isEdit) {
        await _service.updateQuote(q);
      } else {
        q = await _service.createQuote(q);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quotation ${q.quoteNoText} saved')),
      );
      if (send) await showShareQuoteSheet(context, q);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save quotation: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // Unique past customers (latest first) from quotes, then memo parties.
  List<_Customer> get _pastCustomers {
    final seen = <String>{};
    final list = <_Customer>[];
    void add(String name, String phone, String email, String address) {
      if (name.trim().isEmpty || !seen.add(name.trim().toLowerCase())) return;
      list.add(_Customer(name.trim(), phone, email, address));
    }

    for (final q in widget.quotes) {
      add(q.customerName, q.customerPhone, q.customerEmail, q.address);
    }
    for (final m in widget.memos) {
      add(m.transportName, '', '', m.address);
    }
    return list;
  }

  bool _sameRoute(String from, String to) =>
      from.trim().toLowerCase() == _from.text.trim().toLowerCase() &&
      to.trim().toLowerCase() == _to.text.trim().toLowerCase();

  // Latest quote and memo on the same route, as a pricing reference.
  List<String> get _rateHints {
    if (_from.text.trim().isEmpty || _to.text.trim().isEmpty) return const [];
    final hints = <String>[];
    final q = widget.quotes
        .where((x) => x.id != widget.quote?.id && _sameRoute(x.from, x.to))
        .firstOrNull;
    if (q != null) {
      hints.add(
        'Last quote ${q.quoteNoText} (${_shortDate.format(q.date)}): '
        '${freightDescription(q)} · ${q.status.label}',
      );
    }
    final m = widget.memos.where((x) => _sameRoute(x.from, x.to)).firstOrNull;
    if (m != null) {
      hints.add(
        'Last memo ${m.memoNoText} (${_shortDate.format(m.date)}): '
        'hire Rs. ${formatRupees(m.hireFixed)}',
      );
    }
    return hints;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = _collect();
    final title = _isEdit
        ? 'Quotation ${widget.quote!.quoteNoText}'
        : (_nextNo != null
              ? 'New Quotation · Q-${_nextNo.toString().padLeft(4, '0')}'
              : 'New Quotation');
    final hints = _rateHints;
    final perTon = _pricing == PricingMode.perTon;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          // Not a ListView: off-screen fields must exist so Save validates them.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _section(theme, 'Customer'),
                _customerField(),
                _field(_phone, 'Phone', keyboard: TextInputType.phone),
                _field(
                  _email,
                  'Email',
                  keyboard: TextInputType.emailAddress,
                  caps: TextCapitalization.none,
                  validator: _emailCheck,
                ),
                _field(
                  _cc,
                  'CC email',
                  keyboard: TextInputType.emailAddress,
                  caps: TextCapitalization.none,
                  validator: _emailCheck,
                ),
                _field(_address, 'Address', maxLines: 3),
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
                  _cargo,
                  'Cargo',
                  helper: 'e.g. Steel coils, Machinery',
                  caps: TextCapitalization.sentences,
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: _field(_vehicleType, 'Vehicle type'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _field(
                        _vehicles,
                        'No. of vehicles',
                        keyboard: TextInputType.number,
                        validator: (v) =>
                            (int.tryParse((v ?? '').trim()) ?? 0) < 1
                            ? 'Min 1'
                            : null,
                      ),
                    ),
                  ],
                ),
                _section(theme, 'Rate'),
                SegmentedButton<PricingMode>(
                  segments: const [
                    ButtonSegment(
                      value: PricingMode.perVehicle,
                      label: Text('Per vehicle'),
                      icon: Icon(Icons.local_shipping_rounded),
                    ),
                    ButtonSegment(
                      value: PricingMode.perTon,
                      label: Text('Per ton'),
                      icon: Icon(Icons.scale_rounded),
                    ),
                  ],
                  selected: {_pricing},
                  onSelectionChanged: (s) {
                    _pricing = s.first;
                    _refresh();
                  },
                ),
                const SizedBox(height: 12),
                for (final h in hints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(h, style: theme.textTheme.bodySmall),
                        ),
                      ],
                    ),
                  ),
                if (hints.isNotEmpty) const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        _rate,
                        perTon ? 'Rate per ton' : 'Rate per vehicle',
                        money: true,
                        validator: (v) =>
                            _parse(v ?? '') <= 0 ? 'Enter rate' : null,
                      ),
                    ),
                    if (perTon) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          _weight,
                          'Weight (tons)',
                          keyboard: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) =>
                              _parse(v ?? '') <= 0 ? 'Enter weight' : null,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  'Freight: ${freightDescription(q)} = Rs. ${formatRupees(q.freight)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                _section(theme, 'Extra charges'),
                for (final r in _charges) _chargeRow(r),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final d in [
                      'Loading',
                      'Unloading',
                      'Toll',
                      'Escort',
                      'Permit',
                    ])
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 16),
                        label: Text(d),
                        onPressed: () => _addCharge(d),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 16),
                      label: const Text('Other'),
                      onPressed: () => _addCharge(''),
                    ),
                  ],
                ),
                _section(theme, 'Payment terms'),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: _showPayment,
                  title: const Text('Include payment terms'),
                  subtitle: const Text(
                    'Untick for clients without payment terms',
                  ),
                  onChanged: (v) {
                    FocusManager.instance.primaryFocus?.unfocus();
                    setState(() => _showPayment = v ?? true);
                  },
                ),
                if (_showPayment) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _field(
                          _advancePct,
                          'After loading %',
                          keyboard: TextInputType.number,
                          validator: (v) {
                            final p = _parse(v ?? '');
                            return p < 0 || p > 100 ? '0 to 100' : null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _field(
                          _advanceAmt,
                          'After loading amount',
                          money: true,
                          helper: q.isCustomSplit
                              ? '${_num(q.advancePercent)}% = Rs. ${formatRupees(q.percentAdvance)}'
                              : 'Type to round, e.g. 50000',
                          onChanged: (_) {
                            _advanceEdited = true;
                            setState(() {});
                          },
                          validator: (v) {
                            final a = _parse(v ?? '');
                            return a < 0 || a > q.total
                                ? 'Max Rs. ${formatRupees(q.total)}'
                                : null;
                          },
                        ),
                      ),
                    ],
                  ),
                  if (q.isCustomSplit)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _resetAdvance,
                        icon: const Icon(Icons.restart_alt_rounded, size: 18),
                        label: Text(
                          'Use ${_num(q.advancePercent)}% (Rs. ${formatRupees(q.percentAdvance)})',
                        ),
                      ),
                    ),
                ],
                _section(theme, 'Halting'),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _field(
                        _halting,
                        'Halting / day',
                        money: true,
                        helper: 'Blank = no halting term',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        _freeDays,
                        'Free days',
                        keyboard: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                _section(theme, 'Note & other terms'),
                _field(
                  _note,
                  'Note (optional)',
                  maxLines: 4,
                  caps: TextCapitalization.sentences,
                  helper:
                      'Printed in a Note box, e.g. "Vehicle available from 20th"',
                ),
                _field(
                  _otherTerms,
                  'Other terms (one per line)',
                  maxLines: 5,
                  caps: TextCapitalization.sentences,
                  helper: 'Payment and halting terms are added automatically',
                ),
                _summary(theme, q),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              IconButton.outlined(
                tooltip: 'Preview',
                onPressed: _busy ? null : _preview,
                icon: const Icon(Icons.visibility_rounded),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy ? null : () => _save(send: false),
                child: const Text('Save'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _save(send: true),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: const Text('Save & Send'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _emailCheck(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty || _emailRe.hasMatch(t) ? null : 'Invalid email';
  }

  Widget _summary(ThemeData theme, QuoteModel q) {
    Widget row(String l, double v, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            l,
            style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
          const Spacer(),
          Text(
            'Rs. ${formatRupees(v)}',
            style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null,
          ),
        ],
      ),
    );
    return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            row('Freight', q.freight),
            if (q.extrasTotal > 0) row('Extra charges', q.extrasTotal),
            const Divider(),
            row('Total', q.total, bold: true),
            if (q.showPayment) ...[
              row(
                q.isCustomSplit
                    ? 'After loading'
                    : 'After loading (${_num(q.advancePercent)}%)',
                q.advanceAmount,
              ),
              row(
                q.isCustomSplit
                    ? 'Balance after unloading'
                    : 'After unloading (${_num(q.balancePercent)}%)',
                q.balanceAmount,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Two lines per charge so the type label fits on narrow phones.
  Widget _chargeRow(_ChargeRow r) {
    return Card(
      key: ObjectKey(r),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: r.desc,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _deco('Charge'),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => _removeCharge(r),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<ChargeMode>(
                      initialValue: r.mode,
                      isExpanded: true,
                      decoration: _deco('Type'),
                      items: [
                        for (final m in ChargeMode.values)
                          DropdownMenuItem(value: m, child: Text(m.label)),
                      ],
                      onChanged: (m) {
                        r.mode = m ?? ChargeMode.amount;
                        _refresh();
                      },
                    ),
                  ),
                  if (r.mode == ChargeMode.amount) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: r.amount,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: _deco('Amount', prefix: '₹ '),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          return t.isNotEmpty &&
                                  double.tryParse(t.replaceAll(',', '')) == null
                              ? 'Number'
                              : null;
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String label, {String? helper, String? prefix}) =>
      InputDecoration(
        labelText: label,
        helperText: helper,
        prefixText: prefix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  Widget _section(ThemeData theme, String title) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
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
    TextInputType? keyboard,
    TextCapitalization caps = TextCapitalization.words,
    FormFieldValidator<String>? validator,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      // Keyed so a field keeps its own state (and focus) when sections above it appear or hide.
      key: ValueKey('field-$label'),
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        onChanged: onChanged,
        maxLines: maxLines,
        minLines: 1,
        textCapitalization: money ? TextCapitalization.none : caps,
        keyboardType: money
            ? const TextInputType.numberWithOptions(decimal: true)
            : keyboard ??
                  (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
        decoration: _deco(label, helper: helper, prefix: money ? '₹ ' : null),
        validator: (v) {
          final t = (v ?? '').trim();
          if (required && t.isEmpty) return 'Required';
          if (money &&
              t.isNotEmpty &&
              double.tryParse(t.replaceAll(',', '')) == null) {
            return 'Enter a number';
          }
          return validator?.call(v);
        },
      ),
    );
  }

  // Customer name with suggestions; picking one fills phone, email and address.
  Widget _customerField() {
    final customers = _pastCustomers;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: RawAutocomplete<_Customer>(
        textEditingController: _name,
        focusNode: _nameFocus,
        displayStringForOption: (c) => c.name,
        optionsBuilder: (value) {
          final t = value.text.trim().toLowerCase();
          if (t.isEmpty) return const [];
          return customers
              .where((c) => c.name.toLowerCase().contains(t))
              .take(6);
        },
        onSelected: (c) {
          if (c.phone.isNotEmpty) _phone.text = c.phone;
          if (c.email.isNotEmpty) _email.text = c.email;
          if (c.address.isNotEmpty) _address.text = c.address;
        },
        fieldViewBuilder: (context, controller, focusNode, onSubmit) =>
            TextFormField(
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              decoration: _deco('Customer / Company name'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Required' : null,
            ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, maxWidth: 360),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final c in options)
                    ListTile(
                      title: Text(c.name),
                      subtitle: Text(
                        [
                          c.phone,
                          c.email,
                          c.address,
                        ].where((s) => s.isNotEmpty).join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => onSelected(c),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
