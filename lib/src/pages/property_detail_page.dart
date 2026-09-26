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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: IvoryColors.green,
        foregroundColor: IvoryColors.onPrimary,
        title: Text(current.title),
        actions: [
          if (canEdit)
            IconButton(
              onPressed: _openEditSheet,
              icon: const Icon(Icons.edit),
              tooltip: tr('Modifier l\u2019annonce'),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      current.title,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Chip(
                      label: Text(listingStatusLabel(current.status)),
                      backgroundColor: IvoryColors.orange.withOpacity(0.15)),
                ],
              ),
              const SizedBox(height: 16),
              PropertyDetails(property: current),
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
          ),
        ),
      ),
    );
  }
}

class PropertyDetails extends StatelessWidget {
  const PropertyDetails({required this.property, super.key});

  final Property property;

  List<String> get _allImages => [
        if (property.mainImageUrl != null) property.mainImageUrl!,
        ...property.galleryImageUrls,
      ];

  void _openViewer(BuildContext context, int index) {
    final images = _allImages;
    if (images.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ImageViewerPage(images: images, initialIndex: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (property.mainImageUrl != null)
          GestureDetector(
            onTap: () => _openViewer(context, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                property.mainImageUrl!,
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const MediaPlaceholder(icon: Icons.image_not_supported),
              ),
            ),
          )
        else
          const MediaPlaceholder(icon: Icons.photo_camera_back),
        if (property.galleryImageUrls.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: property.galleryImageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _openViewer(
                    context, (property.mainImageUrl != null ? 1 : 0) + index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    property.galleryImageUrls[index],
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(Icons.broken_image, size: 20)),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DetailChip(icon: Icons.category, label: property.category),
            DetailChip(
                icon: Icons.place,
                label: '${property.city}, ${property.district}'),
            DetailChip(icon: Icons.payments, label: property.priceLabel),
            if (property.weeklyPriceLabel != null)
              DetailChip(
                  icon: Icons.date_range, label: property.weeklyPriceLabel!),
            DetailChip(
                icon: property.isShortTerm
                    ? Icons.nights_stay
                    : Icons.calendar_month,
                label: property.rentalType.label),
            DetailChip(
                icon: Icons.meeting_room,
                label: tr('{count} pièces', {'count': property.rooms})),
            DetailChip(
                icon: Icons.square_foot, label: '${property.surface} m\u00b2'),
            DetailChip(
                icon: Icons.verified,
                label: listingStatusLabel(property.status)),
            if (property.hasVideo)
              DetailChip(
                  icon: Icons.videocam, label: tr('Vid\u00e9o disponible')),
          ],
        ),
        if (property.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Description',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(property.description, style: TextStyle(color: IvoryColors.ink)),
        ],
        if (property.videoUrl != null) ...[
          const SizedBox(height: 12),
          VideoCard(videoUrl: property.videoUrl!, title: property.title),
        ],
      ],
    );
  }
}
