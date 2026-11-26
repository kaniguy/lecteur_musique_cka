import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../services/lecteur.dart';
import '../theme.dart';

/// Barres qui montent et descendent selon le niveau sonore (en décibels)
/// de la musique en cours, des graves (à gauche) aux aigus (à droite).
///
/// Le son est mesuré par Android (canal « cka/analyseur ») : cela demande
/// l'autorisation « Micro », même si rien n'est enregistré.
class BarresDecibels extends StatefulWidget {
  const BarresDecibels({super.key, this.hauteur = 56});

  final double hauteur;

  @override
  State<BarresDecibels> createState() => _BarresDecibelsState();
}

class _BarresDecibelsState extends State<BarresDecibels>
    with SingleTickerProviderStateMixin {
  static const EventChannel _analyseur = EventChannel('cka/analyseur');
  static const int _nombre = 28;

  /// Niveaux affichés (lissés) et niveaux reçus d'Android.
  final ValueNotifier<List<double>> _affiches = ValueNotifier(
    List.filled(_nombre, 0),
  );
  List<double> _cibles = List.filled(_nombre, 0);

  late final Ticker _ticker = createTicker(_lisser);
  StreamSubscription<int?>? _session;
  StreamSubscription<Object?>? _mesures;
  bool? _autorise;
  int? _sessionEcoutee;

  @override
  void initState() {
    super.initState();
    _verifier();
  }

  Future<void> _verifier() async {
    final autorise = await LecteurScope.lire(context).bibliotheque.aMicro();
    if (!mounted) return;
    setState(() => _autorise = autorise);
    if (autorise) _demarrer();
  }

  Future<void> _autoriser() async {
    final autorise = await LecteurScope.lire(context).bibliotheque
        .demanderMicro();
    if (!mounted) return;
    setState(() => _autorise = autorise);
    if (autorise) _demarrer();
  }

  void _demarrer() {
    final player = LecteurScope.lire(context).player;
    _session = player.androidAudioSessionIdStream.listen(_ecouter);
    _ecouter(player.androidAudioSessionId);
    if (!_ticker.isActive) _ticker.start();
  }

  /// (Re)branche la mesure sur la session audio du lecteur.
  void _ecouter(int? session) {
    if (session == null || session == _sessionEcoutee) return;
    _sessionEcoutee = session;
    _mesures?.cancel();
    _mesures = _analyseur
        .receiveBroadcastStream(session)
        .listen(
          (niveaux) => _cibles = [
            for (final n in niveaux as List) (n as num).toDouble(),
          ],
          onError: (Object _) => _cibles = List.filled(_nombre, 0),
        );
  }

  /// À chaque image : les barres rejoignent doucement le niveau mesuré,
  /// et redescendent à zéro quand la musique est en pause.
  void _lisser(Duration _) {
    final joue = LecteurScope.lire(context).joue;
    final avant = _affiches.value;
    final apres = List<double>.generate(_nombre, (i) {
      final cible = joue && i < _cibles.length ? _cibles[i] : 0.0;
      final vitesse = cible > avant[i]
          ? 0.45
          : 0.12; // monte vite, descend doucement
      return avant[i] + (cible - avant[i]) * vitesse;
    });
    _affiches.value = apres;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _session?.cancel();
    _mesures?.cancel();
    _affiches.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_autorise == false) {
      return SizedBox(
        height: widget.hauteur,
        child: Center(
          child: TextButton.icon(
            onPressed: _autoriser,
            icon: const Icon(Icons.graphic_eq_rounded),
            label: const Text('Afficher les décibels'),
          ),
        ),
      );
    }
    return SizedBox(
      height: widget.hauteur,
      width: double.infinity,
      child: CustomPaint(painter: _BarresPainter(_affiches)),
    );
  }
}

class _BarresPainter extends CustomPainter {
  _BarresPainter(this.niveaux) : super(repaint: niveaux);

  final ValueNotifier<List<double>> niveaux;

  @override
  void paint(Canvas canvas, Size size) {
    final valeurs = niveaux.value;
    final n = valeurs.length;
    final pas = size.width / n;
    final largeur = pas * 0.58;
    final milieu = size.height * 0.72;
    final degrade = const LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: [violet, rose],
    ).createShader(Rect.fromLTWH(0, 0, size.width, milieu));
    final barre = Paint()..shader = degrade;
    final reflet = Paint()..color = rose.withValues(alpha: 0.18);

    for (var i = 0; i < n; i++) {
      final x = i * pas + (pas - largeur) / 2;
      final h = max(largeur, valeurs[i] * milieu);
      final rayon = Radius.circular(largeur / 2);
      // La barre, posée sur la ligne du milieu…
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, milieu - h, largeur, h),
          rayon,
        ),
        barre,
      );
      // … et son reflet, plus court et transparent, en dessous.
      final r = min(h * 0.35, size.height - milieu - 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, milieu + 2, largeur, r),
          rayon,
        ),
        reflet,
      );
    }
  }

  @override
  bool shouldRepaint(_BarresPainter old) => old.niveaux != niveaux;
}
