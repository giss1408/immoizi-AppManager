import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import 'api/queries.dart';
import 'models/dashboard.dart';
import 'pages/lease_contract_upload_page.dart';
import 'property_edit_context.dart';
import 'views/dashboard_view.dart';
import 'widgets/interest_requests.dart';
import 'widgets/notifications.dart';
import 'widgets/tiles.dart';

class ManagerHomePage extends StatefulWidget {
  const ManagerHomePage({this.client, super.key});

  /// Injected in tests; a default client is created otherwise.
  final GraphQLClient? client;

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage>
    with DashboardSession<ManagerHomePage, ManagerDashboard> {
  @override
  late final GraphQLClient client = widget.client ?? GraphQLClient();
  @override
  final cache = const DashboardCache(
      dataKey: 'manager_dashboard_cache_v1',
      timeKey: 'manager_dashboard_cache_time_v1');
  @override
  final sessionStore = SessionStore('manager');
  @override
  final dashboardQuery = managerQuery;
  @override
  final requiresLogin = true;

  int tab = 0;

  @override
  ManagerDashboard parseDashboard(Map<String, dynamic> json) =>
      ManagerDashboard.fromJson(json);

  @override
  ManagerDashboard demoDashboard() => ManagerDashboard.demo();

  @override
  Iterable<AppNotification> notificationsOf(ManagerDashboard dashboard) =>
      dashboard.notifications;

  @override
  Widget build(BuildContext context) {
    final unread =
        dashboard.notifications.where((item) => !item.isRead).toList();
    final onMySpace = tab == 1;
    return DashboardScaffold(
      drawer: AppDrawer(
        name: username.text.trim().isEmpty
            ? tr('Bailleur')
            : username.text.trim(),
        role: tr('Bailleur / Gestionnaire'),
        connected: connected,
        onLogout: logout,
        applicationName: 'Immoizi Manager',
        homeLabel: tr('Tableau de bord'),
        extraComingSoonTiles: [
          DrawerComingSoonTile(
              icon: Icons.bar_chart, title: tr('Rapports & statistiques')),
          DrawerComingSoonTile(
              icon: Icons.groups_outlined, title: tr('Équipe & rôles')),
        ],
      ),
      tab: tab,
      onTabChanged: (index) => setState(() => tab = index),
      listingsDestination: NavigationDestination(
        icon: const Icon(Icons.apartment_outlined),
        selectedIcon: const Icon(Icons.apartment),
        label: tr('Portefeuille'),
      ),
      unreadCount: unread.length,
      header: (collapsed) => sessionHeader(
        title: onMySpace ? tr('Mon espace') : 'Immoizi Manager',
        subtitle: onMySpace
            ? tr('Outils et suivi de votre portefeuille')
            : tr('Portefeuille bailleur'),
        icon: onMySpace ? Icons.person : Icons.business,
        collapsed: collapsed,
        refreshTooltip: tr('Charger le portefeuille'),
        search: onMySpace
            ? null
            : listingSearchBar(dashboard.properties,
                hintText: tr('Rechercher une annonce...'),
                filterSubtitle: tr('Affinez les biens qui vous intéressent.')),
      ),
      onRefresh: load,
      lastSynced: lastSynced,
      loading: loading,
      error: error,
      children: onMySpace
          ? _mySpace()
          : [
              if (unread.isNotEmpty) ...[
                UnreadNotificationsBanner(
                  notifications: unread,
                  showInterestMessage: true,
                  onTap: () => _openNotification(unread.first),
                ),
                const SizedBox(height: 16),
              ],
              ManagerDashboardView(
                dashboard,
                searchQuery: searchQuery,
                filters: filters,
                onRentalTypeChanged: setRentalType,
                editContext: _editContext,
              ),
            ],
    );
  }

  void _openNotification(NotificationItem notification) =>
      openNotification(context, notification,
          request: _requestFor(notification),
          editContext: _editContext,
          markRead: markNotificationRead);

  InterestRequestItem? _requestFor(NotificationItem notification) {
    for (final request in dashboard.interestRequests) {
      if (request.id == notification.interestRequestId) return request;
    }
    return null;
  }

  PropertyEditContext get _editContext => PropertyEditContext(
        endpoint: endpoint.text.trim(),
        token: token.text.trim(),
        onUpdated: load,
        categories: dashboard.categories,
        client: client,
      );

  List<Widget> _mySpace() {
    return [
      ConnectionCard(
          endpoint: endpoint,
          token: token,
          username: username,
          password: password,
          loading: loading,
          loggingIn: loggingIn,
          connected: connected,
          onPressed: load,
          onLogin: login,
          onLogout: logout,
          loadLabel: tr('Charger le portefeuille')),
      MetricGrid(dashboard: dashboard),
      // Requests and notifications first: they are what needs an answer.
      CategorySection(
          title: tr("Demandes d'intérêt"),
          icon: Icons.forum_outlined,
          count: dashboard.interestRequests.length,
          initiallyExpanded: dashboard.interestRequests.any((item) =>
              isOpenInterestStatus(item.status, expired: item.isExpired)),
          children: dashboard.interestRequests
              .map((item) =>
                  InterestRequestTile(item, editContext: _editContext))
              .toList()),
      CategorySection(
          title: 'Notifications',
          icon: Icons.notifications_none,
          count: dashboard.notifications.length,
          initiallyExpanded:
              dashboard.notifications.any((item) => !item.isRead),
          children: dashboard.notifications
              .map((item) => NotificationTile(item,
                  showInterestMessage: true,
                  onTap: () => _openNotification(item),
                  onDelete: () => deleteNotification(context, item,
                      editContext: _editContext)))
              .toList()),
      CategorySection(
          title: tr('Baux'),
          icon: Icons.assignment,
          count: dashboard.leases.length,
          children: dashboard.leases.map(LeaseTile.new).toList()),
      CategorySection(
          title: 'Documents',
          icon: Icons.description,
          count: dashboard.documents.length,
          children: [
            ...dashboard.documents.map(DocumentTile.new),
            ContractUploadCard(
                properties: dashboard.properties, editContext: _editContext)
          ]),
      CategorySection(
          title: tr('Paiements'),
          icon: Icons.payments,
          count: dashboard.payments.length,
          children: dashboard.payments.map(PaymentTile.new).toList()),
      CategorySection(
          title: 'Maintenance',
          icon: Icons.build,
          count: dashboard.maintenance.length,
          children: dashboard.maintenance
              .map((item) => MaintenanceTile(item, editContext: _editContext))
              .toList()),
      const SizedBox(height: 4),
      const PreferencesCard(),
    ];
  }
}
