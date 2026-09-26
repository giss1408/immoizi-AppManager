import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../models/dashboard.dart';
import '../pages/interest_request_page.dart';
import '../property_edit_context.dart';

class InterestRequestTile extends StatelessWidget {
  const InterestRequestTile(this.request,
      {required this.editContext, super.key});

  final InterestRequestItem request;
  final PropertyEditContext editContext;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: IvoryColors.green.withOpacity(0.12),
          child: Icon(Icons.person_outline, color: IvoryColors.green),
        ),
        title: Text(request.applicantName,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${request.propertyTitle}\n${request.profession} • ${request.occupantsCount} occupant(s)',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing:
            InterestStatusChip(request.status, expired: request.isExpired),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => InterestRequestPage(
                request: request, editContext: editContext))),
      ),
    );
  }
}
