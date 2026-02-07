import 'package:flutter/material.dart';

/// Flutter equivalent of the React 3D Pin: card with perspective tilt on hover
/// and overlay with title pill, ripple circles, and gradient line.
class PinContainer extends StatefulWidget {
  final Widget child;
  final String? title;
  final String? href;

  const PinContainer({
    super.key,
    required this.child,
    this.title,
    this.href,
  });

  @override
  State<PinContainer> createState() => _PinContainerState();
}

class _PinContainerState extends State<PinContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _tiltAnimation;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 700),
      vsync: this,
    );
    _tiltAnimation = Tween<double>(begin: 0, end: 40 * (3.14159 / 180)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onEnter(PointerEvent e) {
    setState(() => _hovered = true);
    _controller.forward();
  }

  void _onExit(PointerEvent e) {
    setState(() => _hovered = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: _onEnter,
      onExit: _onExit,
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          final href = widget.href;
          if (href != null && href.isNotEmpty) {
            // url_launcher could be used here
          }
        },
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Perspective overlay (title + ripples + line) - visible when hovered
            if (_hovered) PinPerspective(title: widget.title, href: widget.href),

            // 3D tilted card
            Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001)
                ..rotateX(70 * (3.14159 / 180))
                ..translate(0.0, 0.0),
              child: AnimatedBuilder(
                animation: _tiltAnimation,
                builder: (context, child) {
                  final tilt = _tiltAnimation.value;
                  final scale = 1.0 - (0.2 * _controller.value);
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateX(tilt)
                      ..scale(scale),
                    child: child,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _hovered
                          ? Colors.white.withValues(alpha: 0.2)
                          : Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: widget.child,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Overlay shown on hover: title pill, pulsing circles, gradient line.
class PinPerspective extends StatefulWidget {
  final String? title;
  final String? href;

  const PinPerspective({super.key, this.title, this.href});

  @override
  State<PinPerspective> createState() => _PinPerspectiveState();
}

class _PinPerspectiveState extends State<PinPerspective>
    with TickerProviderStateMixin {
  late List<AnimationController> _rippleControllers;

  @override
  void initState() {
    super.initState();
    _rippleControllers = List.generate(
      3,
      (i) => AnimationController(
        duration: const Duration(seconds: 6),
        vsync: this,
      )..repeat(),
    );
    _rippleControllers[0].forward(from: 0);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _rippleControllers[1].forward(from: 0);
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) _rippleControllers[2].forward(from: 0);
    });
  }

  @override
  void dispose() {
    for (final c in _rippleControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: 384,
        height: 320,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Title pill at top
            Positioned(
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                child: Text(
                  widget.title ?? 'Explore',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Ripple circles (staggered)
            ...List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _rippleControllers[i],
                builder: (context, _) {
                  final t = _rippleControllers[i].value;
                  final opacity = _rippleOpacity(t);
                  return Transform.translate(
                    offset: const Offset(-96, -36),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0EA5E9)
                            .withValues(alpha: 0.08 * opacity),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x40000000),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),

            // Gradient line and dot at bottom
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 1,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.cyan.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0891B2),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.cyan.withValues(alpha: 0.8),
                            blurRadius: 3,
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
      ),
    );
  }

  double _rippleOpacity(double t) {
    if (t < 0.166) return t / 0.166;
    if (t < 0.333) return 1.0;
    if (t < 0.5) return 0.5;
    return 0.0;
  }
}

/// Demo card content matching the React AnimatedPinDemo (Space Station Alpha).
class PinDemoContent extends StatelessWidget {
  const PinDemoContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF334155).withValues(alpha: 0.5),
            const Color(0xFF334155).withValues(alpha: 0),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF475569).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Live Connection',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Space Station Alpha',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatBlock(value: '427', label: 'Days in Orbit', color: 0xFF0EA5E9),
              const SizedBox(width: 16),
              _StatBlock(value: '98%', label: 'Systems Online', color: 0xFF10B981),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last ping: 3 seconds ago',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const Text(
                'Connect →',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0EA5E9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full demo screen: 40rem-height area with one 3D pin card (Space Station Alpha).
class AnimatedPinDemo extends StatelessWidget {
  const AnimatedPinDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 640,
      width: double.infinity,
      color: Theme.of(context).colorScheme.surface,
      alignment: Alignment.center,
      child: const PinContainer(
        title: 'Explore Space',
        href: 'https://github.com/serafimcloud',
        child: PinDemoContent(),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;
  final int color;

  const _StatBlock({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(color),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
