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

/// Deletes the notification, then refreshes the dashboard.
Future<void> deleteNotification(
    BuildContext context, NotificationItem notification,
    {required PropertyEditContext editContext}) async {
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
          content: Text(tr('Suppression impossible : {error}',
              {'error': describeError(exception)}))));
    }
  }
}
