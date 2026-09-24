import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

class IvoryColors {
  static const Color orange = Color(0xFFFF8200);
  static const Color green = Color(0xFF009A44);
  static const Color background = Color(0xFFF0FAF3);
}

const _cacheKey = 'manager_dashboard_cache_v1';
const _cacheTimeKey = 'manager_dashboard_cache_time_v1';

void main() => runApp(const ImmoiziManagerApp());

class ImmoiziManagerApp extends StatelessWidget {
  const ImmoiziManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Immoizi Manager',
      theme: AppTheme.theme(IvoryColors.orange, IvoryColors.background),
      home: const ManagerHomePage(),
    );
  }
}

class ManagerHomePage extends StatefulWidget {
  const ManagerHomePage({super.key});

  @override
  State<ManagerHomePage> createState() => _ManagerHomePageState();
}

class _ManagerHomePageState extends State<ManagerHomePage> {
  final endpoint = TextEditingController(text: 'http://127.0.0.1:8000/graphql');
  final token = TextEditingController();
  final username = TextEditingController(text: 'landlord_demo');
  final password = TextEditingController(text: 'DemoPass123!');
  final client = GraphQLClient();
  ManagerDashboard dashboard = ManagerDashboard.demo();
  bool loading = false;
  bool loggingIn = false;
  bool connected = false;
  bool hasData = false;
  DateTime? lastSynced;
  String? error;
  Timer? notificationTimer;

  @override
  void initState() {
    super.initState();
    _restoreCache();
    notificationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (connected && !loading) load();
    });
  }

  @override
  void dispose() {
    endpoint.dispose();
    token.dispose();
    username.dispose();
    password.dispose();
    notificationTimer?.cancel();
    super.dispose();
  }

  Future<void> _restoreCache() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);
    final cachedAtMs = prefs.getInt(_cacheTimeKey);
    if (cached == null || !mounted) return;

    try {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      setState(() {
        dashboard = ManagerDashboard.fromJson(data);
        hasData = true;
        lastSynced = cachedAtMs != null ? DateTime.fromMillisecondsSinceEpoch(cachedAtMs) : null;
      });
    } catch (_) {
      // Corrupt or outdated cache format — ignore and keep the demo fallback.
    }
  }

  Future<void> _saveCache(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode(data));
    final now = DateTime.now();
    await prefs.setInt(_cacheTimeKey, now.millisecondsSinceEpoch);
    if (mounted) setState(() => lastSynced = now);
  }

  Future<void> login() async {
    setState(() {
      loggingIn = true;
      error = null;
    });

    try {
      final endpointValue = endpoint.text.trim();
      final newToken = await client.login(endpointValue, username.text.trim(), password.text.trim());
      token.text = newToken;
      await load();
    } catch (_) {
      setState(() => error = 'Connexion échouée — vérifiez vos identifiants ou le backend.');
    } finally {
      if (mounted) {
        setState(() => loggingIn = false);
      }
    }
  }

  void logout() {
    token.clear();
    setState(() => connected = false);
    load();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });

    try {
      final endpointValue = endpoint.text.trim();
      if (endpointValue.isEmpty) {
        throw Exception('Endpoint vide');
      }

      final data = await client.query(endpointValue, token.text.trim(), managerQuery);
      setState(() {
        dashboard = ManagerDashboard.fromJson(data);
        connected = token.text.trim().isNotEmpty;
        hasData = true;
      });
      await _saveCache(data);
    } catch (_) {
      setState(() {
        connected = false;
        if (!hasData) {
          dashboard = ManagerDashboard.demo();
          error = 'Backend indisponible — portefeuille démonstratif chargé';
        } else {
          error = 'Synchronisation impossible — dernier portefeuille en cache affiché';
        }
      });
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        name: username.text.trim().isEmpty ? 'Bailleur' : username.text.trim(),
        role: 'Bailleur / Gestionnaire',
        connected: connected,
        onLogout: logout,
      ),
      bottomNavigationBar: AppBottomBar(
        connected: connected,
        loading: loading,
        onRefresh: load,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              AppHeader(
                title: 'Immoizi Manager',
                subtitle: 'Portefeuille bailleur',
                icon: Icons.business,
                connected: connected,
                connectedLabel: username.text.trim(),
              ),
              const SizedBox(height: 12),
              CacheStatusBar(lastSynced: lastSynced, loading: loading),
              const SizedBox(height: 12),
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
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                ErrorCard(error!),
              ],
              if (dashboard.notifications.any((item) => !item.isRead)) ...[
                const SizedBox(height: 12),
                UnreadNotificationsBanner(
                  notifications: dashboard.notifications.where((item) => !item.isRead).toList(),
                ),
              ],
              const SizedBox(height: 18),
              ManagerDashboardView(
                dashboard,
                editContext: PropertyEditContext(
                  endpoint: endpoint.text.trim(),
                  token: token.text.trim(),
                  onUpdated: load,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PropertyEditContext {
  const PropertyEditContext({required this.endpoint, required this.token, required this.onUpdated});

  final String endpoint;
  final String token;
  final VoidCallback onUpdated;

  bool get canEdit => token.isNotEmpty;

  String get mediaEndpoint {
    final uri = Uri.parse(endpoint);
    return '${uri.scheme}://${uri.authority}';
  }
}

class ManagerDashboardView extends StatelessWidget {
  const ManagerDashboardView(this.dashboard, {required this.editContext, super.key});

  final ManagerDashboard dashboard;
  final PropertyEditContext editContext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MetricGrid(dashboard: dashboard),
        const SizedBox(height: 16),
        CategorySection(
          title: 'Mes biens',
          icon: Icons.apartment,
          count: dashboard.properties.length,
          initiallyExpanded: true,
          children: groupPropertiesByCategory(dashboard.properties)
              .entries
              .map((entry) => PropertyCategoryGroup(category: entry.key, properties: entry.value, editContext: editContext))
              .toList(),
        ),
        CategorySection(
          title: 'Baux',
          icon: Icons.assignment,
          count: dashboard.leases.length,
          children: dashboard.leases.map(LeaseTile.new).toList(),
        ),
        CategorySection(
          title: 'Documents',
          icon: Icons.description,
          count: dashboard.documents.length,
          initiallyExpanded: true,
          children: [
            ...dashboard.documents.map(DocumentTile.new),
            ContractUploadCard(properties: dashboard.properties, editContext: editContext),
          ],
        ),
        CategorySection(
          title: 'Paiements',
          icon: Icons.payments,
          count: dashboard.payments.length,
          children: dashboard.payments.map(PaymentTile.new).toList(),
        ),
        CategorySection(
          title: 'Maintenance',
          icon: Icons.build,
          count: dashboard.maintenance.length,
          children: dashboard.maintenance
              .map((item) => MaintenanceTile(item, editContext: editContext))
              .toList(),
        ),
        CategorySection(
          title: 'Notifications',
          icon: Icons.notifications_none,
          count: dashboard.notifications.where((item) => !item.isRead).length,
          initiallyExpanded: dashboard.notifications.isNotEmpty,
            children: dashboard.notifications
              .map((item) => NotificationTile(item, editContext: editContext))
              .toList(),
        ),
        CategorySection(
          title: "Demandes d'intérêt",
          icon: Icons.forum_outlined,
          count: dashboard.interestRequests.length,
          initiallyExpanded: dashboard.interestRequests.isNotEmpty,
          children: dashboard.interestRequests
              .map((item) => InterestRequestTile(item, endpoint: editContext.endpoint, token: editContext.token))
              .toList(),
        ),
      ],
    );
  }
}

