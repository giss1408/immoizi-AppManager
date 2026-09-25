import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../api/queries.dart';
import '../models/dashboard.dart';
import '../property_edit_context.dart';

class MaintenanceEditPage extends StatefulWidget {
  const MaintenanceEditPage(
      {required this.request, required this.editContext, super.key});

  final Maintenance request;
  final PropertyEditContext editContext;

  @override
  State<MaintenanceEditPage> createState() => _MaintenanceEditPageState();
}

class _MaintenanceEditPageState extends State<MaintenanceEditPage> {
  late final titleController =
      TextEditingController(text: widget.request.title);
  late final descriptionController =
      TextEditingController(text: widget.request.description);
  late String priority = widget.request.priority;
  late String status = widget.request.status;
  bool saving = false;
  String? error;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await GraphQLClient().query(
        widget.editContext.endpoint,
        widget.editContext.token,
        updateMaintenanceMutation,
        variables: {
          'id': widget.request.id,
          'title': titleController.text.trim(),
          'description': descriptionController.text.trim(),
          'priority': priority,
          'status': status,
        },
      );
      if (mounted) {
        widget.editContext.onUpdated();
        Navigator.of(context).pop();
      }
    } catch (exception) {
      setState(() =>
          error = 'Modification impossible : ${describeError(exception)}');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier la maintenance')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.request.propertyTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Sujet')),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            maxLines: 5,
            decoration:
                const InputDecoration(labelText: 'Description du problème'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: priority,
            decoration: const InputDecoration(labelText: 'Priorité'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Faible')),
              DropdownMenuItem(value: 'normal', child: Text('Normale')),
              DropdownMenuItem(value: 'high', child: Text('Haute')),
              DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
            ],
            onChanged: (value) => setState(() => priority = value ?? priority),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: status,
            decoration: const InputDecoration(labelText: 'Statut'),
            items: const [
              DropdownMenuItem(value: 'open', child: Text('Ouverte')),
              DropdownMenuItem(value: 'in_progress', child: Text('En cours')),
              DropdownMenuItem(value: 'resolved', child: Text('Résolue')),
              DropdownMenuItem(value: 'cancelled', child: Text('Annulée')),
            ],
            onChanged: (value) => setState(() => status = value ?? status),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator())
                : const Icon(Icons.save),
            label: Text(saving ? 'Enregistrement...' : 'Enregistrer'),
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
