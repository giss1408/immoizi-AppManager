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
        subtitle: 'Début ${lease.startDate} • ${lease.rentAmount} FCFA',
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
        subtitle: Text('${request.propertyTitle} • ${request.priority}'),
        trailing: Text(request.status),
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