Map<String, List<Property>> groupPropertiesByCategory(List<Property> properties) {
  final grouped = <String, List<Property>>{};
  for (final property in properties) {
    grouped.putIfAbsent(property.category, () => []).add(property);
  }
  return grouped;
}

class AppTheme {
  static ThemeData theme(Color seed, Color background) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: seed),
      scaffoldBackgroundColor: background,
      cardTheme: const CardTheme(elevation: 0, color: Colors.white, margin: EdgeInsets.zero),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: IvoryColors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: IvoryColors.orange,
          side: const BorderSide(color: IvoryColors.orange),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      useMaterial3: true,
    );
  }
}

class AppHeader extends StatelessWidget {
  const AppHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.connected = false,
    this.connectedLabel = '',
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool connected;
  final String connectedLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [IvoryColors.green, Color(0xFF00733A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.all(Radius.circular(18)),
                ),
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ConnectionStatusPill(connected: connected, label: connectedLabel),
        ],
      ),
    );
  }
}

class ConnectionStatusPill extends StatelessWidget {
  const ConnectionStatusPill({required this.connected, required this.label, super.key});

  final bool connected;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: connected ? IvoryColors.green : Colors.black38,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            connected ? 'Connecté — $label' : 'Mode démonstration',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: connected ? IvoryColors.green : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }
}

class AppBottomBar extends StatelessWidget {
  const AppBottomBar({
    required this.connected,
    required this.loading,
    required this.onRefresh,
    super.key,
  });

  final bool connected;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Scaffold.of(context).openDrawer(),
            icon: const Icon(Icons.menu, color: IvoryColors.green),
            tooltip: 'Menu',
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? IvoryColors.green : Colors.black38,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                connected ? 'Connect\u00e9' : 'Mode d\u00e9mo',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54),
              ),
            ],
          ),
          IconButton(
            onPressed: loading ? null : onRefresh,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, color: IvoryColors.orange),
            tooltip: 'Charger le portefeuille',
          ),
        ],
      ),
    );
  }
}

class AppDrawer extends StatelessWidget {
  const AppDrawer({
    required this.name,
    required this.role,
    required this.connected,
    required this.onLogout,
    super.key,
  });

