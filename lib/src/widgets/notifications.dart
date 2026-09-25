import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../api/queries.dart';
import '../models/dashboard.dart';
import '../pages/interest_request_page.dart';
import '../property_edit_context.dart';

/// Marks the notification read and opens the related interest request.
Future<void> openNotification(
  BuildContext context,
  NotificationItem notification, {
  required InterestRequestItem? request,
  required PropertyEditContext editContext,
  required Future<void> Function(String id) markRead,
}) async {
  if (!notification.isRead) markRead(notification.id);
  if (request == null) return;
  await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          InterestRequestPage(request: request, editContext: editContext)));
}

class NotificationTile extends StatelessWidget {
  const NotificationTile(this.notification,
      {required this.editContext,
      required this.markRead,
      this.request,
      super.key});

  final NotificationItem notification;
  final PropertyEditContext editContext;
  final Future<void> Function(String id) markRead;

  /// The interest request this notification is about, if any.
  final InterestRequestItem? request;

  Future<void> _delete(BuildContext context) async {
    try {
      await editContext.client.query(
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
        onTap: () => openNotification(context, notification,
            request: request, editContext: editContext, markRead: markRead),
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
  const UnreadNotificationsBanner(
      {required this.notifications, this.onTap, super.key});

  final List<NotificationItem> notifications;
  final VoidCallback? onTap;

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
        onTap: onTap,
        trailing: notifications.length > 1
            ? Text('+${notifications.length - 1}')
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
