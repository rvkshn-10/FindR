import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Flutter equivalent of the React Waves component: animated wave grid
/// with pointer interaction (simplex-style noise + cursor influence).
class WaveBackground extends StatefulWidget {
  final String? className;
  final Color strokeColor;
  final Color backgroundColor;
  final double pointerSize;

  const WaveBackground({
    super.key,
    this.className,
    this.strokeColor = Colors.white,
    this.backgroundColor = Colors.black,
    this.pointerSize = 0.5,
  });

  @override
  State<WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<WaveBackground>
    with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  double _time = 0;

  // Pointer (cursor) state
  double _sx = 0, _sy = 0;
  double _lx = 0, _ly = 0;
  double _x = -10, _y = 0;
  double _vs = 0, _a = 0;
  bool _set = false;

  // Line points: each line is a list of (base offset, wave offset, cursor offset)
  List<List<_Point>> _lines = [];
  Size _size = Size.zero;
  static const double _xGap = 8;
  static const double _yGap = 8;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final t = elapsed.inMilliseconds.toDouble();
    _time = t;

    // Smooth pointer
    _sx += (_x - _sx) * 0.1;
    _sy += (_y - _sy) * 0.1;

    final dx = _x - _lx;
    final dy = _y - _ly;
    final d = math.sqrt(dx * dx + dy * dy);
    _vs += (d - _vs) * 0.1;
    _vs = math.min(100.0, _vs);
    _lx = _x;
    _ly = _y;
    _a = math.atan2(dy, dx);

    _updatePoints();
    if (mounted) setState(() {});
  }

  /// Simple 2D pseudo-noise (smooth wave) without external package.
  double _noise2D(double x, double y) {
    return math.sin(x * 0.003 + _time * 0.008) *
        math.cos(y * 0.002 + _time * 0.003) *
        8;
  }

  void _updatePoints() {
    if (_size.width <= 0 || _size.height <= 0) return;

    final l = math.max(175.0, _vs);

    for (var li = 0; li < _lines.length; li++) {
      final points = _lines[li];
      for (var pi = 0; pi < points.length; pi++) {
        final p = points[pi];
        final move = _noise2D(p.baseX + _time * 0.008, p.baseY + _time * 0.003);
        p.waveX = math.cos(move) * 12;
        p.waveY = math.sin(move) * 6;

        final dx = p.baseX - _sx;
        final dy = p.baseY - _sy;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < l) {
          final s = 1 - d / l;
          final f = math.cos(d * 0.001) * s;
          p.cursorVx += math.cos(_a) * f * l * _vs * 0.00035;
          p.cursorVy += math.sin(_a) * f * l * _vs * 0.00035;
        }
        p.cursorVx += (0 - p.cursorX) * 0.01;
        p.cursorVy += (0 - p.cursorY) * 0.01;
        p.cursorVx *= 0.95;
        p.cursorVy *= 0.95;
        p.cursorX += p.cursorVx;
        p.cursorY += p.cursorVy;
        p.cursorX = p.cursorX.clamp(-50.0, 50.0);
        p.cursorY = p.cursorY.clamp(-50.0, 50.0);
      }
    }
  }

  void _buildLines() {
    if (_size.width <= 0 || _size.height <= 0) return;

    final oWidth = _size.width + 200;
    final oHeight = _size.height + 30;
    final totalLines = (oWidth / _xGap).ceil();
    final totalPoints = (oHeight / _yGap).ceil();
    final xStart = (_size.width - _xGap * totalLines) / 2;
    final yStart = (_size.height - _yGap * totalPoints) / 2;

    _lines = List.generate(totalLines, (i) {
      return List.generate(totalPoints, (j) {
        return _Point(
          baseX: xStart + _xGap * i,
          baseY: yStart + _yGap * j,
        );
      });
    });
  }

  void _onPointerMove(PointerEvent event) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.globalToLocal(event.position);
    setState(() {
      _x = pos.dx;
      _y = pos.dy;
      if (!_set) {
        _sx = _x;
        _sy = _y;
        _lx = _x;
        _ly = _y;
        _set = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        if (size != _size || _lines.isEmpty) {
          _size = size;
          _buildLines();
        }

        return Listener(
          onPointerMove: _onPointerMove,
          onPointerDown: _onPointerMove,
          child: CustomPaint(
            painter: _WavePainter(
              lines: _lines,
              strokeColor: widget.strokeColor,
              backgroundColor: widget.backgroundColor,
              pointerSize: widget.pointerSize,
              pointerX: _sx,
              pointerY: _sy,
            ),
            size: size,
          ),
        );
      },
    );
  }
}

class _Point {
  final double baseX;
  final double baseY;
  double waveX = 0;
  double waveY = 0;
  double cursorX = 0;
  double cursorY = 0;
  double cursorVx = 0;
  double cursorVy = 0;

  _Point({required this.baseX, required this.baseY});
}

class _WavePainter extends CustomPainter {
  final List<List<_Point>> lines;
  final Color strokeColor;
  final Color backgroundColor;
  final double pointerSize;
  final double pointerX;
  final double pointerY;

  _WavePainter({
    required this.lines,
    required this.strokeColor,
    required this.backgroundColor,
    required this.pointerSize,
    required this.pointerX,
    required this.pointerY,
  });

  Offset _moved(_Point p, {bool withCursor = true}) {
    return Offset(
      p.baseX + p.waveX + (withCursor ? p.cursorX : 0),
      p.baseY + p.waveY + (withCursor ? p.cursorY : 0),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final strokePaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final points in lines) {
      if (points.length < 2) continue;
      final path = Path();
      final first = _moved(points[0], withCursor: false);
      path.moveTo(first.dx, first.dy);
      for (var i = 1; i < points.length; i++) {
        final o = _moved(points[i]);
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, strokePaint);
    }

    final dotPaint = Paint()..color = strokeColor;
    final r = pointerSize * 8;
    canvas.drawCircle(Offset(pointerX, pointerY), r, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => true;
}

/// Demo layout matching the React WavesDemo: full-width 16:9 wave with borders.
class WaveBackgroundDemo extends StatelessWidget {
  const WaveBackgroundDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: double.infinity, height: 1, color: Colors.white24),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: const WaveBackground(
                strokeColor: Colors.white,
                backgroundColor: Colors.black,
              ),
            ),
            Container(width: double.infinity, height: 1, color: Colors.white24),
          ],
        ),
      ),
    );
  }
}
