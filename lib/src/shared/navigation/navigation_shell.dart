import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class NavigationShell extends StatelessWidget {
  const NavigationShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final destinations = _NavigationDestinationData.values;
    final selectedIndex = _selectedIndex(context, destinations);

    return Scaffold(
      body: Row(
        children: [
          if (MediaQuery.sizeOf(context).width >= 800)
            NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  context.go(destinations[index].path),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final destination in destinations)
                  NavigationRailDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: Text(destination.label),
                  ),
              ],
            ),
          Expanded(child: child),
        ],
      ),
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 800
          ? NavigationBar(
              selectedIndex: selectedIndex,
              onDestinationSelected: (index) =>
                  context.go(destinations[index].path),
              destinations: [
                for (final destination in destinations)
                  NavigationDestination(
                    icon: Icon(destination.icon),
                    selectedIcon: Icon(destination.selectedIcon),
                    label: destination.label,
                  ),
              ],
            )
          : null,
    );
  }

  int _selectedIndex(
    BuildContext context,
    List<_NavigationDestinationData> destinations,
  ) {
    final location = GoRouterState.of(context).uri.path;
    final index = destinations.indexWhere(
      (destination) => location.startsWith(destination.path),
    );
    return index < 0 ? 0 : index;
  }
}

class _NavigationDestinationData {
  const _NavigationDestinationData({
    required this.label,
    required this.path,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final String path;
  final IconData icon;
  final IconData selectedIcon;

  static const values = [
    _NavigationDestinationData(
      label: 'Dashboard',
      path: '/dashboard',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
    ),
    _NavigationDestinationData(
      label: 'Customers',
      path: '/customers',
      icon: Icons.people_outline,
      selectedIcon: Icons.people,
    ),
    _NavigationDestinationData(
      label: 'Products',
      path: '/products',
      icon: Icons.inventory_2_outlined,
      selectedIcon: Icons.inventory_2,
    ),
    _NavigationDestinationData(
      label: 'Sales',
      path: '/sales',
      icon: Icons.point_of_sale_outlined,
      selectedIcon: Icons.point_of_sale,
    ),
    _NavigationDestinationData(
      label: 'Expenses',
      path: '/expenses',
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long,
    ),
    _NavigationDestinationData(
      label: 'Reports',
      path: '/reports',
      icon: Icons.assessment_outlined,
      selectedIcon: Icons.assessment,
    ),
    _NavigationDestinationData(
      label: 'Revenue',
      path: '/revenue',
      icon: Icons.payments_outlined,
      selectedIcon: Icons.payments,
    ),
    _NavigationDestinationData(
      label: 'Tasks',
      path: '/tasks',
      icon: Icons.task_alt_outlined,
      selectedIcon: Icons.task_alt,
    ),
    _NavigationDestinationData(
      label: 'Cashflow',
      path: '/cashflow',
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
    ),
  ];
}