  final String name;
  final String role;
  final bool connected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [IvoryColors.green, Color(0xFF00733A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  Text(role, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  const SizedBox(height: 8),
                  ConnectionStatusPill(connected: connected, label: name),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home, color: IvoryColors.green),
                    title: const Text('Tableau de bord'),
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const DrawerComingSoonTile(icon: Icons.bar_chart, title: 'Rapports & statistiques'),
                  const DrawerComingSoonTile(icon: Icons.groups_outlined, title: 'Équipe & rôles'),
                  const DrawerComingSoonTile(icon: Icons.notifications_none, title: 'Notifications'),
                  const DrawerComingSoonTile(icon: Icons.translate, title: 'Langue (FR / EN)'),
                  const DrawerComingSoonTile(icon: Icons.support_agent, title: 'Aide & support'),
                  const DrawerComingSoonTile(icon: Icons.privacy_tip_outlined, title: 'Confidentialité & conditions'),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: IvoryColors.green),
                    title: const Text('À propos'),
                    onTap: () {
                      Navigator.of(context).pop();
                      showAboutDialog(
                        context: context,
                        applicationName: 'Immoizi Manager',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '© Immoizi — Côte d’Ivoire',
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('Déconnexion'),
                    onTap: () {
                      Navigator.of(context).pop();
                      onLogout();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DrawerComingSoonTile extends StatelessWidget {
  const DrawerComingSoonTile({required this.icon, required this.title, super.key});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      enabled: false,
      leading: Icon(icon, color: Colors.black26),
      title: Text(title, style: const TextStyle(color: Colors.black45)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: IvoryColors.orange.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('Bientôt', style: TextStyle(fontSize: 11, color: IvoryColors.orange, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class ConnectionCard extends StatefulWidget {
  const ConnectionCard({
    required this.endpoint,
    required this.token,
    required this.username,
    required this.password,
    required this.loading,
    required this.loggingIn,
    required this.connected,
    required this.onPressed,
    required this.onLogin,
    required this.onLogout,
    super.key,
  });

  final TextEditingController endpoint;
  final TextEditingController token;
  final TextEditingController username;
  final TextEditingController password;
  final bool loading;
  final bool loggingIn;
  final bool connected;
  final VoidCallback onPressed;
  final VoidCallback onLogin;
  final VoidCallback onLogout;

  @override
  State<ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<ConnectionCard> {
  late bool expanded = !widget.connected;

  @override
  void didUpdateWidget(covariant ConnectionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.connected != oldWidget.connected) {
      expanded = !widget.connected;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => expanded = !expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    widget.connected ? Icons.check_circle : Icons.wifi_tethering,
                    color: widget.connected ? IvoryColors.green : IvoryColors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.connected ? 'Connect\u00e9 en tant que ${widget.username.text.trim()}' : 'Connexion au backend',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: widget.connected ? IvoryColors.green : Colors.black87,
                      ),
                    ),
                  ),
                  if (widget.connected)
                    TextButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout, size: 16),
                      label: const Text('D\u00e9connexion'),
                    ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more, color: Colors.black45),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                  TextField(
                    controller: widget.endpoint,
                    decoration: const InputDecoration(
                      labelText: 'Endpoint GraphQL',
                      prefixIcon: Icon(Icons.link),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.username,
                          decoration: const InputDecoration(
                            labelText: 'Identifiant',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: widget.password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: widget.loggingIn ? null : widget.onLogin,
                    icon: widget.loggingIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(widget.loggingIn ? 'Connexion...' : (widget.connected ? 'Se reconnecter' : 'Se connecter')),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: widget.token,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Token API',
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: widget.loading ? null : widget.onPressed,
                    icon: widget.loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: Text(widget.loading ? 'Chargement...' : 'Charger le portefeuille'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class MetricGrid extends StatelessWidget {
  const MetricGrid({required this.dashboard, super.key});

  final ManagerDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: MediaQuery.sizeOf(context).width > 720 ? 4 : 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        MetricCard('Biens', dashboard.properties.length, Icons.apartment),
        MetricCard('Baux', dashboard.leases.length, Icons.assignment),
        MetricCard('Paiements', dashboard.payments.length, Icons.payments),
        MetricCard('Maintenance', dashboard.maintenance.length, Icons.build),
      ],
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard(this.label, this.value, this.icon, {super.key});

  final String label;
  final int value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                Text(label, style: const TextStyle(fontSize: 11, color: Colors.black54), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CategorySection extends StatelessWidget {
  const CategorySection({
    required this.title,
    required this.icon,
    required this.count,
    required this.children,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final IconData icon;
  final int count;
  final List<Widget> children;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(label: Text('$count'), visualDensity: VisualDensity.compact),
                const Icon(Icons.expand_more),
              ],
            ),
            childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            children: [
              if (children.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: MutedText('Aucune donnée disponible.'),
                )
              else
                ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class PropertyCategoryGroup extends StatelessWidget {
  const PropertyCategoryGroup({
    required this.category,
    required this.properties,
    required this.editContext,
    super.key,
  });

  final String category;
  final List<Property> properties;
  final PropertyEditContext editContext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          initiallyExpanded: true,
          title: Row(
            children: [
              Icon(Icons.label, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 6),
              Text(category, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(width: 8),
              Chip(label: Text('${properties.length}'), visualDensity: VisualDensity.compact),
            ],
          ),
          children: properties.map((property) => PropertyCard(property, editContext: editContext)).toList(),
        ),
      ),
    );
  }
}

class PropertyCard extends StatelessWidget {
  const PropertyCard(this.property, {required this.editContext, super.key});

  final Property property;
  final PropertyEditContext editContext;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => PropertyDetailPage(property: property, editContext: editContext)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF0E0), Color(0xFFFFD9B3)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.home_work, color: IvoryColors.orange),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(property.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${property.city} \u2022 ${property.district}', style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text('${property.rooms} pi\u00e8ces \u2022 ${property.surface} m\u00b2', style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    if (property.isTestData) ...[
                      const SizedBox(height: 6),
                      const TestDataBadge(),
                    ],
                  ],
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${property.price} FCFA', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(property.status, style: const TextStyle(fontSize: 11, color: Colors.black54)),
                  const SizedBox(height: 6),
                  const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black45),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PropertyDetailPage extends StatefulWidget {
  const PropertyDetailPage({required this.property, required this.editContext, super.key});

  final Property property;
  final PropertyEditContext editContext;

  @override
  State<PropertyDetailPage> createState() => _PropertyDetailPageState();
}

class _PropertyDetailPageState extends State<PropertyDetailPage> {
  late Property current = widget.property;

  Future<void> _openEditSheet() async {
    final updated = await showModalBottomSheet<Property>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => EditListingSheet(property: current, editContext: widget.editContext),
    );
    if (updated != null && mounted) {
      setState(() => current = updated);
      widget.editContext.onUpdated();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.editContext.canEdit && current.id != null;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: IvoryColors.green,
        foregroundColor: Colors.white,
        title: Text(current.title),
        actions: [
          if (canEdit)
            IconButton(
              onPressed: _openEditSheet,
              icon: const Icon(Icons.edit),
              tooltip: 'Modifier l\u2019annonce',
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      current.title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                  Chip(label: Text(current.status), backgroundColor: IvoryColors.orange.withOpacity(0.15)),
                ],
              ),
              const SizedBox(height: 16),
              PropertyDetails(property: current),
              if (!canEdit) ...[
                const SizedBox(height: 16),
                MutedText(
                  current.id == null
                      ? 'Mode démonstration : connectez-vous comme bailleur et synchronisez une annonce réelle pour téléverser des photos ou une vidéo.'
                      : 'Connectez-vous en tant que bailleur pour modifier cette annonce.',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EditListingSheet extends StatefulWidget {
  const EditListingSheet({required this.property, required this.editContext, super.key});

  final Property property;
  final PropertyEditContext editContext;

  @override
  State<EditListingSheet> createState() => _EditListingSheetState();
}

class _EditListingSheetState extends State<EditListingSheet> {
  late final priceController = TextEditingController(text: widget.property.price.toString());
  late final descriptionController = TextEditingController(text: widget.property.description);
  late Property current = widget.property;
  bool savingText = false;
  bool uploadingImage = false;
  bool uploadingVideo = false;
  bool deletingMedia = false;
  String? error;

  @override
  void dispose() {
    priceController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> _saveText() async {
    setState(() {
      savingText = true;
      error = null;
    });
    try {
      final price = int.tryParse(priceController.text.trim());
      final data = await GraphQLClient().query(
        widget.editContext.endpoint,
        widget.editContext.token,
        updatePropertyListingMutation,
        variables: {
          'propertyId': current.id,
          'price': price,
          'description': descriptionController.text.trim(),
        },
      );
      final updated = data['updatePropertyListing']['property'] as Map<String, dynamic>;
      setState(() {
        current = current.copyWith(
          price: updated['price'] as int?,
          description: updated['description'] as String?,
        );
      });
    } catch (_) {
      setState(() => error = 'Impossible d\u2019enregistrer \u2014 v\u00e9rifiez votre connexion.');
    } finally {
      if (mounted) setState(() => savingText = false);
    }
  }

  Future<void> _pickAndUpload({required bool isVideo}) async {
    if (current.id == null || widget.editContext.token.isEmpty) {
      setState(() => error = 'Mode démo : connectez-vous comme bailleur et synchronisez une annonce réelle avant de téléverser des médias.');
      return;
    }

    String? slot;
    if (!isVideo) {
      slot = _nextImageSlot();
      if (slot == null) {
        setState(() => error = 'Maximum de 5 photos atteint pour cette annonce.');
        return;
      }
    }

    setState(() {
      if (isVideo) {
        uploadingVideo = true;
      } else {
        uploadingImage = true;
      }
      error = null;
    });

    try {
      final picker = ImagePicker();
      final file = isVideo
          ? await picker.pickVideo(source: ImageSource.gallery)
          : await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (file == null) return;

      final uri = Uri.parse('${widget.editContext.mediaEndpoint}/api/properties/${current.id}/media');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${widget.editContext.token}'
        ..fields['slot'] = slot ?? 'main_image';
      request.files.add(
        await http.MultipartFile.fromPath(
          isVideo ? 'video' : 'image',
          file.path,
          contentType: isVideo ? MediaType('video', 'mp4') : null,
        ),
      );
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final payload = _backendError(response.body);
        throw Exception('$payload (HTTP ${response.statusCode})');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        current = current.copyWith(
          mainImageUrl: data['mainImageUrl'] as String?,
          galleryImageUrls: (data['galleryImageUrls'] as List<dynamic>? ?? const []).cast<String>(),
          galleryImageSlots: (data['galleryImageSlots'] as List<dynamic>? ?? const []).cast<String>(),
          hasVideo: data['videoUrl'] != null,
          videoUrl: data['videoUrl'] as String?,
        );
      });
    } catch (exception) {
      setState(() => error = 'Téléchargement impossible : ${exception.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() {
          uploadingImage = false;
          uploadingVideo = false;
        });
      }
    }
  }

  Future<void> _deleteMedia({required String slot}) async {
    if (current.id == null || widget.editContext.token.isEmpty) {
      setState(() => error = 'Mode démo : connectez-vous comme bailleur pour supprimer ce média.');
      return;
    }

    setState(() {
      deletingMedia = true;
      error = null;
    });

    try {
      final uri = Uri.parse('${widget.editContext.mediaEndpoint}/api/properties/${current.id}/media').replace(
        queryParameters: {'slot': slot},
      );
      final request = http.Request('DELETE', uri)
        ..headers['Authorization'] = 'Bearer ${widget.editContext.token}';
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final payload = _backendError(response.body);
        throw Exception('$payload (HTTP ${response.statusCode})');
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      setState(() {
        current = current.copyWith(
          mainImageUrl: data['mainImageUrl'] as String?,
          galleryImageUrls: (data['galleryImageUrls'] as List<dynamic>? ?? const []).cast<String>(),
          galleryImageSlots: (data['galleryImageSlots'] as List<dynamic>? ?? const []).cast<String>(),
          hasVideo: data['videoUrl'] != null,
          videoUrl: data['videoUrl'] as String?,
          clearMainImage: slot == 'main_image',
          clearVideo: slot == 'video',
        );
      });
    } catch (exception) {
      setState(() => error = 'Suppression impossible : ${exception.toString().replaceFirst('Exception: ', '')}');
    } finally {
      if (mounted) setState(() => deletingMedia = false);
    }
  }

  String _backendError(String body) {
    try {
      final payload = jsonDecode(body) as Map<String, dynamic>;
      return payload['error'] as String? ?? 'Réponse backend invalide';
    } catch (_) {
      return 'Réponse backend invalide';
    }
  }

  /// Next free image slot (main first, then the first unused gallery slot).
  String? _nextImageSlot() {
    if (current.mainImageUrl == null) return 'main_image';
    final occupiedSlots = current.galleryImageSlots.isNotEmpty
        ? current.galleryImageSlots.toSet()
        : {for (var index = 1; index <= current.galleryImageUrls.length; index++) 'image_$index'};
    for (var index = 1; index <= 4; index++) {
      final slot = 'image_$index';
      if (!occupiedSlots.contains(slot)) return slot;
    }
    return null;
  }

  int get _imageCount => (current.mainImageUrl == null ? 0 : 1) + current.galleryImageUrls.length;

  Widget _mediaThumbnail(String url, String slot) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(
              url,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 64,
                height: 64,
                color: const Color(0xFFFFE8E8),
                child: const Icon(Icons.broken_image_outlined, color: Colors.redAccent, size: 24),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: deletingMedia ? null : () => _deleteMedia(slot: slot),
              icon: const Icon(Icons.close, color: Colors.white, size: 16),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                padding: const EdgeInsets.all(2),
                minimumSize: const Size(22, 22),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              tooltip: 'Supprimer la photo',
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Modifier l\u2019annonce', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Prix (FCFA)', prefixIcon: Icon(Icons.payments)),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.description)),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: savingText ? null : _saveText,
              icon: savingText
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: Text(savingText ? 'Enregistrement...' : 'Enregistrer prix & description'),
            ),
            const SizedBox(height: 20),
            if (_imageCount > 0) ...[
              SizedBox(
                height: 64,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    if (current.mainImageUrl != null)
                      _mediaThumbnail(
                        current.mainImageUrl!,
                        'main_image',
                      ),
                    for (var index = 0; index < current.galleryImageUrls.length; index++)
                      _mediaThumbnail(
                        current.galleryImageUrls[index],
                        index < current.galleryImageSlots.length ? current.galleryImageSlots[index] : 'image_${index + 1}',
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (current.videoUrl != null) ...[
              Row(
                children: [
                  const Icon(Icons.videocam, color: IvoryColors.green),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Vidéo de présentation', style: TextStyle(fontWeight: FontWeight.w700))),
                  IconButton(
                    onPressed: deletingMedia ? null : () => _deleteMedia(slot: 'video'),
                    icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                    tooltip: 'Supprimer la vidéo',
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (uploadingImage || deletingMedia || _imageCount >= 5) ? null : () => _pickAndUpload(isVideo: false),
                    icon: uploadingImage
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.photo_camera),
                    label: Text('Photo ($_imageCount/5)'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: (uploadingVideo || deletingMedia) ? null : () => _pickAndUpload(isVideo: true),
                    icon: uploadingVideo
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.videocam),
                    label: const Text('Vid\u00e9o'),
                  ),
                ),
              ],
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              ErrorCard(error!),
            ],
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).pop(current),
              child: const Text('Fermer'),
            ),
          ],
        ),
      ),
    );
  }
}

class PropertyDetails extends StatelessWidget {
  const PropertyDetails({required this.property, super.key});

