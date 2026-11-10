// TankLoader — animated tank loading indicator for Flutter.
// Pure Dart (CustomPainter), no packages or asset files needed.
// Works on Android, iOS, desktop and Flutter web.
//
//   import 'tank_loader.dart';
//
//   const TankLoader(size: 220)
//
// Options:
//   size        diameter in logical pixels
//   ink         line colour
//   paper       background colour inside the circle
//   speed       cruising speed (default 165)
//   fireEvery   seconds between shots, 0 = never fire
//
// This is a line-for-line port of tank-loader.js.

import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class TankLoader extends StatefulWidget {
  const TankLoader({
    super.key,
    this.size = 240,
    this.ink = const Color(0xFFC8102E),
    this.paper = const Color(0xFFFBFAF3),
    this.speed = 165,
    this.fireEvery = 6.5,
    this.semanticsLabel = 'Loading',
  });

  final double size;
  final Color ink;
  final Color paper;
  final double speed;
  final double fireEvery;
  final String semanticsLabel;

  @override
  State<TankLoader> createState() => _TankLoaderState();
}

class _TankLoaderState extends State<TankLoader>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  late final _Sim _sim;
  final ValueNotifier<int> _repaint = ValueNotifier<int>(0);
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _sim = _Sim(speed: widget.speed, fireEvery: widget.fireEvery);
    _ticker = createTicker(_tick);
  }

  void _tick(Duration elapsed) {
    _sim.step(elapsed.inMicroseconds / 1e6);
    _repaint.value++;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respect the system "reduce motion" setting: show one still frame.
    _still = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (_still) {
      if (_ticker.isActive) _ticker.stop();
      _sim.freeze();
      _repaint.value++;
    } else if (!_ticker.isActive) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(TankLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sim.speed = widget.speed;
    _sim.setFireEvery(widget.fireEvery);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel,
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _TankPainter(_sim, widget.ink, widget.paper, _repaint),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shapes
// ---------------------------------------------------------------------------

const int _ln = 0; // stroke only
const int _sf = 1; // paper fill + ink stroke
const int _inkFill = 2;
const int _paperFill = 3;

class _Shape {
  _Shape(this.path, this.kind, [this.sw = 2.1]);
  final Path path;
  final int kind;
  final double sw;
}

final RegExp _token = RegExp(r'([MmLlHhVvCcQqZz])|(-?\d*\.?\d+)');

/// Minimal SVG path reader (M L H V Q C Z, absolute and relative).
Path _svg(String d) {
  final Path p = Path();
  final List<RegExpMatch> tk = _token.allMatches(d).toList();
  int i = 0;
  String cmd = '';
  double x = 0, y = 0, sx = 0, sy = 0;
  double n() => double.parse(tk[i++].group(0)!);
  while (i < tk.length) {
    if (tk[i].group(1) != null) {
      cmd = tk[i].group(1)!;
      i++;
    }
    switch (cmd) {
      case 'M':
        x = n();
        y = n();
        p.moveTo(x, y);
        sx = x;
        sy = y;
        cmd = 'L';
        break;
      case 'm':
        x += n();
        y += n();
        p.moveTo(x, y);
        sx = x;
        sy = y;
        cmd = 'l';
        break;
      case 'L':
        x = n();
        y = n();
        p.lineTo(x, y);
        break;
      case 'l':
        x += n();
        y += n();
        p.lineTo(x, y);
        break;
      case 'H':
        x = n();
        p.lineTo(x, y);
        break;
      case 'h':
        x += n();
        p.lineTo(x, y);
        break;
      case 'V':
        y = n();
        p.lineTo(x, y);
        break;
      case 'v':
        y += n();
        p.lineTo(x, y);
        break;
      case 'Q':
        {
          final double x1 = n(), y1 = n();
          x = n();
          y = n();
          p.quadraticBezierTo(x1, y1, x, y);
        }
        break;
      case 'q':
        {
          final double x1 = x + n(), y1 = y + n();
          x += n();
          y += n();
          p.quadraticBezierTo(x1, y1, x, y);
        }
        break;
      case 'C':
        {
          final double x1 = n(), y1 = n(), x2 = n(), y2 = n();
          x = n();
          y = n();
          p.cubicTo(x1, y1, x2, y2, x, y);
        }
        break;
      case 'c':
        {
          final double x1 = x + n(), y1 = y + n();
          final double x2 = x + n(), y2 = y + n();
          x += n();
          y += n();
          p.cubicTo(x1, y1, x2, y2, x, y);
        }
        break;
      case 'Z':
      case 'z':
        p.close();
        x = sx;
        y = sy;
        cmd = '';
        break;
      default:
        i++; // skip anything unexpected
    }
  }
  return p;
}

Path _rrect(double x, double y, double w, double h, double r) => Path()
  ..addRRect(
    RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r)),
  );

