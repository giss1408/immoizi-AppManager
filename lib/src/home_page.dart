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

  PropertyFilters filters = const PropertyFilters();
  int tab = 0;

  @override
  ManagerDashboard parseDashboard(Map<String, dynamic> json) =>
      ManagerDashboard.fromJson(json);

  @override
  ManagerDashboard demoDashboard() => ManagerDashboard.demo();

  @override
  Iterable<AppNotification> notificationsOf(ManagerDashboard dashboard) =>
      dashboard.notifications.map((item) => AppNotification(
          id: item.id,
          title: item.title,
          message: item.message,
          isRead: item.isRead,
          interestRequestId: item.interestRequestId));

  @override
  Widget build(BuildContext context) {
    final unread = dashboard.notifications.where((item) => !item.isRead).length;
    final onMySpace = tab == 1;
    return Scaffold(
      drawer: AppDrawer(
        name: username.text.trim().isEmpty ? 'Bailleur' : username.text.trim(),
        role: 'Bailleur / Gestionnaire',
        connected: connected,
        onLogout: logout,
        applicationName: 'Immoizi Manager',
        homeLabel: 'Tableau de bord',
        extraComingSoonTiles: const [
          DrawerComingSoonTile(
              icon: Icons.bar_chart, title: 'Rapports & statistiques'),
          DrawerComingSoonTile(
              icon: Icons.groups_outlined, title: 'Équipe & rôles'),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.apartment_outlined),
            selectedIcon: Icon(Icons.apartment),
            label: 'Portefeuille',
          ),
          NavigationDestination(
            icon: Badge.count(
                count: unread,
                isLabelVisible: unread > 0,
                child: const Icon(Icons.person_outline)),
            selectedIcon: Badge.count(
                count: unread,
                isLabelVisible: unread > 0,
                child: const Icon(Icons.person)),
            label: 'Mon espace',
          ),
        ],
      ),
      body: Column(
        children: [
          AppHeader(
            title: onMySpace ? 'Mon espace' : 'Immoizi Manager',
            subtitle: onMySpace
                ? 'Outils et suivi de votre portefeuille'
                : 'Portefeuille bailleur',
            icon: onMySpace ? Icons.person : Icons.business,
            connected: connected,
            online: online,
            connectedLabel: username.text.trim(),
            loading: loading,
            onRefresh: load,
            refreshTooltip: 'Charger le portefeuille',
            bottom: onMySpace
                ? null
                : PropertySearchBar(
                    controller: propertySearch,
                    onChanged: searchProperties,
                    activeFilterCount: filters.activeCount,
                    onOpenFilters: _showFilters,
                    hintText: 'Rechercher une annonce...',
                  ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: load,
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        CacheStatusBar(
                            lastSynced: lastSynced, loading: loading),
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          ErrorCard(error!),
                        ],
                        if (!onMySpace && unread > 0) ...[
                          const SizedBox(height: 12),
                          UnreadNotificationsBanner(
                            notifications: dashboard.notifications
                                .where((item) => !item.isRead)
                                .toList(),
                            onTap: () {
                              final first = dashboard.notifications
                                  .firstWhere((item) => !item.isRead);
                              openNotification(context, first,
                                  request: _requestFor(first),
                                  editContext: _editContext,
                                  markRead: markNotificationRead);
                            },
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (onMySpace)
                          ..._mySpace()
                        else
                          ManagerDashboardView(
                            dashboard,
                            searchQuery: searchQuery,
                            filters: filters,
                            editContext: _editContext,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

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
          loadLabel: 'Charger le portefeuille'),
      MetricGrid(dashboard: dashboard),
      // Requests and notifications first: they are what needs an answer.
      CategorySection(
          title: "Demandes d'intérêt",
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
                  editContext: _editContext,
                  markRead: markNotificationRead,
                  request: _requestFor(item)))
              .toList()),
      CategorySection(
          title: 'Baux',
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
          title: 'Paiements',
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
    ];
  }

  Future<void> _showFilters() async {
    final result = await showModalBottomSheet<PropertyFilters>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => PropertyFilterSheet(
        initial: filters,
        categories: dashboard.properties
            .map((property) => property.category)
            .toSet()
            .toList()
          ..sort(),
        subtitle: 'Affinez les biens qui vous intéressent.',
      ),
    );
    if (result != null && mounted) setState(() => filters = result);
  }
}