  final Property property;

  List<String> get _allImages => [
        if (property.mainImageUrl != null) property.mainImageUrl!,
        ...property.galleryImageUrls,
      ];

  void _openViewer(BuildContext context, int index) {
    final images = _allImages;
    if (images.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ImageViewerPage(images: images, initialIndex: index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (property.mainImageUrl != null)
          GestureDetector(
            onTap: () => _openViewer(context, 0),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                property.mainImageUrl!,
                height: 260,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const MediaPlaceholder(icon: Icons.image_not_supported),
              ),
            ),
          )
        else
          const MediaPlaceholder(icon: Icons.photo_camera_back),
        if (property.galleryImageUrls.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: property.galleryImageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => _openViewer(context, (property.mainImageUrl != null ? 1 : 0) + index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    property.galleryImageUrls[index],
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const SizedBox(width: 56, height: 56, child: Icon(Icons.broken_image, size: 20)),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            DetailChip(icon: Icons.category, label: property.category),
            DetailChip(icon: Icons.place, label: '${property.city}, ${property.district}'),
            DetailChip(icon: Icons.payments, label: '${property.price} FCFA'),
            DetailChip(icon: Icons.meeting_room, label: '${property.rooms} pi\u00e8ces'),
            DetailChip(icon: Icons.square_foot, label: '${property.surface} m\u00b2'),
            DetailChip(icon: Icons.verified, label: property.status),
            if (property.hasVideo) const DetailChip(icon: Icons.videocam, label: 'Vid\u00e9o disponible'),
          ],
        ),
        if (property.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Description', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(property.description, style: const TextStyle(color: Colors.black87)),
        ],
        if (property.videoUrl != null) ...[
          const SizedBox(height: 12),
          VideoCard(videoUrl: property.videoUrl!, title: property.title),
        ],
      ],
    );
  }
}

class VideoCard extends StatelessWidget {
  const VideoCard({required this.videoUrl, required this.title, super.key});

  final String videoUrl;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => VideoPlayerPage(videoUrl: videoUrl, title: title)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: IvoryColors.green.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.play_circle_fill, color: IvoryColors.green, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Vidéo de présentation', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black45),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  const VideoPlayerPage({required this.videoUrl, required this.title, super.key});