Path _circle(double cx, double cy, double r) =>
    Path()..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));

final Map<String, List<_Shape>> _symbols = <String, List<_Shape>>{
  'tree': <_Shape>[
    _Shape(_svg('M0 0V-36M0 -17l8 -9'), _ln),
    _Shape(
      _svg(
        'M-9 -30c-12 0 -17 -13 -10 -21c-5 -11 3 -22 13 -20c3 -11 19 -11 22 0c10 -1 16 10 10 19c7 9 1 22 -11 22z',
      ),
      _sf,
    ),
  ],
  'pine': <_Shape>[
    _Shape(_svg('M0 0V-13'), _ln),
    _Shape(
      _svg(
        'M0 -75Q-4 -62 -11 -54Q-7 -52.5 -5 -54Q-8 -42 -15 -34Q-11 -32.5 -8 -34Q-11 -22 -19 -14Q0 -9 19 -14Q11 -22 8 -34Q11 -32.5 15 -34Q8 -42 5 -54Q7 -52.5 11 -54Q4 -62 0 -75Z',
      ),
      _sf,
    ),
  ],
  'bush': <_Shape>[
    _Shape(
      _svg(
        'M-17 0q-6 -8 0 -10q-2 -8 6 -8q1 -8 8 -6q5 -7 10 0q7 -2 7 6q7 1 4 9q4 4 -1 9z',
      ),
      _sf,
    ),
    _Shape(_svg('M-6 0q1 -8 -3 -12M3 0q0 -9 2 -14M11 0q0 -6 5 -9'), _ln),
  ],
  'rock': <_Shape>[
    _Shape(_svg('M-22 0q0 -10 8 -15q8 -9 17 -5q9 1 12 10q6 4 6 10z'), _sf),
    _Shape(_svg('M-5 -21q5 4 2 9q-2 4 -6 5'), _ln),
    _Shape(_svg('M15 0q1 -8 8 -9q9 0 10 9z'), _sf),
  ],
  'grass': <_Shape>[
    _Shape(
      _svg(
        'M0 0q-1 -6 -6 -10M0 0q1 -7 0 -13M0 0q1 -6 6 -10M-3 0q-3 -4 -9 -5M3 0q3 -4 9 -5',
      ),
      _ln,
    ),
  ],
};

final List<_Shape> _puffShape = <_Shape>[
  _Shape(
    _svg(
      'M-15 6c-8 0 -9 -10 -2 -11c-2 -9 9 -13 13 -6c4 -7 15 -4 13 5c7 0 8 12 -1 12z',
    ),
    _sf,
  ),
];
final List<_Shape> _cloudShape = <_Shape>[
  _Shape(
    _svg(
      'M-34 8H32c11 0 12 -15 1 -16c0 -12 -16 -16 -22 -7c-7 -10 -24 -6 -24 6c-11 -2 -15 15 -4 17z',
    ),
    _sf,
  ),
];

// Tank, drawn in its own coordinates (origin is set by _Sim.ox / _Sim.oy).
final List<_Shape> _barrelShapes = <_Shape>[
  _Shape(_svg('M156 57.5L226 55V61.5L156 66Z'), _sf, 3.9),
  _Shape(_rrect(222, 52.5, 20, 11, 3), _sf, 3.9),
];
final List<_Shape> _flashShapes = <_Shape>[
  _Shape(
    _svg('M0 -5Q10 -17 17 -9Q31 -15 46 0Q31 15 17 9Q10 17 0 5Z'),
    _sf,
    3.9,
  ),
  _Shape(
    _svg('M54 0H72M44 -17l13 -9M44 17l13 9M23 -22l4 -13M23 22l4 13'),
    _ln,
    3.9,
  ),
];
final List<_Shape> _upperShapes = <_Shape>[
  _Shape(_svg('M54 65H76'), _ln, 6),
  _Shape(_svg('M121 35V44'), _ln, 3.9),
  _Shape(_circle(121, 33.5, 3.4), _inkFill),
  _Shape(_svg('M101 38.5H119'), _ln, 4.6),
  _Shape(_rrect(98, 41, 24, 12, 3), _sf, 3.9),
  _Shape(_svg('M72 76V66Q72 51 88 51H137Q150 51 152 76Z'), _sf, 3.9),
  _Shape(_svg('M91 52V75'), _ln, 3.9),
  _Shape(_circle(81, 63.5, 9.5), _inkFill),
  _Shape(_circle(83.5, 61, 2.2), _paperFill),
  _Shape(_rrect(149, 56, 11, 13, 3), _sf, 3.9),
];
final List<_Shape> _hullShapes = <_Shape>[
  _Shape(
    _svg('M33 94L47 79H171L184 92Q185.5 97 180 97H37Q31 97 33 94Z'),
    _sf,
    3.9,
  ),
  _Shape(_svg('M45 86H177'), _ln, 2.4),
];

