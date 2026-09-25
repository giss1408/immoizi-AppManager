import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:immoizi_core/immoizi_core.dart';

import '../api/rest_client.dart';
import '../property_edit_context.dart';

class ContractUploadCard extends StatelessWidget {
  const ContractUploadCard(
      {required this.properties, required this.editContext, super.key});

  final List<Property> properties;
  final PropertyEditContext editContext;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: IvoryColors.green.withOpacity(0.08),
      child: ListTile(
        leading: const Icon(Icons.upload_file, color: IvoryColors.green),
        title: const Text('Ajouter un contrat de location'),
        subtitle: const Text('Associer un bail à une propriété louée'),
        onTap: editContext.canEdit
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LeaseContractUploadPage(
                        properties: properties, editContext: editContext),
                  ),
                )
            : null,
      ),
    );
  }
}

class LeaseContractUploadPage extends StatefulWidget {
  const LeaseContractUploadPage(
      {required this.properties, required this.editContext, super.key});

  final List<Property> properties;
  final PropertyEditContext editContext;

  @override
  State<LeaseContractUploadPage> createState() =>
      _LeaseContractUploadPageState();
}

class _LeaseContractUploadPageState extends State<LeaseContractUploadPage> {
  final titleController = TextEditingController(text: 'Contrat de location');
  String? propertyId;
  PlatformFile? selectedFile;
  bool uploading = false;
  String? error;

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.single.path == null) return;
    setState(() => selectedFile = result.files.single);
  }

  Future<void> _upload() async {
    if (propertyId == null ||
        selectedFile?.path == null ||
        titleController.text.trim().isEmpty) {
      setState(
          () => error = 'Choisissez une propriété, un titre et un fichier.');
      return;
    }
    setState(() {
      uploading = true;
      error = null;
    });
    try {
      final uri = Uri.parse(
          '${widget.editContext.mediaEndpoint}/api/properties/$propertyId/documents');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${widget.editContext.token}'
        ..fields['title'] = titleController.text.trim();
      request.files
          .add(await http.MultipartFile.fromPath('file', selectedFile!.path!));
      await sendRest(request);
      if (mounted) {
        widget.editContext.onUpdated();
        Navigator.of(context).pop();
      }
    } catch (exception) {
      setState(() => error =
          'Contrat impossible à téléverser : ${describeError(exception)}');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un contrat')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            value: propertyId,
            decoration: const InputDecoration(labelText: 'Propriété louée'),
            items: widget.properties
                .where((property) => property.id != null)
                .map((property) => DropdownMenuItem(
                    value: property.id, child: Text(property.title)))
                .toList(),
            onChanged: (value) => setState(() => propertyId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Titre du document'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: uploading ? null : _selectFile,
            icon: const Icon(Icons.attach_file),
            label: Text(selectedFile?.name ?? 'Choisir le fichier du contrat'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: uploading ? null : _upload,
            icon: uploading
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator())
                : const Icon(Icons.cloud_upload),
            label:
                Text(uploading ? 'Téléversement...' : 'Téléverser le contrat'),
          ),
          if (error != null) ...[
            const SizedBox(height: 12),
            ErrorCard(error!),
          ],
        ],
      ),
    );
  }
}