  final String videoUrl;
  final String title;

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

String _videoUrlForPlayback(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return '';

  final lower = trimmed.toLowerCase();
  if (lower.contains('w3schools.com') || lower.contains('example.com') || lower.contains('commondatastorage.googleapis.com')) {
    return 'https://media.w3.org/2010/05/sintel/trailer.mp4';
  }

  return trimmed;
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late final VideoPlayerController controller;
  bool initialized = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final resolvedUrl = _videoUrlForPlayback(widget.videoUrl);
    final uri = Uri.tryParse(resolvedUrl);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      setState(() => error = 'URL vidéo invalide.');
      return;
    }

    controller = VideoPlayerController.networkUrl(uri);
    controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => initialized = true);
      controller.play();
    }).catchError((_) {
      if (!mounted) return;
      final reason = controller.value.errorDescription;
      setState(() {
        error = reason == null || reason.trim().isEmpty
            ? 'Impossible de lire la vidéo. Vérifiez votre connexion et le format du fichier.'
            : 'Impossible de lire la vidéo. Cause détectée : $reason';
      });
    });
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Center(
        child: error != null
            ? Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 42),
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            : initialized
                ? AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  )
                : const CircularProgressIndicator(color: Colors.white),
      ),
      floatingActionButton: initialized
          ? FloatingActionButton(
              backgroundColor: IvoryColors.green,
              onPressed: () => setState(() {
                controller.value.isPlaying ? controller.pause() : controller.play();
              }),
              child: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow),
            )
          : null,
    );
  }
}

class DetailChip extends StatelessWidget {
  const DetailChip({required this.icon, required this.label, super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class MediaPlaceholder extends StatelessWidget {
  const MediaPlaceholder({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDE4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, size: 32, color: Colors.black26),
    );
  }
}

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({required this.images, required this.initialIndex, super.key});

  final List<String> images;
  final int initialIndex;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  late final PageController controller = PageController(initialPage: widget.initialIndex);
  late int currentIndex = widget.initialIndex;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${currentIndex + 1} / ${widget.images.length}'),
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemBuilder: (context, index) => InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.network(
              widget.images[index],
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white54, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}

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
        leading: Icon(Icons.construction, color: Theme.of(context).colorScheme.primary),
        title: Text(request.title),
        subtitle: Text('${request.propertyTitle} • ${request.priority}'),
        trailing: Text(request.status),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MaintenanceEditPage(request: request, editContext: editContext),
          ),
        ),
      ),
    );
  }
}

class DocumentItem {
  DocumentItem(this.id, this.propertyId, this.propertyTitle, this.title, this.type, this.fileUrl);

  final String id;
  final String propertyId;
  final String propertyTitle;
  final String title;
  final String type;
  final String? fileUrl;

  factory DocumentItem.fromJson(Map<String, dynamic> json) => DocumentItem(
        json['id'] as String? ?? '',
        (json['property'] as Map<String, dynamic>?)?['id'] as String? ?? '',
        _nestedTitle(json['property']),
        json['title'] as String? ?? '-',
        json['documentType'] as String? ?? '-',
        json['file'] as String?,
      );
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

class ContractUploadCard extends StatelessWidget {
  const ContractUploadCard({required this.properties, required this.editContext, super.key});

  final List<Property> properties;
  final PropertyEditContext editContext;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: IvoryColors.green.withOpacity(0.08),
      child: ListTile(
        leading: const Icon(Icons.upload_file, color: IvoryColors.green),
        title: const Text('Ajouter un contrat de location'),
        subtitle: const Text('Associer un bail à une propriété louée'),
        onTap: editContext.canEdit
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LeaseContractUploadPage(properties: properties, editContext: editContext),
                  ),
                )
            : null,
      ),
    );
  }
}

class LeaseContractUploadPage extends StatefulWidget {
  const LeaseContractUploadPage({required this.properties, required this.editContext, super.key});

  final List<Property> properties;
  final PropertyEditContext editContext;

  @override
  State<LeaseContractUploadPage> createState() => _LeaseContractUploadPageState();
}

class _LeaseContractUploadPageState extends State<LeaseContractUploadPage> {
  final titleController = TextEditingController(text: 'Contrat de location');
  String? propertyId;
  PlatformFile? selectedFile;
  bool uploading = false;
  String? error;

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(withData: false);
    if (result == null || result.files.single.path == null) return;
    setState(() => selectedFile = result.files.single);
  }

  Future<void> _upload() async {
    if (propertyId == null || selectedFile?.path == null || titleController.text.trim().isEmpty) {
      setState(() => error = 'Choisissez une propriété, un titre et un fichier.');
      return;
    }
    setState(() {
      uploading = true;
      error = null;
    });
    try {
      final uri = Uri.parse('${widget.editContext.mediaEndpoint}/api/properties/$propertyId/documents');
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer ${widget.editContext.token}'
        ..fields['title'] = titleController.text.trim();
      request.files.add(await http.MultipartFile.fromPath('file', selectedFile!.path!));
      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Upload HTTP ${response.statusCode}');
      }
      if (mounted) {
        widget.editContext.onUpdated();
        Navigator.of(context).pop();
      }
    } catch (exception) {
      setState(() => error = 'Contrat impossible à téléverser : $exception');
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un contrat')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DropdownButtonFormField<String>(
            value: propertyId,
            decoration: const InputDecoration(labelText: 'Propriété louée'),
            items: widget.properties
                .where((property) => property.id != null)
                .map((property) => DropdownMenuItem(value: property.id, child: Text(property.title)))
                .toList(),
            onChanged: (value) => setState(() => propertyId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: titleController,
            decoration: const InputDecoration(labelText: 'Titre du document'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: uploading ? null : _selectFile,
            icon: const Icon(Icons.attach_file),
            label: Text(selectedFile?.name ?? 'Choisir le fichier du contrat'),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: uploading ? null : _upload,
            icon: uploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator()) : const Icon(Icons.cloud_upload),
            label: Text(uploading ? 'Téléversement...' : 'Téléverser le contrat'),
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

class MaintenanceEditPage extends StatefulWidget {
  const MaintenanceEditPage({required this.request, required this.editContext, super.key});

  final Maintenance request;
  final PropertyEditContext editContext;

  @override
  State<MaintenanceEditPage> createState() => _MaintenanceEditPageState();
}

class _MaintenanceEditPageState extends State<MaintenanceEditPage> {
  late final titleController = TextEditingController(text: widget.request.title);
  late final descriptionController = TextEditingController(text: widget.request.description);
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
      setState(() => error = 'Modification impossible : $exception');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier la maintenance')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(widget.request.propertyTitle, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Sujet')),
          const SizedBox(height: 12),
          TextField(
            controller: descriptionController,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Description du problème'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: priority,
            decoration: const InputDecoration(labelText: 'Priorité'),
            items: const [
              DropdownMenuItem(value: 'low', child: Text('Faible')),
              DropdownMenuItem(value: 'normal', child: Text('Normale')),
              DropdownMenuItem(value: 'high', child: Text('Haute')),
              DropdownMenuItem(value: 'urgent', child: Text('Urgente')),
            ],
            onChanged: (value) => setState(() => priority = value ?? priority),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: status,
            decoration: const InputDecoration(labelText: 'Statut'),
            items: const [
              DropdownMenuItem(value: 'open', child: Text('Ouverte')),
              DropdownMenuItem(value: 'in_progress', child: Text('En cours')),
              DropdownMenuItem(value: 'resolved', child: Text('Résolue')),
              DropdownMenuItem(value: 'cancelled', child: Text('Annulée')),
            ],
            onChanged: (value) => setState(() => status = value ?? status),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator()) : const Icon(Icons.save),
            label: Text(saving ? 'Enregistrement...' : 'Enregistrer'),
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

class InfoTile extends StatelessWidget {
  const InfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: ListTile(
          leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: trailing == null ? null : Text(trailing!),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Text(message),
        ),
      );
}