// ---------------------------------------------------------------------------
// Simulation
// ---------------------------------------------------------------------------

class _Prop {
  _Prop(this.px, this.py, this.sc, this.amp, this.shapes);
  final double px, py, sc, amp;
  final List<_Shape> shapes;
}

class _Blade {
  _Blade(this.path, this.px, this.py, this.ph);
  final Path path;
  final double px, py, ph;
}

class _Puff {
  double born = -9,
      life = 1,
      x = 0,
      y = 0,
      vx = 0,
      vy = 0,
      s0 = 1,
      s1 = 1,
      o = 1;
}

class _Pebble {
  double born = -9, x = 0, y = 0, vx = 0, vy = 0;
  bool hidden = true;
}

class _Sim {
  _Sim({required this.speed, required double fireEvery})
    : _fireEvery = fireEvery {
    nextFire = fireEvery > 0 ? 3 : double.infinity;
    v = speed;
    _build();
  }

  // Settings
  double speed;
  double _fireEvery;
  static const double scale = 1; // tank size
  static const double scene = 1.35; // scenery size
  static const double w = 3000; // length of one terrain loop
  static const double base = 372; // y of flat ground
  static const double tankX = 300; // tank stays at the centre
  static const double ox = 110, oy = 126.7;
  static const double half = 46 * scale;
  static const double fw = 1200, mw = 1600, sw = 1000, gw = 1400;
  static const List<double> wheelX = <double>[69, 95, 121, 147];

  // Hills, valleys and small bumps: [start, width, height]
  static const List<List<double>> bumps = <List<double>>[
    <double>[330, 560, 80],
    <double>[760, 400, 42],
    <double>[1090, 64, 8],
    <double>[1170, 64, 8],
    <double>[1250, 64, 8],
    <double>[1420, 460, -36],
    <double>[1900, 640, 96],
    <double>[2330, 380, 46],
    <double>[2740, 80, 11],
  ];
  // Scenery: [x, kind, scale]
  static const List<List<Object>> items = <List<Object>>[
    <Object>[90.0, 'grass', 1.0],
    <Object>[190.0, 'tree', 1.0],
    <Object>[300.0, 'bush', 1.0],
    <Object>[470.0, 'grass', 0.9],
    <Object>[612.0, 'rock', 0.9],
    <Object>[700.0, 'pine', 0.85],
    <Object>[900.0, 'bush', 1.0],
    <Object>[1010.0, 'grass', 1.0],
    <Object>[1130.0, 'pine', 1.0],
    <Object>[1230.0, 'rock', 0.8],
    <Object>[1330.0, 'bush', 0.9],
    <Object>[1500.0, 'grass', 1.0],
    <Object>[1650.0, 'tree', 0.9],
    <Object>[1760.0, 'grass', 1.0],
    <Object>[1850.0, 'rock', 0.8],
    <Object>[2060.0, 'bush', 0.9],
    <Object>[2222.0, 'pine', 0.8],
    <Object>[2420.0, 'grass', 0.9],
    <Object>[2560.0, 'rock', 1.0],
    <Object>[2680.0, 'tree', 1.05],
    <Object>[2790.0, 'bush', 1.0],
    <Object>[2900.0, 'grass', 1.0],
  ];
  static const Map<String, double> sway = <String, double>{
    'grass': 16,
    'bush': 7,
    'tree': 3.5,
    'pine': 2.5,
    'rock': 0,
  };

  // Static geometry
  late final Path groundPath, underPath, farPath, midPath, fgPath;
  final List<_Prop> props = <_Prop>[];
  final List<_Blade> blades = <_Blade>[];
  static const List<List<double>> clouds = <List<double>>[
    <double>[140, 150, 1],
    <double>[500, 208, 0.7],
    <double>[810, 128, 0.85],
  ];

  // State
  double t = 0, dist = 0, v = 165, hv = 0, ha = 0, hav = 0, ba = 0, bav = 0;
  double kick = 0, kv = 0, cam = 0, fireT = -99, nextFire = 3;
  double? hy, last;
  double s = 0, rel = 0, recoil = 0, ft = -99, spin = 0;
  double tDust = 0, tPeb = 0, tExh = 0;
  bool still = false;
  Offset? shotPos, shotDir;
  final List<double> wheelD = <double>[0, 0, 0, 0];
  final List<_Puff> puffs = List<_Puff>.generate(22, (_) => _Puff());
  final List<_Pebble> pebbles = List<_Pebble>.generate(14, (_) => _Pebble());
  int _np = 0, _nb = 0;

