import 'package:flutter/material.dart';

import '../theme.dart';

/// Dégradé doré-rosé de la signature.
const LinearGradient degradeOr = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color(0xFFFFF1C9),
    Color(0xFFF2C46D),
    Color(0xFFE79A5B),
    Color(0xFFFF8FB8),
  ],
  stops: [0, 0.35, 0.7, 1],
);

/// Fond de l'application, fixe : une nuit violette éclairée de quelques
/// lueurs douces, les sillons d'un vinyle en filigrane et la signature
/// « KANIGUY PIGNON ».
class FondCka extends StatelessWidget {
  const FondCka({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: RepaintBoundary(child: CustomPaint(painter: _FondPainter())),
        ),
        const Positioned.fill(child: IgnorePointer(child: _Signature())),
        child,
      ],
    );
  }
}

class _FondPainter extends CustomPainter {
  const _FondPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final cote = size.shortestSide;

    // Nuit profonde, un peu plus claire en haut.
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1B1030), fond, Color(0xFF07060C)],
          stops: [0, 0.5, 1],
        ).createShader(rect),
    );

    // Trois lueurs douces, toujours à la même place.
    void lueur(Offset centre, double rayon, Color couleur, double force) {
      canvas.drawCircle(
        centre,
        rayon,
        Paint()
          ..shader = RadialGradient(
            colors: [
              couleur.withValues(alpha: force),
              couleur.withValues(alpha: force * 0.3),
              couleur.withValues(alpha: 0),
            ],
            stops: const [0, 0.5, 1],
          ).createShader(Rect.fromCircle(center: centre, radius: rayon)),
      );
    }

    lueur(
      Offset(size.width * 0.05, size.height * 0.08),
      cote * 0.95,
      violet,
      0.32,
    );
    lueur(Offset(size.width * 1.0, size.height * 0.42), cote * 0.8, rose, 0.22);
    lueur(
      Offset(size.width * 0.15, size.height * 0.95),
      cote * 0.9,
      const Color(0xFF2E4BD8),
      0.2,
    );

    // Sillons d'un vinyle, très discrets, en bas à droite.
    final disque = Offset(size.width * 0.95, size.height * 0.86);
    final sillon = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 16; i++) {
      sillon.color = Colors.white.withValues(alpha: i.isEven ? 0.045 : 0.025);
      canvas.drawCircle(disque, cote * (0.18 + i * 0.035), sillon);
    }
  }

  @override
  bool shouldRepaint(_FondPainter old) => false;
}

/// « KANIGUY PIGNON » en grandes lettres dorées et espacées, encadré de deux
/// fins traits, au milieu du fond.
class _Signature extends StatelessWidget {
  const _Signature();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: const Alignment(0, 0.18),
      child: Opacity(
        opacity: 0.2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: FittedBox(
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => degradeOr.createShader(r),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'KANIGUY',
                    style: TextStyle(
                      fontSize: 64,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 16,
                      height: 1,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 14),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Trait(),
                      SizedBox(width: 14),
                      Text(
                        'PIGNON',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 14,
                          height: 1,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 6),
                      _Trait(),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Trait extends StatelessWidget {
  const _Trait();

  @override
  Widget build(BuildContext context) =>
      Container(width: 70, height: 1.6, color: Colors.white);
}

/// Petite signature dorée, pour l'en-tête.
class SignatureKaniguy extends StatelessWidget {
  const SignatureKaniguy({super.key, this.taille = 10.5});

  final double taille;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => degradeOr.createShader(r),
      child: Text(
        'KANIGUY  PIGNON',
        style: TextStyle(
          fontSize: taille,
          fontWeight: FontWeight.w600,
          letterSpacing: 3.2,
          color: Colors.white,
          shadows: const [Shadow(color: Color(0x66F2C46D), blurRadius: 8)],
        ),
      ),
    );
  }
}