class ErrorCard extends StatelessWidget {
  const ErrorCard(this.message, {super.key});
  final String message;

  @override
  Widget build(BuildContext context) => Card(
        color: const Color(0xFFFFF1E8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Text(message, style: const TextStyle(color: Color(0xFF9A3D16))),
        ),
      );
}

class CacheStatusBar extends StatelessWidget {
  const CacheStatusBar({required this.lastSynced, required this.loading, super.key});

  final DateTime? lastSynced;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final label = loading
        ? 'Synchronisation en cours...'
        : lastSynced == null
            ? 'Aucune donn\u00e9e en cache \u2014 tirez vers le bas pour synchroniser'
            : 'Donn\u00e9es en cache \u2014 derni\u00e8re mise \u00e0 jour ${_formatTimestamp(lastSynced!)}';

    return Row(
      children: [
        Icon(loading ? Icons.sync : Icons.cached, size: 14, color: Colors.black45),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.black45)),
        ),
      ],
    );
  }
}

String _formatTimestamp(DateTime dt) {
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(dt.day)}/${two(dt.month)} \u00e0 ${two(dt.hour)}:${two(dt.minute)}';
}

class MutedText extends StatelessWidget {
  const MutedText(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(color: Colors.black54));
}

class TestDataBadge extends StatelessWidget {
  const TestDataBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE0A800)),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.science, size: 12, color: Color(0xFF8A6D00)),
          SizedBox(width: 4),
          Text('Donnée de test', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF8A6D00))),
        ],
      ),
    );
  }
}

class GraphQLClient {
  Future<Map<String, dynamic>> query(
    String endpoint,
    String token,
    String query, {
    Map<String, dynamic> variables = const {},
  }) async {
    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Accept-Language': 'fr',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'query': query, 'variables': variables}),
    );

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300 || payload['errors'] != null) {
      throw Exception(payload['errors'] ?? 'HTTP ${response.statusCode}');
    }

    return payload['data'] as Map<String, dynamic>;
  }

  Future<String> login(String endpoint, String username, String password) async {
    final data = await query(
      endpoint,
      '',
      loginMutation,
      variables: {'username': username, 'password': password},
    );
    return data['tokenAuth']['token'] as String;
  }
}

const loginMutation = r'''
mutation Login($username: String!, $password: String!) {
  tokenAuth(username: $username, password: $password) { token }
}
''';

class ManagerDashboard {
  ManagerDashboard(this.properties, this.leases, this.documents, this.payments, this.maintenance, this.notifications, this.interestRequests);

  final List<Property> properties;
  final List<LeaseItem> leases;
  final List<DocumentItem> documents;
  final List<Payment> payments;
  final List<Maintenance> maintenance;
  final List<NotificationItem> notifications;
  final List<InterestRequestItem> interestRequests;

  factory ManagerDashboard.fromJson(Map<String, dynamic> json) => ManagerDashboard(
        _items(json['myLandlordProperties']).map(Property.fromJson).toList(),
        _items(json['leases']).map(LeaseItem.fromJson).toList(),
        _items(json['propertyDocuments']).map(DocumentItem.fromJson).toList(),
        _items(json['rentPayments']).map(Payment.fromJson).toList(),
        _items(json['maintenanceRequests']).map(Maintenance.fromJson).toList(),
        _items(json['notifications']).map(NotificationItem.fromJson).toList(),
        _items(json['propertyInterestRequests']).map(InterestRequestItem.fromJson).toList(),
      );

  factory ManagerDashboard.demo() => ManagerDashboard(
        [
          Property(
            'Villa de prestige',
            'Residence',
            'Abidjan',
            'Cocody',
            5,
            220,
            920000,
            'Disponible',
            isTestData: true,
            description: 'Villa moderne avec piscine, jardin paysager et garage double.',
            mainImageUrl: 'https://placehold.co/600x400',
            hasVideo: true,
            videoUrl: 'https://media.w3.org/2010/05/sintel/trailer.mp4',
          ),
          Property('Appartement duplex', 'Residence', 'Abidjan', 'Yopougon', 4, 170, 710000, 'Loué', isTestData: true, description: 'Duplex lumineux avec balcon panoramique sur la lagune.'),
          Property('Studio meublé', 'Residence', 'Yamoussoukro', 'Centre', 1, 42, 195000, 'Disponible', isTestData: true, description: 'Studio compact et meublé, idéal pour étudiant ou jeune actif.'),
          Property('Bureau commercial', 'Business', 'Abidjan', 'Plateau', 2, 98, 480000, 'Occupé', isTestData: true, description: 'Espace de bureaux climatisé, proche des institutions financières.'),
          Property('Local commercial passant', 'Commerce', 'Yamoussoukro', 'Centre', 1, 60, 260000, 'Disponible', isTestData: true, description: 'Local en rez-de-chaussée avec forte visibilité et grand accès client.'),
          Property('Entrepôt logistique', 'Industrie', 'Abidjan', 'Vridi', 1, 540, 1150000, 'Disponible', isTestData: true, description: 'Entrepôt sécurisé avec quai de chargement et bureaux annexes.'),
        ],
        [
          LeaseItem('Villa de prestige', '01/09/2026', '920000', 'Actif'),
          LeaseItem('Appartement duplex', '15/08/2026', '710000', 'Actif'),
        ],
        [],
        [
          Payment('Villa de prestige', '920000', 'Payé'),
          Payment('Appartement duplex', '710000', 'En attente'),
        ],
        [
          Maintenance('1', 'Villa de prestige', 'Remplacement plomberie', 'Fuite dans la salle de bain.', 'Moyenne', 'Planifiée'),
          Maintenance('2', 'Appartement duplex', 'Nettoyage toiture', 'Entretien préventif de la toiture.', 'Faible', 'En cours'),
        ],
        [],
        [],
      );
}

class Property {
  Property(
    this.title,
    this.category,
    this.city,
    this.district,
    this.rooms,
    this.surface,
    this.price,
    this.status, {
    this.id,
    this.isTestData = false,
    this.description = '',
    this.mainImageUrl,
    this.galleryImageUrls = const [],
    this.galleryImageSlots = const [],
    this.hasVideo = false,
    this.videoUrl,
  });

