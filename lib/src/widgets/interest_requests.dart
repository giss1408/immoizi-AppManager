import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../models/dashboard.dart';

class InterestRequestTile extends StatelessWidget {
  const InterestRequestTile(this.request,
      {required this.endpoint, required this.token, super.key});

  final InterestRequestItem request;
  final String endpoint;
  final String token;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.forum, color: IvoryColors.green),
        title: Text(request.propertyTitle,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          'Statut : ${request.status}\nProfession : ${request.profession}\nSalaire : ${request.salaryRange}\n'
          'Occupants : ${request.occupantsCount} • Entrée : ${request.leaseStartDate}\n'
          '${request.message.isEmpty ? 'Aucun message initial.' : request.message}',
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InterestChatPage(
              interestRequestId: request.id,
              propertyTitle: request.propertyTitle,
              endpoint: endpoint,
              token: token,
              isManager: true,
            ),
          ),
        ),
      ),
    );
  }
}