  int _seed = 7;
  double rnd() {
    _seed = (_seed * 16807) % 2147483647;
    return _seed / 2147483647;
  }

  void setFireEvery(double value) {
    if (value == _fireEvery) return;
    _fireEvery = value;
    nextFire = value > 0 ? t + value : double.infinity;
  }

  static double ground(double x) {
    x = ((x % w) + w) % w;
    const double k = 2 * math.pi / w;
    double h = 5 * math.sin(k * 3 * x) + 3 * math.sin(k * 8 * x + 1.3);
    for (final List<double> b in bumps) {
      final double u = (x - b[0]) / b[1];
      if (u > 0 && u < 1) h += b[2] * 0.5 * (1 - math.cos(2 * math.pi * u));
    }
    return h;
  }

  static double gy(double x) => base - ground(x);
  static double fgy(double x) {
    final double a = 2 * math.pi * x / gw;
    return 9 * math.sin(a * 2) + 5 * math.sin(a * 5 + 2);
  }

  void _build() {
    // Ground line, filled below so layers behind are hidden by hills
    groundPath = Path()..moveTo(-340, base + 420);
    for (double x = -340; x <= w + 340; x += 3) {
      groundPath.lineTo(x, gy(x));
    }
    groundPath
      ..lineTo(w + 340, base + 420)
      ..close();

    // Pebbles and soil marks under the surface
    underPath = Path();
    for (int i = 0; i < 120; i++) {
      final double ux = rnd() * w;
      final double depth = 12 + math.pow(rnd(), 1.6).toDouble() * 150;
      final double len = 5 + rnd() * 9;
      final bool round = rnd() < 0.3;
      for (final double px in <double>[ux, ux - w, ux + w]) {
        if (px < -340 || px > w + 340) continue;
        final double py = gy(px) + depth;
        if (round) {
          underPath.addOval(
            Rect.fromCenter(
              center: Offset(px, py),
              width: len,
              height: len * 0.6,
            ),
          );
        } else {
          underPath
            ..moveTo(px - len, py)
            ..quadraticBezierTo(px, py - 3, px + len, py);
        }
      }
    }

    // Scenery, repeated at both ends so the loop has no seam
    for (final List<Object> it in items) {
      final double ix = it[0] as double;
      final String kind = it[1] as String;
      final double sc = it[2] as double;
      for (final double px in <double>[ix, ix - w, ix + w]) {
        if (px < -340 || px > w + 340) continue;
        props.add(
          _Prop(px, gy(px) + 1, sc * scene, sway[kind]!, _symbols[kind]!),
        );
      }
    }

    // Distant rolling mountains
    const List<List<double>> peaks = <List<double>>[
      <double>[0, 20],
      <double>[60, 20],
      <double>[150, 100],
      <double>[260, 40],
      <double>[380, 150],
      <double>[520, 30],
      <double>[640, 120],
      <double>[760, 50],
      <double>[880, 110],
      <double>[1020, 20],
      <double>[1140, 20],
      <double>[1200, 20],
    ];
    farPath = Path()..moveTo(peaks[0][0], -peaks[0][1]);
    for (int i = 1; i < peaks.length - 1; i++) {
      final List<double> p = peaks[i], n = peaks[i + 1];
      farPath.quadraticBezierTo(
        p[0],
        -p[1],
        (p[0] + n[0]) / 2,
        -(p[1] + n[1]) / 2,
      );
    }
    farPath.lineTo(1200, -20);

    // Middle layer of low hills
    midPath = Path()..moveTo(0, 420);
    for (double x = 0; x <= mw * 2; x += 8) {
      final double a = 2 * math.pi * x / mw;
      midPath.lineTo(
        x,
        -(30 + 20 * math.sin(a * 2 + 1) + 10 * math.sin(a * 5)),
      );
    }
    midPath
      ..lineTo(mw * 2, 420)
      ..close();

    // Foreground bank with tall grass
    fgPath = Path()..moveTo(0, 200);
    for (double x = 0; x <= gw + 700; x += 8) {
      fgPath.lineTo(x, fgy(x));
    }
    fgPath
      ..lineTo(gw + 700, 200)
      ..close();
    const List<double> bladeX = <double>[70, 330, 560, 820, 1010, 1260];
    for (int bi = 0; bi < bladeX.length; bi++) {
      final int count = 5 + (bi % 3);
      final Path bd = Path();
      for (int j = 0; j < count; j++) {
        final double off = j - (count - 1) / 2;
        final double lean = off * 9 + (rnd() - 0.5) * 6;
        final double hgt = 26 + rnd() * 26;
        bd
          ..moveTo(off * 3, 0)
          ..quadraticBezierTo(
            off * 3 + lean * 0.2,
            -hgt * 0.6,
            off * 3 + lean,
            -hgt,
          );
      }
      for (final double px in <double>[bladeX[bi], bladeX[bi] + gw]) {
        if (px > gw + 700) continue;
        blades.add(_Blade(bd, px, fgy(px) + 1, bi * 1.7));
      }
    }
  }

