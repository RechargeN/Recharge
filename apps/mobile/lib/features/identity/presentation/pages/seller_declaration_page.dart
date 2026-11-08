import 'package:flutter/material.dart';

import '../../../../core/localization/l10n_context.dart';
import '../../data/seller_declaration_gateway.dart';
import '../../domain/entities/seller_declaration.dart';

/// ADR 0023 (2026-11-08, DSA Art. 30): the author's own seller details. The
/// server decides; this form only collects and sends them. Without a backend
/// binding the page says the details are unavailable.
class SellerDeclarationPage extends StatefulWidget {
  const SellerDeclarationPage({super.key, required this.gateway});

  /// Null when no backend is bound (local mock, production disabled).
  final Future<SellerDeclarationGateway?> gateway;

  @override
  State<SellerDeclarationPage> createState() => _SellerDeclarationPageState();
}

class _SellerDeclarationPageState extends State<SellerDeclarationPage> {
  final GlobalKey<FormState> _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _fields =
      <String, TextEditingController>{
        for (final String id in const <String>[
          'email',
          'phone',
          'legalName',
          'registrationNumber',
          'vatId',
          'line1',
          'city',
          'postalCode',
          'countryCode',
        ])
          id: TextEditingController(),
      };
  SellerDeclarationGateway? _gateway;
  SellerStatus _status = SellerStatus.private;
  final Set<Dac7ActivityType> _activities = <Dac7ActivityType>{};
  int _revision = 0;
  bool _loading = true;
  bool _saving = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    // The save button and the contact hint follow the two contact fields.
    _fields['email']!.addListener(_contactChanged);
    _fields['phone']!.addListener(_contactChanged);
    _load();
  }

  void _contactChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _fields.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final SellerDeclarationGateway? gateway = await widget.gateway;
      _gateway = gateway;
      if (gateway == null) {
        _fail('unavailable');
        return;
      }
      final SellerDeclarationRecord record = await gateway.read();
      _revision = record.revision;
      final SellerDeclaration? stored = record.declaration;
      if (stored != null) {
        _status = stored.status;
        _activities
          ..clear()
          ..addAll(stored.dac7ActivityTypes);
        _fields['email']!.text = stored.email ?? '';
        _fields['phone']!.text = stored.phone ?? '';
        final TraderDetails? trader = stored.trader;
        if (trader != null) {
          _fields['legalName']!.text = trader.legalName;
          _fields['registrationNumber']!.text = trader.registrationNumber;
          _fields['vatId']!.text = trader.vatId ?? '';
          _fields['line1']!.text = trader.address.line1;
          _fields['city']!.text = trader.address.city;
          _fields['postalCode']!.text = trader.address.postalCode;
          _fields['countryCode']!.text = trader.address.countryCode;
        }
      }
    } on SellerDeclarationFailure catch (error) {
      _fail(error.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fail(String code) {
    if (!mounted) return;
    setState(() {
      _messageIsError = true;
      _message = code;
    });
  }

  String _messageText(BuildContext context, String code) => switch (code) {
    'saved' => context.l10n.sellerSaved,
    'invalid_contract' => context.l10n.sellerInvalid,
    'revision_conflict' => context.l10n.sellerConflict,
    _ => context.l10n.sellerUnavailable,
  };

  String _text(String id) => _fields[id]!.text.trim();

  Future<void> _save() async {
    final SellerDeclarationGateway? gateway = _gateway;
    if (gateway == null || !(_form.currentState?.validate() ?? false)) return;
    final SellerDeclaration declaration = SellerDeclaration(
      status: _status,
      email: _text('email').isEmpty ? null : _text('email'),
      phone: _text('phone').isEmpty ? null : _text('phone'),
      trader: _status == SellerStatus.trader
          ? TraderDetails(
              legalName: _text('legalName'),
              registrationNumber: _text('registrationNumber'),
              vatId: _text('vatId').isEmpty ? null : _text('vatId'),
              address: SellerAddress(
                line1: _text('line1'),
                city: _text('city'),
                postalCode: _text('postalCode'),
                countryCode: _text('countryCode'),
              ),
            )
          : null,
      dac7ActivityTypes: Set<Dac7ActivityType>.of(_activities),
    );
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final SellerDeclarationRecord record = await gateway.declare(
        declaration,
        expectedRevision: _revision,
      );
      _revision = record.revision;
      if (mounted) {
        setState(() {
          _messageIsError = false;
          _message = 'saved';
        });
      }
    } on SellerDeclarationFailure catch (error) {
      _fail(error.code);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String id,
    String label, {
    bool required = false,
    TextInputType? keyboard,
    String? Function(String value)? check,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        key: ValueKey<String>('seller-$id'),
        controller: _fields[id],
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          border: const OutlineInputBorder(),
        ),
        validator: (String? raw) {
          final String value = (raw ?? '').trim();
          if (required && value.isEmpty) return context.l10n.sellerInvalid;
          if (value.isNotEmpty && check != null) return check(value);
          return null;
        },
      ),
    );
  }

  String? _contactCheck() {
    if (_text('email').isEmpty && _text('phone').isEmpty) {
      return context.l10n.sellerContactHint;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool trader = _status == SellerStatus.trader;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.sellerDataTitle)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: <Widget>[
                  Text(context.l10n.sellerDataIntro),
                  const SizedBox(height: 16),
                  SegmentedButton<SellerStatus>(
                    key: const ValueKey<String>('seller-status'),
                    segments: <ButtonSegment<SellerStatus>>[
                      ButtonSegment<SellerStatus>(
                        value: SellerStatus.private,
                        label: Text(context.l10n.sellerStatusPrivate),
                      ),
                      ButtonSegment<SellerStatus>(
                        value: SellerStatus.trader,
                        label: Text(context.l10n.sellerStatusTrader),
                      ),
                    ],
                    selected: <SellerStatus>{_status},
                    onSelectionChanged: (Set<SellerStatus> selected) =>
                        setState(() => _status = selected.single),
                  ),
                  const SizedBox(height: 16),
                  _field(
                    'email',
                    context.l10n.sellerEmail,
                    keyboard: TextInputType.emailAddress,
                    check: (String value) =>
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(value)
                        ? null
                        : context.l10n.sellerInvalid,
                  ),
                  _field(
                    'phone',
                    context.l10n.sellerPhone,
                    keyboard: TextInputType.phone,
                    check: (String value) =>
                        RegExp(
                          r'^\+[1-9][0-9]{6,14}$',
                        ).hasMatch(value.replaceAll(' ', ''))
                        ? null
                        : context.l10n.sellerInvalid,
                  ),
                  Builder(
                    builder: (BuildContext context) {
                      final String? hint = _contactCheck();
                      return hint == null
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(hint),
                            );
                    },
                  ),
                  if (trader) ...<Widget>[
                    _field(
                      'legalName',
                      context.l10n.sellerLegalName,
                      required: true,
                    ),
                    _field(
                      'registrationNumber',
                      context.l10n.sellerRegistrationNumber,
                      required: true,
                    ),
                    _field('vatId', context.l10n.sellerVatId),
                    _field(
                      'line1',
                      context.l10n.sellerAddressLine,
                      required: true,
                    ),
                    _field('city', context.l10n.sellerCity, required: true),
                    _field(
                      'postalCode',
                      context.l10n.sellerPostalCode,
                      required: true,
                    ),
                    _field(
                      'countryCode',
                      context.l10n.sellerCountryCode,
                      required: true,
                      check: (String value) =>
                          RegExp(r'^[A-Za-z]{2}$').hasMatch(value)
                          ? null
                          : context.l10n.sellerInvalid,
                    ),
                  ],
                  Text(
                    context.l10n.sellerDac7Title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  for (final Dac7ActivityType type in Dac7ActivityType.values)
                    CheckboxListTile(
                      key: ValueKey<String>('seller-dac7-${type.name}'),
                      contentPadding: EdgeInsets.zero,
                      value: _activities.contains(type),
                      title: Text(switch (type) {
                        Dac7ActivityType.personalServices =>
                          context.l10n.sellerDac7Services,
                        Dac7ActivityType.rentalOfGoods =>
                          context.l10n.sellerDac7Rental,
                      }),
                      onChanged: (bool? on) => setState(
                        () => on == true
                            ? _activities.add(type)
                            : _activities.remove(type),
                      ),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const ValueKey<String>('seller-save'),
                    onPressed:
                        _saving || _gateway == null || _contactCheck() != null
                        ? null
                        : _save,
                    child: Text(context.l10n.sellerSave),
                  ),
                  if (_message != null) ...<Widget>[
                    const SizedBox(height: 12),
                    Text(
                      _messageText(context, _message!),
                      key: const ValueKey<String>('seller-message'),
                      style: TextStyle(
                        color: _messageIsError
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
