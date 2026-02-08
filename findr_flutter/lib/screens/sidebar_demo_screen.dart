import 'package:flutter/material.dart';
import '../widgets/sidebar.dart';

/// Demo screen that shows the collapsible sidebar (desktop hover + mobile drawer).
class SidebarDemoScreen extends StatelessWidget {
  const SidebarDemoScreen({super.key});

  static List<SidebarLinkData> _links(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? _colorNeutral200 : _colorNeutral700;
    return [
      SidebarLinkData(
        label: 'Dashboard',
        href: '#',
        icon: Icon(Icons.dashboard_outlined, size: 20, color: color),
      ),
      SidebarLinkData(
        label: 'Profile',
        href: '#',
        icon: Icon(Icons.person_outline, size: 20, color: color),
      ),
      SidebarLinkData(
        label: 'Settings',
        href: '#',
        icon: Icon(Icons.settings_outlined, size: 20, color: color),
      ),
      SidebarLinkData(
        label: 'Logout',
        href: '#',
        icon: Icon(Icons.logout, size: 20, color: color),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        color: isDark ? _colorNeutral800 : const Color(0xFFE5E5E5),
        child: SafeArea(
          child: Sidebar(
            initialOpen: false,
            animate: true,
            sidebarContent: _SidebarContent(),
            body: _DashboardPlaceholder(isDark: isDark),
          ),
        ),
      ),
    );
  }
}

class _SidebarContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Logo(),
                const SizedBox(height: 32),
                ...SidebarDemoScreen._links(context).map(
                  (link) => SidebarLink(link: link, onTap: () {}),
                ),
              ],
            ),
          ),
        ),
        SidebarLink(
          link: const SidebarLinkData(
            label: 'User',
            href: '#',
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: _colorNeutral700,
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ),
          onTap: () {},
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 24,
              height: 20,
              decoration: BoxDecoration(
                color: isDark ? Colors.white : Colors.black,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(8),
                  bottomLeft: Radius.circular(4),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Acet Labs',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardPlaceholder extends StatelessWidget {
  const _DashboardPlaceholder({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? _colorNeutral900 : Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16)),
        border: Border.all(
          color: isDark ? const Color(0xFF404040) : const Color(0xFFE5E5E5),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(4, (_) => Expanded(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Container(
                  height: 80,
                  decoration: BoxDecoration(
                    color: isDark ? _colorNeutral800 : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            )),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: List.generate(2, (_) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? _colorNeutral800 : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              )),
            ),
          ),
        ],
      ),
    );
  }
}

const _colorNeutral200 = Color(0xFFE5E5E5);
const _colorNeutral700 = Color(0xFF404040);
const _colorNeutral800 = Color(0xFF262626);
const _colorNeutral900 = Color(0xFF171717);
