import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../api/queries.dart';
import '../api/rest_client.dart';
import '../property_edit_context.dart';

class EditListingSheet extends StatefulWidget {
  const EditListingSheet(
      {required this.property, required this.editContext, super.key});

  final Property property;
  final PropertyEditContext editContext;

  @override
  State<EditListingSheet> createState() => _EditListingSheetState();
}

class _EditListingSheetState extends State<EditListingSheet> {
  late final priceController =
      TextEditingController(text: widget.property.price.toString());
  late final descriptionController =
      TextEditingController(text: widget.property.description);
  late Property current = widget.property;
  bool savingText = false;
  bool uploadingImage = false;
  bool uploadingVideo = false;
  bool deletingMedia = false;
  String? error;

  @override
  void dispose() {
    priceController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveText() async {
    setState(() {
      savingText = true;
      error = null;
    });
    try {
      final price = int.tryParse(priceController.text.trim());
      final data = await GraphQLClient().query(
        widget.editContext.endpoint,
        widget.editContext.token,
        updatePropertyListingMutation,
        variables: {
          'propertyId': current.id,
          'price': price,
          'description': descriptionController.text.trim(),
        },
      );
      final updated =
          data['updatePropertyListing']['property'] as Map<String, dynamic>;
      setState(() {
        current = current.copyWith(
          price: updated['price'] as int?,
          description: updated['description'] as String?,
        );
      });
    } catch (exception) {
      if (mounted) {
        setState(() => error =
            'Impossible d\u2019enregistrer : ${describeError(exception)}');
      }
    } finally {
      if (mounted) setState(() => savingText = false);
    }
  }

  Future<void> _pickAndUpload({required bool isVideo}) async {
    if (current.id == null || widget.editContext.token.isEmpty) {
      setState(() => error =
          'Mode démo : connectez-vous comme bailleur et synchronisez une annonce réelle avant de téléverser des médias.');
      return;
    }

    String? slot;
    if (!isVideo) {
      slot = _nextImageSlot();
      if (slot == null) {
        setState(
            () => error = 'Maximum de 5 photos atteint pour cette annonce.');
        return;
      }
    }

    setState(() {
      if (isVideo) {
        uploadingVideo = true;
      } else {
        uploadingImage = true;
      }
      error = null;
    });

    try {
      final picker = ImagePicker();
      final file = isVideo
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(
              source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;

      MediaType? contentType;
      if (isVideo) {
        contentType = videoMediaType(file.path);
        if (contentType == null) {
          throw const ServerException(
              'Format vidéo non pris en charge (MP4, WebM ou MOV).');
        }
        if (await file.length() > maxVideoBytes) {
          throw const ServerException('Vidéo trop lourde (10 Mo maximum).');
        }
      }

      final uri = Uri.parse(
          '${widget.editContext.mediaEndpoint}/api/properties/${current.id}/media');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${widget.editContext.token}'
        ..fields['slot'] = slot ?? 'main_image';
      request.files.add(
        await http.MultipartFile.fromPath(
          isVideo ? 'video' : 'image',
          file.path,
          contentType: contentType,
        ),
      );
      final data = await sendRest(request);
      setState(() {
        current = current.copyWith(
          mainImageUrl: data['mainImageUrl'] as String?,
          galleryImageUrls:
              (data['galleryImageUrls'] as List<dynamic>? ?? const [])
                  .cast<String>(),
          galleryImageSlots:
              (data['galleryImageSlots'] as List<dynamic>? ?? const [])
                  .cast<String>(),
          hasVideo: data['videoUrl'] != null,
          videoUrl: data['videoUrl'] as String?,
        );
      });
    } catch (exception) {
      if (mounted) {
        setState(() =>
            error = 'Téléchargement impossible : ${describeError(exception)}');
      }
    } finally {
      if (mounted) {
        setState(() {
          uploadingImage = false;
          uploadingVideo = false;
        });
      }
    }
  }

  Future<void> _deleteMedia({required String slot}) async {
    if (current.id == null || widget.editContext.token.isEmpty) {
      setState(() => error =
          'Mode démo : connectez-vous comme bailleur pour supprimer ce média.');
      return;
    }

    setState(() {
      deletingMedia = true;
      error = null;
    });

    try {
      final uri = Uri.parse(
              '${widget.editContext.mediaEndpoint}/api/properties/${current.id}/media')
          .replace(
        queryParameters: {'slot': slot},
      );
      final request = http.Request('DELETE', uri)
        ..headers['Authorization'] = 'Bearer ${widget.editContext.token}';
      final data = await sendRest(request);
      setState(() {
        current = current.copyWith(
          mainImageUrl: data['mainImageUrl'] as String?,
          galleryImageUrls:
              (data['galleryImageUrls'] as List<dynamic>? ?? const [])
                  .cast<String>(),
          galleryImageSlots:
              (data['galleryImageSlots'] as List<dynamic>? ?? const [])
                  .cast<String>(),
          hasVideo: data['videoUrl'] != null,
          videoUrl: data['videoUrl'] as String?,
          clearMainImage: slot == 'main_image',
          clearVideo: slot == 'video',
        );
      });
    } catch (exception) {
      if (mounted) {
        setState(() =>
            error = 'Suppression impossible : ${describeError(exception)}');
      }
    } finally {
      if (mounted) setState(() => deletingMedia = false);
    }
  }

  /// Next free image slot (main first, then the first unused gallery slot).
  String? _nextImageSlot() {
    if (current.mainImageUrl == null) return 'main_image';
    final occupiedSlots = current.galleryImageSlots.isNotEmpty
        ? current.galleryImageSlots.toSet()
        : {
            for (var index = 1;
                index <= current.galleryImageUrls.length;
                index++)
              'image_$index'
          };
    for (var index = 1; index <= 4; index++) {
      final slot = 'image_$index';
      if (!occupiedSlots.contains(slot)) return slot;
    }
    return null;
  }

  int get _imageCount =>
      (current.mainImageUrl == null ? 0 : 1) + current.galleryImageUrls.length;

  Widget _mediaThumbnail(String url, String slot) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 64,
                height: 64,
                color: const Color(0xFFFFE8E8),
                child: const Icon(Icons.broken_image_outlined,
                    color: Colors.redAccent, size: 24),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: deletingMedia ? null : () => _deleteMedia(slot: slot),
              icon: const Icon(Icons.close, color: Colors.white, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                padding: const EdgeInsets.all(2),
                minimumSize: const Size(22, 22),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              tooltip: 'Supprimer la photo',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Modifier l\u2019annonce',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Prix (FCFA)', prefixIcon: Icon(Icons.payments)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(
                  labelText: 'Description',
                  prefixIcon: Icon(Icons.description)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: savingText ? null : _saveText,
              icon: savingText
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(savingText
                  ? 'Enregistrement...'
                  : 'Enregistrer prix & description'),
            ),
            const SizedBox(height: 20),
            if (_imageCount > 0) ...[
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (current.mainImageUrl != null)
                      _mediaThumbnail(
                        current.mainImageUrl!,
                        'main_image',
                      ),
                    for (var index = 0;
                        index < current.galleryImageUrls.length;
                        index++)
                      _mediaThumbnail(
                        current.galleryImageUrls[index],
                        index < current.galleryImageSlots.length
                            ? current.galleryImageSlots[index]
                            : 'image_${index + 1}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (current.videoUrl != null) ...[
              Row(
                children: [
                  const Icon(Icons.videocam, color: IvoryColors.green),
                  const SizedBox(width: 8),
                  const Expanded(
                      child: Text('Vidéo de présentation',
                          style: TextStyle(fontWeight: FontWeight.w700))),
                  IconButton(
                    onPressed: deletingMedia
                        ? null
                        : () => _deleteMedia(slot: 'video'),
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    tooltip: 'Supprimer la vidéo',
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        (uploadingImage || deletingMedia || _imageCount >= 5)
                            ? null
                            : () => _pickAndUpload(isVideo: false),
                    icon: uploadingImage
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo_camera),
                    label: Text('Photo ($_imageCount/5)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (uploadingVideo || deletingMedia)
                        ? null
                        : () => _pickAndUpload(isVideo: true),
                    icon: uploadingVideo
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.videocam),
                    label: const Text('Vid\u00e9o'),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              ErrorCard(error!),
            ],
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(current),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}