  final String? id;
  final String title;
  final String category;
  final String city;
  final String district;
  final int rooms;
  final int surface;
  final int price;
  final String status;
  final bool isTestData;
  final String description;
  final String? mainImageUrl;
  final List<String> galleryImageUrls;
  final List<String> galleryImageSlots;
  final bool hasVideo;
  final String? videoUrl;

  Property copyWith({
    int? price,
    String? description,
    String? mainImageUrl,
    List<String>? galleryImageUrls,
    List<String>? galleryImageSlots,
    bool? hasVideo,
    String? videoUrl,
    bool clearMainImage = false,
    bool clearVideo = false,
  }) {
    return Property(
      title,
      category,
      city,
      district,
      rooms,
      surface,
      price ?? this.price,
      status,
      id: id,
      isTestData: isTestData,
      description: description ?? this.description,
      mainImageUrl: clearMainImage ? null : mainImageUrl ?? this.mainImageUrl,
      galleryImageUrls: galleryImageUrls ?? this.galleryImageUrls,
      galleryImageSlots: galleryImageSlots ?? this.galleryImageSlots,
      hasVideo: clearVideo ? false : hasVideo ?? this.hasVideo,
      videoUrl: clearVideo ? null : videoUrl ?? this.videoUrl,
    );
  }

  factory Property.fromJson(Map<String, dynamic> json) => Property(
        json['title'] as String? ?? '-',
        (json['category'] as Map<String, dynamic>?)?['title'] as String? ?? 'Autres',
        json['city'] as String? ?? '-',
        json['district'] as String? ?? '-',
        _int(json['rooms']),
        _int(json['surfaceM2']),
        _int(json['price']),
        json['listingStatus'] as String? ?? '-',
        id: json['id'] as String?,
        isTestData: json['isTestData'] as bool? ?? false,
        description: json['description'] as String? ?? '',
        mainImageUrl: json['mainImageUrl'] as String?,
        galleryImageUrls: (json['galleryImageUrls'] as List<dynamic>? ?? const []).cast<String>(),
        galleryImageSlots: (json['galleryImageSlots'] as List<dynamic>? ?? const []).cast<String>(),
        hasVideo: json['hasVideo'] as bool? ?? false,
        videoUrl: json['videoUrl'] as String?,
      );
}

class LeaseItem {
  LeaseItem(this.propertyTitle, this.startDate, this.rentAmount, this.status);

  final String propertyTitle;
  final String startDate;
  final String rentAmount;
  final String status;

  factory LeaseItem.fromJson(Map<String, dynamic> json) => LeaseItem(
        _nestedTitle(json['property']),
        json['startDate'] as String? ?? '-',
        '${json['rentAmount'] ?? '-'}',
        json['status'] as String? ?? '-',
      );
}

class Payment {
  Payment(this.propertyTitle, this.amount, this.status);

  final String propertyTitle;
  final String amount;
  final String status;

  factory Payment.fromJson(Map<String, dynamic> json) => Payment(
        _nestedTitle((json['lease'] as Map<String, dynamic>?)?['property']),
        '${json['amount'] ?? '-'}',
        json['status'] as String? ?? '-',
      );
}

class Maintenance {
  Maintenance(this.id, this.propertyTitle, this.title, this.description, this.priority, this.status);

  final String id;
  final String propertyTitle;
  final String title;
  final String description;
  final String priority;
  final String status;

  factory Maintenance.fromJson(Map<String, dynamic> json) => Maintenance(
        json['id'] as String? ?? '',
        _nestedTitle(json['property']),
        json['title'] as String? ?? '-',
        json['description'] as String? ?? '',
        _maintenancePriority(json['priority']),
        _maintenanceStatus(json['status']),
      );
}

class NotificationItem {
  NotificationItem(this.id, this.title, this.message, this.propertyTitle, this.interestMessage, this.isRead, this.createdAt);

  final String id;
  final String title;
  final String message;
  final String propertyTitle;
  final String interestMessage;
  final bool isRead;
  final String createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        json['id'] as String? ?? '',
        json['title'] as String? ?? 'Notification',
        json['message'] as String? ?? '',
        _nestedTitle(json['property']),
        ((json['interestRequest'] as Map<String, dynamic>?)?['message'] as String?) ?? '',
        json['isRead'] as bool? ?? false,
        json['createdAt'] as String? ?? '',
      );
}

class NotificationTile extends StatelessWidget {
  const NotificationTile(this.notification, {required this.editContext, super.key});

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Suppression impossible : $exception')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          notification.isRead ? Icons.notifications_none : Icons.notifications_active,
          color: notification.isRead ? Colors.grey : IvoryColors.orange,
        ),
        title: Text(notification.title, style: const TextStyle(fontWeight: FontWeight.w800)),
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
            if (!notification.isRead) const Icon(Icons.circle, size: 10, color: IvoryColors.orange),
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
        leading: const Icon(Icons.notifications_active, color: IvoryColors.orange),
        title: Text(notifications.first.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(
          '${notifications.first.message}\n${notifications.first.propertyTitle}\n'
          '${notifications.first.interestMessage.isEmpty ? 'Aucun message initial.' : notifications.first.interestMessage}',
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: notifications.length > 1 ? Text('+${notifications.length - 1}') : null,
      ),
    );
  }
}

class InterestRequestItem {
  InterestRequestItem(this.id, this.propertyTitle, this.status, this.profession, this.salaryRange, this.employer, this.occupantsCount, this.leaseStartDate, this.message);

  final String id;
  final String propertyTitle;
  final String status;
  final String profession;
  final String salaryRange;
  final String employer;
  final int occupantsCount;
  final String leaseStartDate;
  final String message;

  factory InterestRequestItem.fromJson(Map<String, dynamic> json) => InterestRequestItem(
        json['id'] as String? ?? '',
        _nestedTitle(json['property']),
        json['status'] as String? ?? '-',
        json['profession'] as String? ?? '-',
        json['salaryRange'] as String? ?? '-',
        json['employer'] as String? ?? '',
        _int(json['occupantsCount']),
        json['leaseStartDate'] as String? ?? '-',
        json['message'] as String? ?? '',
      );
}

class InterestRequestTile extends StatelessWidget {
  const InterestRequestTile(this.request, {required this.endpoint, required this.token, super.key});

  final InterestRequestItem request;
  final String endpoint;
  final String token;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.forum, color: IvoryColors.green),
        title: Text(request.propertyTitle, style: const TextStyle(fontWeight: FontWeight.w800)),
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

class InterestChatPage extends StatefulWidget {
  const InterestChatPage({required this.interestRequestId, required this.propertyTitle, required this.endpoint, required this.token, required this.isManager, super.key});

  final String interestRequestId;
  final String propertyTitle;
  final String endpoint;
  final String token;
  final bool isManager;

  @override
  State<InterestChatPage> createState() => _InterestChatPageState();
}

