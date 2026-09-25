import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../api/queries.dart';
import '../models/dashboard.dart';
import '../property_edit_context.dart';

class NotificationTile extends StatelessWidget {
  const NotificationTile(this.notification,
      {required this.editContext, super.key});

  final NotificationItem notification;
  final PropertyEditContext editContext;

  Future<void> _delete(BuildContext context) async {
    try {
      await GraphQLClient().query(
        editContext.endpoint,
        editContext.token,
        deleteNotificationMutation,
        variables: {'notificationId': notification.id},
      );
      editContext.onUpdated();
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Suppression impossible : ${describeError(exception)}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          notification.isRead
              ? Icons.notifications_none
              : Icons.notifications_active,
          color: notification.isRead ? Colors.grey : IvoryColors.orange,
        ),
        title: Text(notification.title,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${notification.message}\n${notification.propertyTitle}\n'
          '${notification.interestMessage.isEmpty ? 'Aucun message initial.' : notification.interestMessage}',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!notification.isRead)
              const Icon(Icons.circle, size: 10, color: IvoryColors.orange),
            IconButton(
              onPressed: () => _delete(context),
              icon: const Icon(Icons.delete_outline),
              color: Colors.redAccent,
              tooltip: 'Supprimer la notification',
            ),
          ],
        ),
      ),
    );
  }
}

class UnreadNotificationsBanner extends StatelessWidget {
  const UnreadNotificationsBanner({required this.notifications, super.key});

  final List<NotificationItem> notifications;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF4E5),
      child: ListTile(
        leading:
            const Icon(Icons.notifications_active, color: IvoryColors.orange),
        title: Text(notifications.first.title,
            style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${notifications.first.message}\n${notifications.first.propertyTitle}\n'
          '${notifications.first.interestMessage.isEmpty ? 'Aucun message initial.' : notifications.first.interestMessage}',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: notifications.length > 1
            ? Text('+${notifications.length - 1}')
            : null,
      ),
    );
  }
}
