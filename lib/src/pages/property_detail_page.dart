import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../property_edit_context.dart';
import 'edit_listing_sheet.dart';

class PropertyDetailPage extends StatefulWidget {
  const PropertyDetailPage(
      {required this.property,
      required this.editContext,
      this.openEditor = false,
      super.key});

  final Property property;
  final PropertyEditContext editContext;

  /// Opens the editor right away, e.g. to add photos to a new listing.
  final bool openEditor;

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  late Property current = widget.property;

  @override
  void initState() {
    super.initState();
    if (widget.openEditor) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openEditSheet();
      });
    }
  }

  Future<void> _openEditSheet() async {
    final updated = await showModalBottomSheet<Property>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) =>
          EditListingSheet(property: current, editContext: widget.editContext),
    );
    if (updated != null && mounted) {
      setState(() => current = updated);
      widget.editContext.onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.editContext.canEdit && current.id != null;
    return PropertyPageScaffold(
      title: current.title,
      statusLabel: listingStatusLabel(current.status),
      actions: [
        if (canEdit)
          IconButton(
            onPressed: _openEditSheet,
            icon: const Icon(Icons.edit),
            tooltip: tr('Modifier l\u2019annonce'),
          ),
      ],
      children: [
        PropertyDetails(property: current, showListingStatus: true),
        if (!canEdit) ...[
          const SizedBox(height: 16),
          MutedText(
            current.id == null
                ? tr(
                    'Mode démonstration : connectez-vous comme bailleur et synchronisez une annonce réelle pour téléverser des photos ou une vidéo.')
                : tr(
                    'Connectez-vous en tant que bailleur pour modifier cette annonce.'),
          ),
        ],
      ],
    );
  }
}
