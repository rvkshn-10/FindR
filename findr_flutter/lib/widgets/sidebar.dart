import 'package:flutter/material.dart';

// --- Sidebar scope (equivalent to React SidebarContext) ---

class SidebarScope extends InheritedWidget {
  const SidebarScope({
    super.key,
    required this.open,
    required this.setOpen,
    required this.animate,
    required super.child,
  });

  final bool open;
  final VoidCallback setOpen;
  final bool animate;

  static SidebarScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SidebarScope>();
  }

  static SidebarScope of(BuildContext context) {
    final scope = maybeOf(context);
    assert(scope != null, 'SidebarScope not found. Use Sidebar as ancestor.');
    return scope!;
  }

  @override
  bool updateShouldNotify(SidebarScope oldWidget) {
    return open != oldWidget.open ||
        setOpen != oldWidget.setOpen ||
        animate != oldWidget.animate;
  }
}

// --- Link data (equivalent to React Links) ---

class SidebarLinkData {
  const SidebarLinkData({
    required this.label,
    required this.href,
    required this.icon,
  });

  final String label;
  final String href;
  final Widget icon;
}

// --- Sidebar (provider + layout: sidebar + body) ---

class Sidebar extends StatefulWidget {
  const Sidebar({
    super.key,
    this.initialOpen = false,
    this.animate = true,
    required this.sidebarContent,
    required this.body,
  });

  final bool initialOpen;
  final bool animate;
  /// Content shown inside the sidebar (logo, links, user). Same on desktop and mobile.
  final Widget sidebarContent;
  /// Main content next to the sidebar (e.g. dashboard).
  final Widget body;

  @override
  State<Sidebar> createState() => _SidebarState();
}

class _SidebarState extends State<Sidebar> {
  late bool _open;

  @override
  void initState() {
    super.initState();
    _open = widget.initialOpen;
  }

  void _toggleOpen() {
    setState(() => _open = !_open);
  }

  @override
  Widget build(BuildContext context) {
    return SidebarScope(
      open: _open,
      setOpen: _toggleOpen,
      animate: widget.animate,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 600;
          final topPadding = isDesktop ? 0.0 : 56.0 + MediaQuery.paddingOf(context).top;

          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isDesktop)
                    _DesktopSidebar(sidebarContent: widget.sidebarContent),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: topPadding),
                      child: widget.body,
                    ),
                  ),
                ],
              ),
              if (!isDesktop)
                _MobileSidebar(sidebarContent: widget.sidebarContent),
            ],
          );
        },
      ),
    );
  }
}

// --- Desktop sidebar (hover to expand, animated width) ---

class _DesktopSidebar extends StatefulWidget {
  const _DesktopSidebar({required this.sidebarContent});

  final Widget sidebarContent;

  @override
  State<_DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends State<_DesktopSidebar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scope = SidebarScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final open = scope.animate ? (scope.open || _hover) : true;
    final width = open ? 300.0 : 60.0;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        color: isDark ? _colorNeutral800 : _colorNeutral100,
        child: widget.sidebarContent,
      ),
    );
  }
}

// --- Mobile sidebar (top bar + overlay drawer) ---

class _MobileSidebar extends StatelessWidget {
  const _MobileSidebar({required this.sidebarContent});

  final Widget sidebarContent;

  @override
  Widget build(BuildContext context) {
    final scope = SidebarScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      children: [
        // Top bar only (overlays the body)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? _colorNeutral800 : _colorNeutral100,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: scope.setOpen,
                  color: isDark ? _colorNeutral200 : _colorNeutral800,
                ),
              ],
            ),
            ),
          ),
        ),
        if (scope.open) ...[
          Positioned.fill(
            child: GestureDetector(
              onTap: scope.setOpen,
              child: Container(color: Colors.black54),
            ),
          ),
          Positioned(
            top: 56 + MediaQuery.paddingOf(context).top,
            left: 0,
            bottom: 0,
            width: MediaQuery.sizeOf(context).width * 0.85,
            child: Material(
              color: isDark ? _colorNeutral900 : Colors.white,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: scope.setOpen,
                          color: isDark ? _colorNeutral200 : _colorNeutral800,
                        ),
                      ),
                      Expanded(child: SingleChildScrollView(child: sidebarContent)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// --- SidebarLink ---

class SidebarLink extends StatelessWidget {
  const SidebarLink({
    super.key,
    required this.link,
    this.onTap,
  });

  final SidebarLinkData link;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scope = SidebarScope.maybeOf(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final open = scope?.open ?? true;
    final animate = scope?.animate ?? true;
    final showLabel = animate ? open : true;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            SizedBox(width: 24, height: 24, child: link.icon),
            if (showLabel) ...[
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  link.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? _colorNeutral200 : _colorNeutral700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// --- Themed colors (neutral palette) ---

const _colorNeutral100 = Color(0xFFF5F5F5);
const _colorNeutral200 = Color(0xFFE5E5E5);
const _colorNeutral700 = Color(0xFF404040);
const _colorNeutral800 = Color(0xFF262626);
const _colorNeutral900 = Color(0xFF171717);
