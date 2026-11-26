import 'package:flutter/material.dart';

/// Texte sur une ligne qui défile doucement de droite à gauche quand il est
/// trop long pour la place disponible (et reste immobile sinon).
class TexteDefilant extends StatefulWidget {
  const TexteDefilant(
    this.texte, {
    super.key,
    this.style,
    this.actif = true,
    this.textAlign = TextAlign.start,
  });

  final String texte;
  final TextStyle? style;

  /// Si false, le texte est simplement coupé avec « … ».
  final bool actif;

  final TextAlign textAlign;

  @override
  State<TexteDefilant> createState() => _TexteDefilantState();
}

class _TexteDefilantState extends State<TexteDefilant>
    with SingleTickerProviderStateMixin {
  static const double _vitesse = 35; // pixels par seconde
  static const double _ecart = 48; // espace entre la fin et la reprise du texte
  static const Duration _pause = Duration(milliseconds: 1500);

  late final AnimationController _animation = AnimationController(vsync: this);
  double? _distance;

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  static Duration _dureeTotale(double distance) =>
      _pause + Duration(milliseconds: (distance / _vitesse * 1000).round());

  /// Règle l'animation pour faire défiler [distance] pixels, puis recommencer
  /// (juste après l'affichage, jamais pendant la construction).
  void _regler(double distance) {
    if (_distance == distance) return;
    _distance = distance;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _distance != distance) return;
      _animation
        ..duration = _dureeTotale(distance)
        ..repeat();
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(widget.style);
    return LayoutBuilder(
      builder: (context, contraintes) {
        final mesure = TextPainter(
          text: TextSpan(text: widget.texte, style: style),
          maxLines: 1,
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final largeur = mesure.width;

        if (!widget.actif || largeur <= contraintes.maxWidth) {
          if (_distance != null) {
            _distance = null;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _distance == null) _animation.stop();
            });
          }
          return Text(
            widget.texte,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: widget.textAlign,
          );
        }

        final distance = largeur + _ecart;
        _regler(distance);
        final partPause =
            _pause.inMilliseconds / _dureeTotale(distance).inMilliseconds;

        return SizedBox(
          height: mesure.height,
          child: ShaderMask(
            // Fondu sur les bords pour un défilement plus doux.
            shaderCallback: (r) => const LinearGradient(
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0, 0.04, 0.92, 1],
            ).createShader(r),
            blendMode: BlendMode.dstIn,
            child: ClipRect(
              child: AnimatedBuilder(
                animation: _animation,
                builder: (context, enfant) {
                  final t = _animation.value;
                  final avance = t < partPause
                      ? 0.0
                      : (t - partPause) / (1 - partPause);
                  return Transform.translate(
                    offset: Offset(-avance * distance, 0),
                    child: enfant,
                  );
                },
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: double.infinity,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.texte,
                        style: style,
                        maxLines: 1,
                        softWrap: false,
                      ),
                      const SizedBox(width: _ecart),
                      Text(
                        widget.texte,
                        style: style,
                        maxLines: 1,
                        softWrap: false,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