  // Where the hull wants to sit: best-fit line through the ground under the track.
  // Returns Offset(restY, restAngle).
  Offset _rest(double at) {
    const int n = 9;
    double sy = 0, sxy = 0, sxx = 0;
    for (int j = 0; j < n; j++) {
      final double o = (j / (n - 1) * 2 - 1) * half * 1.25;
      final double y = gy(at + o);
      sy += y;
      sxy += o * y;
      sxx += o * o;
    }
    return Offset(sy / n, math.atan(sxy / sxx));
  }

  /// Tank drawing coordinates -> world coordinates.
  Offset toWorld(double lx, double ly) {
    final double c = math.cos(ha), n = math.sin(ha);
    final double dx = (lx - ox) * scale, dy = (ly - oy) * scale;
    return Offset(s + kick + dx * c - dy * n, hy! + dx * n + dy * c);
  }

  void _puff(
    double x,
    double y,
    double vx,
    double vy,
    double s0,
    double s1,
    double life,
    double o,
  ) {
    final _Puff p = puffs[_np++ % puffs.length];
    p
      ..born = t
      ..x = x
      ..y = y
      ..vx = vx
      ..vy = vy
      ..s0 = s0
      ..s1 = s1
      ..life = life
      ..o = o;
  }

  /// One still frame, used when the system asks for reduced motion.
  void freeze() {
    still = true;
    dist = 240;
    hy = null;
    last = null;
    step(0);
  }

  void step(double time) {
    t = time;
    final double dt = last == null
        ? 0.0
        : math.min(0.05, math.max(0.0, t - last!));
    last = t;

    // Speed: slower on climbs, faster downhill
    final Offset r0 = _rest(dist % w);
    final double vT = (speed * (1 + 0.9 * math.tan(r0.dy)))
        .clamp(speed * 0.6, speed * 1.3)
        .toDouble();
    v += (vT - v) * (1 - math.exp(-dt * 1.8));
    dist += v * dt;
    s = dist % w;
    final Offset r = _rest(s);
    if (hy == null) {
      hy = r.dx;
      ha = r.dy;
      ba = r.dy * 0.3;
      cam = (base - r.dx) * 0.78;
    }

    // Fire
    bool fired = false;
    if (!still && t >= nextFire) {
      fireT = t;
      nextFire = t + _fireEvery;
      hav -= 1.0;
      kv -= 150;
      fired = true;
    }
    ft = t - fireT;
    recoil = ft < 0
        ? 0.0
        : 16 * (ft < 0.05 ? ft / 0.05 : math.exp(-(ft - 0.05) * 5));

    // Suspension: hull is sprung, so it lags, rocks and settles; the gun is stabilised
    for (int k = 0; k < 3; k++) {
      final double h = dt / 3;
      hv += (260 * (r.dx - hy!) - 16 * hv) * h;
      hy = hy! + hv * h;
      hav += (140 * (r.dy - ha) - 10 * hav) * h;
      ha += hav * h;
      kv += (-120 * kick - 14 * kv) * h;
      kick += kv * h;
      bav += (60 * (r.dy * 0.3 - ba) - 11 * bav) * h;
      ba += bav * h;
    }
    rel = (ba - ha).clamp(-0.3, 0.17).toDouble();

    // Each road wheel follows the ground on its own, within suspension travel
    final double ca = math.cos(ha);
    for (int i = 0; i < wheelX.length; i++) {
      final Offset p = toWorld(wheelX[i], 125);
      final double want = ((gy(p.dx) - p.dy) / (scale * ca))
          .clamp(-6.0, 7.0)
          .toDouble();
      wheelD[i] += (want - wheelD[i]) * (dt > 0 ? 1 - math.exp(-dt * 30) : 1.0);
    }
    spin = dist / (11 * scale);

    // Camera follows part of the climb
    cam +=
        ((base - hy!) * 0.78 - cam) * (dt > 0 ? 1 - math.exp(-dt * 3.5) : 1.0);

    // Muzzle position and direction, for the smoke and shell
    final double bc = math.cos(rel), bn = math.sin(rel);
    final Offset mw0 = toWorld(
      155 + (89 - recoil) * bc + 4 * bn,
      62 + (89 - recoil) * bn - 4 * bc,
    );
    final double aim = ha + rel - 0.035;
    if (fired) {
      shotPos = Offset(mw0.dx + tankX - s, mw0.dy + cam);
      shotDir = Offset(math.cos(aim), math.sin(aim));
      for (int k = 0; k < 5; k++) {
        final double sa = aim + (rnd() - 0.5) * 1.1, sv = 70 + rnd() * 230;
        _puff(
          mw0.dx + 10,
          mw0.dy,
          sv * math.cos(sa) + v * 0.55,
          sv * math.sin(sa) - 12,
          0.5,
          1.4 + rnd() * 1.1,
          0.9 + rnd() * 0.6,
          1,
        );
      }
    }

    if (still) return;

    // Dust and pebbles thrown off the back of the track, and exhaust
    final Offset rear = toWorld(50, 124);
    if (t - tDust > 0.3 * speed / v) {
      tDust = t;
      _puff(
        rear.dx,
        rear.dy - 8,
        -18 - rnd() * 20,
        -16 - rnd() * 16,
        0.5,
        1.5 + rnd() * 0.5,
        1.2,
        1,
      );
    }
    if (t - tExh > 0.42) {
      tExh = t;
      final Offset ex = toWorld(38, 82);
      _puff(ex.dx, ex.dy, -26, -44, 0.25, 0.85, 0.9, 0.7);
    }
    if (t - tPeb > 0.07) {
      tPeb = t;
      final _Pebble b = pebbles[_nb++ % pebbles.length];
      b
        ..born = t
        ..x = rear.dx + 4
        ..y = rear.dy - 3
        ..vx = -(50 + rnd() * 120)
        ..vy = -(80 + rnd() * 150);
    }
    for (final _Puff p in puffs) {
      if ((t - p.born) / p.life >= 1) continue;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vx *= math.exp(-dt * 2.6);
      p.vy *= math.exp(-dt * 1.4);
    }
    for (final _Pebble b in pebbles) {
      if (t - b.born > 0.7) {
        b.hidden = true;
        continue;
      }
      b.vy += 640 * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.hidden = b.y > gy(b.x);
    }
  }