class _InterestChatPageState extends State<InterestChatPage> {
  final messageController = TextEditingController();
  List<InterestMessageItem> messages = [];
  String messageType = 'message';
  DateTime? proposedVisitAt;
  bool loading = true;
  bool sending = false;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      final data = await GraphQLClient().query(widget.endpoint, widget.token, interestMessagesQuery, variables: {'interestRequestId': widget.interestRequestId});
      if (mounted) setState(() => messages = _items(data['propertyInterestMessages']).map(InterestMessageItem.fromJson).toList());
    } catch (exception) {
      if (mounted) setState(() => error = 'Chargement impossible : $exception');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _chooseVisitDate() async {
    final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), initialDate: proposedVisitAt ?? DateTime.now());
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(proposedVisitAt ?? DateTime.now()));
    if (time != null) setState(() => proposedVisitAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  Future<void> _send() async {
    if (messageController.text.trim().isEmpty || (messageType == 'visit_proposal' && proposedVisitAt == null)) return;
    setState(() { sending = true; error = null; });
    try {
      await GraphQLClient().query(widget.endpoint, widget.token, sendInterestMessageMutation, variables: {
        'interestRequestId': widget.interestRequestId,
        'message': messageController.text.trim(),
        'messageType': messageType,
        'proposedVisitAt': proposedVisitAt?.toUtc().toIso8601String(),
      });
      messageController.clear();
      await _loadMessages();
    } catch (exception) {
      if (mounted) setState(() => error = 'Envoi impossible : $exception');
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.propertyTitle)),
      body: Column(
        children: [
          if (error != null) Padding(padding: const EdgeInsets.all(12), child: Text(error!, style: const TextStyle(color: Colors.red))),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(child: Text('Aucun message.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) => _MessageBubble(message: messages[index]),
                      ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            color: Colors.white,
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: DropdownButtonFormField<String>(value: messageType, decoration: const InputDecoration(labelText: 'Type'), items: const [
                    DropdownMenuItem(value: 'message', child: Text('Message')),
                    DropdownMenuItem(value: 'visit_proposal', child: Text('Proposer une visite')),
                    DropdownMenuItem(value: 'visit_confirmation', child: Text('Confirmer la visite')),
                    DropdownMenuItem(value: 'visit_declined', child: Text('Refuser la visite')),
                  ], onChanged: (value) => setState(() => messageType = value ?? 'message'))),
                  if (messageType == 'visit_proposal') IconButton(onPressed: _chooseVisitDate, icon: const Icon(Icons.event), tooltip: 'Choisir une date'),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: TextField(controller: messageController, minLines: 1, maxLines: 3, decoration: const InputDecoration(hintText: 'Votre message'))),
                  const SizedBox(width: 8),
                  IconButton(onPressed: sending ? null : _send, icon: sending ? const CircularProgressIndicator() : const Icon(Icons.send), color: IvoryColors.green, tooltip: 'Envoyer'),
                ]),
                if (proposedVisitAt != null) Align(alignment: Alignment.centerLeft, child: Text('Visite : ${proposedVisitAt!.day}/${proposedVisitAt!.month}/${proposedVisitAt!.year} à ${proposedVisitAt!.hour.toString().padLeft(2, '0')}:${proposedVisitAt!.minute.toString().padLeft(2, '0')}')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InterestMessageItem {
  InterestMessageItem(this.message, this.messageType, this.proposedVisitAt, this.createdAt, this.senderUsername);

  final String message;
  final String messageType;
  final String? proposedVisitAt;
  final String createdAt;
  final String senderUsername;

  factory InterestMessageItem.fromJson(Map<String, dynamic> json) => InterestMessageItem(
        json['message'] as String? ?? '',
        json['messageType'] as String? ?? 'message',
        json['proposedVisitAt'] as String?,
        json['createdAt'] as String? ?? '',
        (json['sender'] as Map<String, dynamic>?)?['username'] as String? ?? 'Utilisateur',
      );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});
  final InterestMessageItem message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.senderUsername, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(message.message),
              if (message.proposedVisitAt != null) Text('Visite proposée : ${message.proposedVisitAt}'),
            ],
          ),
        ),
      ),
    );
  }
}

String _maintenancePriority(Object? value) {
  final normalized = '${value ?? ''}'.toLowerCase().replaceAll(' ', '_');
  return const {
        'low': 'low',
        'faible': 'low',
        'normal': 'normal',
        'normale': 'normal',
        'high': 'high',
        'haute': 'high',
        'urgent': 'urgent',
        'urgente': 'urgent',
      }[normalized] ?? 'normal';
}

String _maintenanceStatus(Object? value) {
  final normalized = '${value ?? ''}'.toLowerCase().replaceAll(' ', '_');
  return const {
        'open': 'open',
        'ouverte': 'open',
        'in_progress': 'in_progress',
        'en_cours': 'in_progress',
        'resolved': 'resolved',
        'resolue': 'resolved',
        'cancelled': 'cancelled',
        'annulee': 'cancelled',
      }[normalized] ?? 'open';
}

List<Map<String, dynamic>> _items(Object? value) => (value as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
int _int(Object? value) => value is int ? value : int.tryParse('${value ?? ''}') ?? 0;
String _nestedTitle(Object? value) => (value as Map<String, dynamic>?)?['title'] as String? ?? '-';

const managerQuery = r'''
query ManagerDashboard {
  myLandlordProperties(first: 20) { id title city district rooms surfaceM2 price listingStatus category { title } isTestData description mainImageUrl galleryImageUrls galleryImageSlots hasVideo videoUrl }
  leases { property { title } startDate rentAmount status }
  propertyDocuments { id property { id title } title documentType visibility file createdAt }
  rentPayments { lease { property { title } } amount status }
  maintenanceRequests { id property { title } title description priority status }
  notifications { id title message isRead createdAt property { title } interestRequest { message } }
  propertyInterestRequests { id property { title } status profession salaryRange employer occupantsCount leaseStartDate message }
}
''';

const deleteNotificationMutation = r'''
mutation DeleteNotification($notificationId: ID!) {
  deleteNotification(notificationId: $notificationId) {
    deletedNotificationId
  }
}
''';

const interestMessagesQuery = r'''
query InterestMessages($interestRequestId: ID!) {
  propertyInterestMessages(interestRequestId: $interestRequestId) {
    id message messageType proposedVisitAt createdAt sender { username }
  }
}
''';

const sendInterestMessageMutation = r'''
mutation SendInterestMessage($interestRequestId: ID!, $message: String!, $messageType: String, $proposedVisitAt: DateTime) {
  sendPropertyInterestMessage(interestRequestId: $interestRequestId, message: $message, messageType: $messageType, proposedVisitAt: $proposedVisitAt) {
    interestMessage { id message messageType proposedVisitAt createdAt }
  }
}
''';

const updatePropertyListingMutation = r'''
mutation UpdatePropertyListing($propertyId: ID!, $price: Int, $description: String) {
  updatePropertyListing(propertyId: $propertyId, price: $price, description: $description) {
    property { id price description }
  }
}
''';

const updateMaintenanceMutation = r'''
mutation UpdateMaintenance($id: ID!, $title: String, $description: String, $priority: String, $status: String) {
  updateMaintenanceRequest(id: $id, title: $title, description: $description, priority: $priority, status: $status) {
    maintenanceRequest { id title description priority status }
  }
}
''';
