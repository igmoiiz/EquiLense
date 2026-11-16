import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class _Dest {
  const _Dest(this.path, this.label, this.icon, this.selectedIcon);
  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _destinations = [
  _Dest('/dashboard', 'Dashboard', Icons.space_dashboard_outlined, Icons.space_dashboard),
  _Dest('/analyses', 'Analyses', Icons.compare_arrows_outlined, Icons.compare_arrows),
  _Dest('/companies', 'Companies', Icons.business_outlined, Icons.business),
  _Dest('/profile', 'Profile', Icons.person_outline, Icons.person),
];

/// Bottom navigation on phones, navigation rail on tablets/web.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  int get _index {
    final i = _destinations.indexWhere((d) => location.startsWith(d.path));
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    void go(int i) => context.go(_destinations[i].path);

    if (wide) {
      final t = Theme.of(context);
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: go,
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(children: [
                Icon(Icons.analytics_outlined, color: t.colorScheme.primary, size: 28),
                const SizedBox(height: 4),
                Text('EquiLense', style: t.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700)),
              ]),
            ),
            destinations: [
              for (final d in _destinations)
                NavigationRailDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: Text(d.label)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ]),
      );
    }
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: go,
        destinations: [
          for (final d in _destinations)
            NavigationDestination(icon: Icon(d.icon), selectedIcon: Icon(d.selectedIcon), label: d.label),
        ],
      ),
    );
  }
}
