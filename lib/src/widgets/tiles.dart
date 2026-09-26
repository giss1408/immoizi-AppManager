import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../models/dashboard.dart';
import '../pages/maintenance_edit_page.dart';
import '../property_edit_context.dart';

class LeaseTile extends StatelessWidget {
  const LeaseTile(this.lease, {super.key});

  final LeaseItem lease;

  @override
  Widget build(BuildContext context) => InfoTile(
        icon: Icons.assignment_turned_in,
        title: lease.propertyTitle,
        subtitle: tr('Début {date} • {amount}',
            {'date': lease.startDate, 'amount': '${lease.rentAmount} FCFA'}),
        trailing: lease.status,
      );
}

class PaymentTile extends StatelessWidget {
  const PaymentTile(this.payment, {super.key});

  final Payment payment;

  @override
  Widget build(BuildContext context) => InfoTile(
        icon: Icons.receipt_long,
        title: '${payment.amount} FCFA',
        subtitle: payment.propertyTitle,
        trailing: payment.status,
      );
}

class MaintenanceTile extends StatelessWidget {
  const MaintenanceTile(this.request, {required this.editContext, super.key});

  final Maintenance request;
  final PropertyEditContext editContext;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: Icon(Icons.construction,
            color: Theme.of(context).colorScheme.primary),
        title: Text(request.title),
        subtitle: Text(
            '${request.propertyTitle} • ${maintenanceLabel(request.priority)}'),
        trailing: Text(maintenanceLabel(request.status)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                MaintenanceEditPage(request: request, editContext: editContext),
          ),
        ),
      ),
    );
  }
}

class DocumentTile extends StatelessWidget {
  const DocumentTile(this.document, {super.key});

  final DocumentItem document;

  @override
  Widget build(BuildContext context) => InfoTile(
        icon: Icons.description,
        title: document.title,
        subtitle: '${document.propertyTitle} • ${document.type}',
      );
}

/// Label for a maintenance priority or status code, in the active language.
String maintenanceLabel(String code) => tr(const {
      'low': 'Faible',
      'normal': 'Normale',
      'high': 'Haute',
      'urgent': 'Urgente',
      'open': 'Ouverte',
      'in_progress': 'En cours',
      'resolved': 'Résolue',
      'cancelled': 'Annulée',
    }[code] ??
    code);
