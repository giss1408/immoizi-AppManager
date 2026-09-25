import 'package:flutter/material.dart';
import 'package:immoizi_core/immoizi_core.dart';

import '../models/dashboard.dart';
import '../pages/property_detail_page.dart';
import '../pages/property_form_page.dart';
import '../property_edit_context.dart';

class ManagerDashboardView extends StatelessWidget {
  const ManagerDashboardView(this.dashboard,
      {required this.editContext,
      this.searchQuery = '',
      this.filters = const PropertyFilters(),
      super.key});

  final ManagerDashboard dashboard;
  final PropertyEditContext editContext;
  final String searchQuery;
  final PropertyFilters filters;

  Future<void> _addProperty(BuildContext context) async {
    final navigator = Navigator.of(context);
    final created = await navigator.push<Property>(MaterialPageRoute(
        builder: (_) => PropertyFormPage(editContext: editContext)));
    if (created == null) return;
    editContext.onUpdated();
    await navigator.push(MaterialPageRoute(
        builder: (_) => PropertyDetailPage(
            property: created, editContext: editContext, openEditor: true)));
  }

  @override
  Widget build(BuildContext context) {
    final query = searchQuery.trim().toLowerCase();
    final properties = dashboard.properties.where((property) {
      final matchesSearch = query.isEmpty ||
          property.title.toLowerCase().contains(query) ||
          property.city.toLowerCase().contains(query) ||
          property.district.toLowerCase().contains(query);
      return matchesSearch && filters.matches(property);
    }).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader('Mes biens',
            count: properties.length,
            subtitle: 'Annonces et biens de votre portefeuille'),
        if (editContext.canEdit)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: FilledButton.icon(
              onPressed: () => _addProperty(context),
              icon: const Icon(Icons.add_home_outlined),
              label: const Text('Ajouter un bien'),
            ),
          ),
        GroupedPropertyList(
          properties: properties,
          cardBuilder: (property) =>
              PropertyCard(property, editContext: editContext),
        ),
      ],
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
        border: Border.all(color: IvoryColors.border),
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
            child: Icon(icon,
                size: 18, color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$value',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w900)),
                Text(label,
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
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
    return PropertyListingCard(
      property,
      statusLabel: listingStatusLabel(property.status),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => PropertyDetailPage(
                property: property, editContext: editContext)),
      ),
    );
  }
}