  /// Keeps particles attached across the loop seam.
  double wrapX(double x) => x - s > w / 2 ? x - w : (s - x > w / 2 ? x + w : x);
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _TankPainter extends CustomPainter {
  _TankPainter(this.sim, this.ink, this.paper, Listenable repaint)
    : super(repaint: repaint);

  final _Sim sim;
  final Color ink;
  final Color paper;

  static Color _a(Color c, double o) =>
      c.withAlpha((o.clamp(0.0, 1.0) * 255).round());

  Paint _st(double width, [double o = 1]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = _a(ink, o);

  Paint _fl(Color c, [double o = 1]) => Paint()
    ..style = PaintingStyle.fill
    ..color = _a(c, o);

  void _draw(Canvas canvas, List<_Shape> shapes, [double o = 1]) {
    for (final _Shape sh in shapes) {
      switch (sh.kind) {
        case _ln:
          canvas.drawPath(sh.path, _st(sh.sw, o));
          break;
        case _sf:
          canvas.drawPath(sh.path, _fl(paper, o));
          canvas.drawPath(sh.path, _st(sh.sw, o));
          break;
        case _inkFill:
          canvas.drawPath(sh.path, _fl(ink, o));
          break;
        default:
          canvas.drawPath(sh.path, _fl(paper, o));
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (sim.hy == null) sim.step(0);
    final double t = sim.t,
        s = sim.s,
        cam = sim.cam,
        dist = sim.dist,
        ft = sim.ft;
    final double hy = sim.hy!;
    const Offset centre = Offset(300, 300);

    canvas.save();
    canvas.scale(size.shortestSide / 600);
    canvas.drawCircle(centre, 268, _fl(paper));

    canvas.save();
    canvas.clipPath(
      Path()..addOval(Rect.fromCircle(center: centre, radius: 268)),
    );

    // A shot shakes the camera briefly
    final double sh = ft >= 0 && ft < 0.6 ? math.exp(-ft * 10) : 0.0;
    canvas.translate(
      math.sin(ft * 70) * 3.5 * sh,
      math.cos(ft * 55) * 2.5 * sh,
    );

    // Clouds
    canvas.save();
    canvas.translate(-((dist * 0.05 + t * 5) % _Sim.sw), cam * 0.12);
    for (final List<double> cl in _Sim.clouds) {
      for (int c = 0; c < 2; c++) {
        canvas.save();
        canvas.translate(cl[0] + c * _Sim.sw, cl[1]);
        canvas.scale(cl[2]);
        _draw(canvas, _cloudShape, 0.45);
        canvas.restore();
      }
    }
    canvas.restore();

    // Distant mountains
    canvas.save();
    canvas.translate(-((dist * 0.2) % _Sim.fw), _Sim.base + 2 + cam * 0.3);
    for (int c = 0; c < 3; c++) {
      canvas.save();
      canvas.translate(c * _Sim.fw, 0);
      canvas.scale(1, 1.25);
      canvas.drawPath(sim.farPath, _st(2.1, 0.3));
      canvas.restore();
    }
    canvas.restore();

    // Middle hills
    canvas.save();
    canvas.translate(-((dist * 0.45) % _Sim.mw), _Sim.base + 6 + cam * 0.55);
    canvas.drawPath(sim.midPath, _fl(paper));
    canvas.drawPath(sim.midPath, _st(2.1, 0.5));
    canvas.restore();

    // World: ground, scenery, particles, tank
    canvas.save();
    canvas.translate(_Sim.tankX - s, cam);
    canvas.drawPath(sim.groundPath, _fl(paper));
    canvas.drawPath(sim.groundPath, _st(2.3));
    canvas.drawPath(sim.underPath, _st(2.1, 0.5));

    for (final _Prop p in sim.props) {
      final double dx = s - p.px;
      if (dx < -420 || dx > 420) continue;
      // Plants sway in the breeze, and whip as the tank goes by
      double rot = 0;
      if (p.amp > 0 && !sim.still) {
        final double pass = dx + 70;
        rot = math.sin(t * 1.4 + p.px) * p.amp * 0.12;
        if (pass > 0) {
          rot += p.amp * math.exp(-pass / 150) * math.sin(pass / 16);
        }
      }
      canvas.save();
      canvas.translate(p.px, p.py);
      canvas.rotate(rot * math.pi / 180);
      canvas.scale(p.sc);
      _draw(canvas, p.shapes);
      canvas.restore();
    }

    for (final _Puff p in sim.puffs) {
      final double a = (t - p.born) / p.life;
      if (a >= 1 || a < 0) continue;
      canvas.save();
      canvas.translate(sim.wrapX(p.x), p.y);
      canvas.scale(p.s0 + (p.s1 - p.s0) * math.sqrt(a));
      _draw(canvas, _puffShape, p.o * (1 - a * a));
      canvas.restore();
    }

    _paintTank(canvas, hy, ft);

    for (final _Pebble b in sim.pebbles) {
      if (b.hidden) continue;
      canvas.drawCircle(Offset(sim.wrapX(b.x), b.y), 1.7, _fl(ink));
    }
    canvas.restore();

    // Shell
    if (sim.shotPos != null && ft >= 0 && ft < 0.5) {
      final double far = 46 + 1150 * ft;
      canvas.drawLine(
        sim.shotPos! + sim.shotDir! * far,
        sim.shotPos! + sim.shotDir! * (far - 34),
        _st(3.4),
      );
    }

    // Speed lines
    if (!sim.still) {
      const List<List<double>> lines = <List<double>>[
        <double>[118, 168, -104, 0],
        <double>[96, 134, -84, 0.33],
        <double>[124, 154, -64, 0.66],
      ];
      for (final List<double> l in lines) {
        final double p = (t - l[3]) % 1;
        final double o = p < 0.3 ? 0.9 * p / 0.3 : 0.9 * (1 - (p - 0.3) / 0.7);
        final double tx = 10 - 40 * p, y = hy + cam + l[2];
        canvas.drawLine(
          Offset(l[0] + tx, y),
          Offset(l[1] + tx, y),
          _st(2.1, o),
        );
      }
    }

    // Foreground bank and tall grass
    canvas.save();
    canvas.translate(-((dist * 1.7) % _Sim.gw), 522 + cam * 1.4);
    canvas.drawPath(sim.fgPath, _fl(paper));
    canvas.drawPath(sim.fgPath, _st(3));
    for (final _Blade b in sim.blades) {
      canvas.save();
      canvas.translate(b.px, b.py);
      canvas.rotate(math.sin(t * 2.1 + b.ph) * 5 * math.pi / 180);
      canvas.drawPath(b.path, _st(3));
      canvas.restore();
    }
    canvas.restore();

    canvas.restore(); // clip

    // Rings and the rotating progress arc
    canvas.drawCircle(centre, 268, _st(3));
    canvas.drawCircle(centre, 286, _st(2, 0.16));
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: 286),
      t * 2 * math.pi / 2.6,
      300 / 286,
      false,
      _st(4),
    );

    canvas.restore();
  }

  void _paintTank(Canvas canvas, double hy, double ft) {
    canvas.save();
    canvas.translate(
      sim.s + sim.kick,
      hy + (sim.still ? 0 : math.sin(sim.t * 7) * 0.35) + 1,
    );
    canvas.rotate(sim.ha);
    canvas.scale(_Sim.scale);
    canvas.translate(-_Sim.ox, -_Sim.oy);

    // Barrel pivots at the mantlet and slides back on recoil
    canvas.save();
    canvas.translate(155, 62);
    canvas.rotate(sim.rel);
    canvas.translate(-155 - sim.recoil, -62);
    _draw(canvas, _barrelShapes);
    if (ft >= 0 && ft < 0.16) {
      canvas.save();
      canvas.translate(243, 58);
      canvas.scale(0.55 + ft * 6);
      _draw(canvas, _flashShapes, 1 - ft / 0.16);
      canvas.restore();
    }
    canvas.restore();

    _draw(canvas, _upperShapes);

    // Track wraps the sprocket, the idler and the bottoms of the road wheels
    final double y1 = 110 + sim.wheelD[0], y2 = 110 + sim.wheelD[1];
    final double y3 = 110 + sim.wheelD[2], y4 = 110 + sim.wheelD[3];
    final List<Offset> pts = <Offset>[
      const Offset(46, 97),
      const Offset(110, 97),
      const Offset(174, 97),
      const Offset(179.5, 98.8),
      const Offset(181, 105.6),
      const Offset(177, 112),
      Offset(157.6, y4 + 10.6),
      Offset(147, y4 + 15),
      Offset(121, y3 + 15),
      Offset(95, y2 + 15),
      Offset(69, y1 + 15),
      Offset(58.4, y1 + 10.6),
      const Offset(42.6, 112.3),
      const Offset(38.4, 106),
      const Offset(40, 99.2),
    ];
    final int n = pts.length;
    final Path track = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < n; i++) {
      final Offset p0 = pts[(i + n - 1) % n],
          p1 = pts[i],
          p2 = pts[(i + 1) % n],
          p3 = pts[(i + 2) % n];
      const double k = 0.13;
      track.cubicTo(
        p1.dx + (p2.dx - p0.dx) * k,
        p1.dy + (p2.dy - p0.dy) * k,
        p2.dx - (p3.dx - p1.dx) * k,
        p2.dy - (p3.dy - p1.dy) * k,
        p2.dx,
        p2.dy,
      );
    }
    track.close();
    canvas.drawPath(track, _fl(paper));
    canvas.drawPath(track, _st(3.9));

    // Tread marks that travel round the track
    final Paint dot = _fl(paper);
    final double start = (sim.dist / _Sim.scale) % 7;
    for (final metric in track.computeMetrics()) {
      for (double o = start; o < metric.length; o += 7) {
        final tangent = metric.getTangentForOffset(o);
        if (tangent != null) canvas.drawCircle(tangent.position, 0.7, dot);
      }
    }

    // Sprocket and idler
    _paintSmallWheel(canvas, 48, 104.5, 4.2);
    _paintSmallWheel(canvas, 171.5, 104, 4.6);

    // Road wheels
    for (int i = 0; i < _Sim.wheelX.length; i++) {
      canvas.save();
      canvas.translate(_Sim.wheelX[i], 110 + sim.wheelD[i]);
      canvas.rotate(sim.spin);
      canvas.drawCircle(Offset.zero, 9.4, _fl(paper));
      canvas.drawCircle(Offset.zero, 9.4, _st(3.2));
      canvas.drawCircle(Offset.zero, 4.2, _fl(ink));
      canvas.drawCircle(Offset.zero, 1.2, _fl(paper));
      for (int k = 0; k < 3; k++) {
        canvas.drawCircle(
          Offset(6.5 * math.cos(k * 2.094), 6.5 * math.sin(k * 2.094)),
          0.8,
          _fl(ink),
        );
      }
      canvas.restore();
    }

    _draw(canvas, _hullShapes);
    canvas.restore();
  }

  void _paintSmallWheel(Canvas canvas, double cx, double cy, double r) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(sim.spin * 2);
    canvas.drawCircle(Offset.zero, r, _fl(paper));
    canvas.drawCircle(Offset.zero, r, _st(2.6));
    canvas.drawCircle(Offset(r * 0.45, 0), 0.9, _fl(ink));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TankPainter oldDelegate) =>
      oldDelegate.sim != sim ||
      oldDelegate.ink != ink ||
      oldDelegate.paper != paper;
}
