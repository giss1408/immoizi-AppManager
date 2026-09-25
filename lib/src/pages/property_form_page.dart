import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../api/queries.dart';
import '../models/dashboard.dart';
import '../property_edit_context.dart';

/// Creates a listing, or edits the details of [property] when given.
/// Pops with the saved [Property].
class PropertyFormPage extends StatefulWidget {
  const PropertyFormPage({required this.editContext, this.property, super.key});

  final PropertyEditContext editContext;
  final Property? property;

  @override
  State<PropertyFormPage> createState() => _PropertyFormPageState();
}

class _PropertyFormPageState extends State<PropertyFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final Property? _initial = widget.property;
  late final _title = TextEditingController(text: _initial?.title ?? '');
  late final _city = TextEditingController(text: _initial?.city ?? 'Abidjan');
  late final _district = TextEditingController(text: _initial?.district ?? '');
  late final _rooms =
      TextEditingController(text: _initial == null ? '' : '${_initial.rooms}');
  late final _surface = TextEditingController(
      text: _initial == null || _initial.surface == 0
          ? ''
          : '${_initial.surface}');
  late final _price =
      TextEditingController(text: _initial == null ? '' : '${_initial.price}');
  late final _description =
      TextEditingController(text: _initial?.description ?? '');
  late final _weeklyPrice = TextEditingController(
      text: _initial?.weeklyPrice == null ? '' : '${_initial!.weeklyPrice}');
  late RentalType _rentalType = _initial?.rentalType ?? RentalType.longTerm;
  late String? _categoryId = _initialCategoryId();
  late String _status = _initialStatus();
  bool _saving = false;
  String? _error;

  bool get _isNew => _initial == null;
  List<CategoryOption> get _categories => widget.editContext.categories;

  String? _initialCategoryId() {
    final title = _initial?.category;
    for (final category in _categories) {
      if (category.title == title) return category.id;
    }
    return _isNew && _categories.isNotEmpty ? _categories.first.id : null;
  }

  String _initialStatus() {
    final value = listingStatusValue(_initial?.status ?? 'available');
    return listingStatusLabels.containsKey(value) ? value : 'available';
  }

  @override
  void dispose() {
    for (final controller in [
      _title,
      _city,
      _district,
      _rooms,
      _surface,
      _price,
      _description,
      _weeklyPrice
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final variables = {
      'title': _title.text.trim(),
      'categoryId': _categoryId,
      'city': _city.text.trim(),
      'district': _district.text.trim(),
      'rooms': int.parse(_rooms.text.trim()),
      'surfaceM2': int.tryParse(_surface.text.trim()) ?? 0,
      'price': int.parse(_price.text.trim()),
      'description': _description.text.trim(),
      'listingStatus': _status,
      'rentalType': _rentalType.apiValue,
      'weeklyPrice': _rentalType == RentalType.shortTerm
          ? int.tryParse(_weeklyPrice.text.trim())
          : null,
    };
    try {
      final data = await widget.editContext.client.query(
        widget.editContext.endpoint,
        widget.editContext.token,
        _isNew ? createPropertyListingMutation : updatePropertyListingMutation,
        variables:
            _isNew ? variables : {'propertyId': _initial!.id, ...variables},
      );
      final payload =
          data[_isNew ? 'createPropertyListing' : 'updatePropertyListing']
              as Map<String, dynamic>;
      final saved =
          Property.fromJson(payload['property'] as Map<String, dynamic>);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (exception) {
      if (mounted) setState(() => _error = describeError(exception));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value) =>
      (value == null || value.trim().isEmpty) ? 'Champ obligatoire' : null;

  String? _number(String? value, {bool required = true}) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return required ? 'Champ obligatoire' : null;
    return int.tryParse(text) == null ? 'Nombre entier attendu' : null;
  }

  InputDecoration _decoration(String label, IconData icon, {String? suffix}) =>
      InputDecoration(
          labelText: label, prefixIcon: Icon(icon), suffixText: suffix);

  @override
  Widget build(BuildContext context) {
    final digitsOnly = [FilteringTextInputFormatter.digitsOnly];
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Ajouter un bien' : 'Modifier les informations'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                decoration: _decoration('Titre de l’annonce', Icons.title),
                validator: _required,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _categoryId,
                decoration: _decoration('Catégorie', Icons.sell_outlined),
                items: [
                  for (final category in _categories)
                    DropdownMenuItem(
                        value: category.id, child: Text(category.title)),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
                validator: (value) =>
                    value == null ? 'Choisissez une catégorie' : null,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _city,
                    decoration: _decoration('Ville', Icons.location_city),
                    validator: _required,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _district,
                    decoration: _decoration('Quartier', Icons.place_outlined),
                    validator: _required,
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: TextFormField(
                    controller: _rooms,
                    keyboardType: TextInputType.number,
                    inputFormatters: digitsOnly,
                    decoration: _decoration('Pièces', Icons.bed_outlined),
                    validator: _number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _surface,
                    keyboardType: TextInputType.number,
                    inputFormatters: digitsOnly,
                    decoration:
                        _decoration('Surface', Icons.square_foot, suffix: 'm²'),
                    validator: (value) => _number(value, required: false),
                  ),
                ),
              ]),
              const SizedBox(height: 16),
              const Text('Type de location',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<RentalType>(
                segments: const [
                  ButtonSegment(
                      value: RentalType.longTerm,
                      icon: Icon(Icons.calendar_month),
                      label: Text('Au mois')),
                  ButtonSegment(
                      value: RentalType.shortTerm,
                      icon: Icon(Icons.nights_stay),
                      label: Text('Courte durée')),
                ],
                selected: {_rentalType},
                onSelectionChanged: (selection) =>
                    setState(() => _rentalType = selection.first),
              ),
              if (_rentalType == RentalType.shortTerm)
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
                  child: MutedText(
                      'Appartement meublé loué à la nuit ou à la semaine.'),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType: TextInputType.number,
                inputFormatters: digitsOnly,
                decoration: _decoration(
                    _rentalType == RentalType.shortTerm
                        ? 'Prix par nuit'
                        : 'Loyer mensuel',
                    Icons.payments,
                    suffix: 'FCFA'),
                validator: _number,
              ),
              if (_rentalType == RentalType.shortTerm) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weeklyPrice,
                  keyboardType: TextInputType.number,
                  inputFormatters: digitsOnly,
                  decoration: _decoration(
                      'Prix par semaine (facultatif)', Icons.date_range,
                      suffix: 'FCFA'),
                  validator: (value) => _number(value, required: false),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _status,
                decoration: _decoration('Statut', Icons.flag_outlined),
                items: [
                  for (final entry in listingStatusLabels.entries)
                    DropdownMenuItem(
                        value: entry.key, child: Text(entry.value)),
                ],
                onChanged: (value) =>
                    setState(() => _status = value ?? 'available'),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 6, 4, 0),
                child: MutedText(
                    'Seuls les biens « Disponible » apparaissent dans la recherche des locataires.'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                minLines: 4,
                maxLines: 8,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  alignLabelWithHint: true,
                  hintText: 'Points forts, équipements, proximité…',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                ErrorCard(_error!),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(_isNew ? Icons.add_home_outlined : Icons.save),
                label: Text(_saving
                    ? 'Enregistrement…'
                    : _isNew
                        ? 'Créer le bien'
                        : 'Enregistrer'),
              ),
              if (_isNew)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: MutedText(
                      'Vous pourrez ajouter les photos et la vidéo juste après.'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
