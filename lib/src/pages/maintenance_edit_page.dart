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
      setState(() => error = tr('Modification impossible : {error}',
          {'error': describeError(exception)}));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Modifier la maintenance'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.request.propertyTitle,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: tr('Sujet'))),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            maxLines: 5,
            decoration:
                InputDecoration(labelText: tr('Description du problème')),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: priority,
            decoration: InputDecoration(labelText: tr('Priorité')),
            items: [
              DropdownMenuItem(value: 'low', child: Text(tr('Faible'))),
              DropdownMenuItem(value: 'normal', child: Text(tr('Normale'))),
              DropdownMenuItem(value: 'high', child: Text(tr('Haute'))),
              DropdownMenuItem(value: 'urgent', child: Text(tr('Urgente'))),
            ],
            onChanged: (value) => setState(() => priority = value ?? priority),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: status,
            decoration: InputDecoration(labelText: tr('Statut')),
            items: [
              DropdownMenuItem(value: 'open', child: Text(tr('Ouverte'))),
              DropdownMenuItem(
                  value: 'in_progress', child: Text(tr('En cours'))),
              DropdownMenuItem(value: 'resolved', child: Text(tr('Résolue'))),
              DropdownMenuItem(value: 'cancelled', child: Text(tr('Annulée'))),
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
            label: Text(saving ? tr('Enregistrement...') : tr('Enregistrer')),
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
