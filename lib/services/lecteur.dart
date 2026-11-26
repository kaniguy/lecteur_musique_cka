import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modeles/chanson.dart';
import 'bibliotheque.dart';
import 'gestionnaire_audio.dart';
import 'memoire.dart';

/// Le lecteur : file d'attente, lecture, aléatoire, répétition, favoris,
/// minuterie d'arrêt et reprise là où on s'était arrêté. La lecture continue
/// en arrière-plan, avec les commandes dans la notification et sur l'écran
/// verrouillé.
class Lecteur extends ChangeNotifier {
  Lecteur(this.bibliotheque, this.audio) {
    // Le bouton ♥ de la notification.
    audio.estFavori = (id) => _favoris.contains(int.tryParse(id));
    audio.basculerFavori = (id) {
      final c = _parId[int.tryParse(id)];
      if (c != null) basculerFavori(c);
    };
    _abonnements = [
      player.currentIndexStream.listen((_) {
        _compterEcoute();
        _sauverPosition();
        notifyListeners();
      }),
      player.playingStream.listen((joue) {
        _compterEcoute();
        if (!joue) _sauverPosition();
        notifyListeners();
      }),
      player.positionStream.listen((_) => _sauverPositionDeTempsEnTemps()),
      player.shuffleModeEnabledStream.listen((_) => notifyListeners()),
      player.loopModeStream.listen((_) => notifyListeners()),
    ];
    memoire.addListener(notifyListeners);
    _memoirePrete = memoire.charger();
    _chargerFavoris();
  }

  static const Duration saut = Duration(seconds: 15);

  final Bibliotheque bibliotheque;
  final Memoire memoire = Memoire();
  final GestionnaireAudio audio;

  AudioPlayer get player => audio.player;
  late final List<StreamSubscription<Object?>> _abonnements;

  late final Future<void> _memoirePrete;

  /// Toute la musique du téléphone (avec les infos modifiées appliquées).
  List<Chanson> _toutes = [];
  List<Chanson> _brutes = [];
  Map<int, Chanson> _parId = {};
  List<Chanson> _file = [];
  Set<int> _favoris = {};
  Timer? _minuterie;
  int? _derniereEcoute;
  bool _enReprise = false;
  DateTime _derniereSauvegarde = DateTime(2000);

  /// Heure à laquelle la musique s'arrêtera, si la minuterie est active.
  DateTime? finMinuterie;

  List<Chanson> get file => List.unmodifiable(_file);

  /// Toute la musique du téléphone. La liste change d'identité à chaque
  /// modification (pratique pour mettre un tri en cache).
  List<Chanson> get toutes => _toutes;

  Chanson? get enCours {
    final i = player.currentIndex;
    return i != null && i < _file.length ? _file[i] : null;
  }

  bool get joue => player.playing;
  bool get aleatoire => player.shuffleModeEnabled;
  LoopMode get repetition => player.loopMode;

  /// Indices de la file dans l'ordre où ils seront joués.
  List<int> get ordre => player.effectiveIndices;

  /// Retrouve des chansons du téléphone à partir de leurs identifiants
  /// (celles qui ont été supprimées entre-temps sont ignorées).
  List<Chanson> chansons(Iterable<int> ids) => [
    for (final id in ids) ?_parId[id],
  ];

  /// À appeler quand la musique du téléphone est chargée : reprend alors la
  /// dernière écoute (sans lancer la musique).
  Future<void> bibliothequeChargee(List<Chanson> toutes) async {
    await _memoirePrete;
    _brutes = toutes;
    _appliquerModifs();
    if (_file.isEmpty) await _reprendre();
  }

  /// Recalcule la bibliothèque et la file avec les infos modifiées.
  void _appliquerModifs() {
    _toutes = [for (final c in _brutes) memoire.appliquer(c)];
    _parId = {for (final c in _toutes) c.id: c};
    if (_file.isNotEmpty) {
      _file = [for (final c in _file) _parId[c.id] ?? c];
      audio.changerFile([for (final c in _file) _element(c)]);
    }
    notifyListeners();
  }

  // ---------- Moments marqués ----------

  /// Marque le moment en cours de la chanson en cours.
  Future<Marque?> marquerMaintenant() async {
    final c = enCours;
    if (c == null) return null;
    return memoire.marquer(c.id, player.position);
  }

  /// Va au moment marqué : dans la chanson en cours, ou lance [c] à ce moment.
  /// [liste] : la liste d'où vient la chanson, pour enchaîner ensuite.
  Future<void> allerAuMoment(
    Chanson c,
    Duration position, {
    List<Chanson>? liste,
  }) async {
    if (enCours?.id == c.id) {
      await player.seek(position);
      if (!joue) unawaited(player.play());
      return;
    }
    final file = liste != null && liste.any((x) => x.id == c.id) ? liste : [c];
    await lire(
      file,
      index: file.indexWhere((x) => x.id == c.id),
      position: position,
    );
  }

  // ---------- Actions sur plusieurs titres ----------

  /// Change le titre, l'artiste ou l'album (dans l'application seulement).
  Future<void> modifierInfos(
    Iterable<Chanson> chansons, {
    String? titre,
    String? artiste,
    String? album,
  }) async {
    await memoire.modifier(
      chansons.map((c) => c.id),
      titre: titre,
      artiste: artiste,
      album: album,
    );
    _appliquerModifs();
  }

  Future<void> retablirInfos(Iterable<Chanson> chansons) async {
    await memoire.retablir(chansons.map((c) => c.id));
    _appliquerModifs();
  }

  /// Efface ces chansons du téléphone. Renvoie le nombre effacé.
  Future<int> supprimerDuTelephone(Iterable<Chanson> chansons) async {
    final effaces = await bibliotheque.supprimer(chansons.map((c) => c.id));
    if (effaces.isEmpty) return 0;
    // Retire les titres effacés de la file, en partant de la fin.
    for (var i = _file.length - 1; i >= 0; i--) {
      if (!effaces.contains(_file[i].id)) continue;
      _file.removeAt(i);
      try {
        await player.removeAudioSourceAt(i);
      } catch (e) {
        _trace('Retrait de la file impossible : $e');
      }
    }
    audio.changerFile([for (final c in _file) _element(c)]);
    _brutes = [
      for (final c in _brutes)
        if (!effaces.contains(c.id)) c,
    ];
    _favoris.removeAll(effaces);
    await _sauverFavoris();
    await memoire.oublier(effaces);
    _appliquerModifs();
    unawaited(_sauverFile());
    return effaces.length;
  }

  /// Met (ou retire) toutes ces chansons en favori.
  Future<void> definirFavoris(Iterable<Chanson> chansons, bool favori) async {
    for (final c in chansons) {
      favori ? _favoris.add(c.id) : _favoris.remove(c.id);
    }
    notifyListeners();
    await _sauverFavoris();
  }

  Future<void> ajouterPlusieursALaFile(List<Chanson> chansons) async {
    if (chansons.isEmpty) return;
    if (_file.isEmpty) return lire(chansons);
    _file.addAll(chansons);
    await player.addAudioSources([for (final c in chansons) _source(c)]);
    audio.changerFile([for (final c in _file) _element(c)]);
    notifyListeners();
    await _sauverFile();
  }

  Future<void> lirePlusieursEnsuite(List<Chanson> chansons) async {
    if (chansons.isEmpty) return;
    if (_file.isEmpty) return lire(chansons);
    final i = (player.currentIndex ?? -1) + 1;
    _file.insertAll(i, chansons);
    await player.insertAudioSources(i, [for (final c in chansons) _source(c)]);
    audio.changerFile([for (final c in _file) _element(c)]);
    notifyListeners();
    await _sauverFile();
  }

  // ---------- Lecture ----------

  Future<void> lire(
    List<Chanson> chansons, {
    int index = 0,
    bool aleatoire = false,
    Duration? position,
  }) async {
    if (chansons.isEmpty) return;
    _file = List.of(chansons);
    _derniereEcoute = null;
    final depart = aleatoire ? Random().nextInt(_file.length) : index;
    _trace('lire ${_file.length} titres, départ $depart');
    // La pochette de la première chanson, pour la notification (sans jamais
    // bloquer la lecture si elle tarde).
    await bibliotheque
        .pochette(_file[depart])
        .timeout(const Duration(milliseconds: 800), onTimeout: () => null);
    _trace('pochette prête');
    try {
      await player.setShuffleModeEnabled(aleatoire);
      _trace('aléatoire réglé');
      audio.changerFile([for (final c in _file) _element(c)]);
      await player.setAudioSources(
        [for (final c in _file) _source(c)],
        initialIndex: depart,
        initialPosition: position,
        preload: false,
      );
      _trace('file chargée');
      if (aleatoire) await player.shuffle();
      notifyListeners();
      unawaited(_sauverFile());
      unawaited(player.play());
      _trace('lecture demandée');
    } catch (e, pile) {
      _trace('Lecture impossible : $e\n$pile');
    }
  }

  void _trace(String message) => debugPrint('[MusiqueCKA] $message');

  AudioSource _source(Chanson c) =>
      AudioSource.uri(Uri.parse(c.uri), tag: _element(c));

  /// Ce qu'Android affiche pour une chanson (notification, écran verrouillé).
  MediaItem _element(Chanson c) {
    final pochette = bibliotheque.pochetteConnue(c);
    return MediaItem(
      id: '${c.id}',
      title: c.titre,
      artist: c.artiste,
      album: c.album,
      duration: c.duree,
      artUri: pochette != null ? Uri.file(pochette) : null,
    );
  }

  Future<void> ajouterALaFile(Chanson c) async {
    if (_file.isEmpty) return lire([c]);
    _file.add(c);
    await player.addAudioSource(_source(c));
    audio.changerFile([for (final c in _file) _element(c)]);
    notifyListeners();
    await _sauverFile();
  }

  Future<void> lireEnsuite(Chanson c) async {
    if (_file.isEmpty) return lire([c]);
    final i = (player.currentIndex ?? -1) + 1;
    _file.insert(i, c);
    await player.insertAudioSource(i, _source(c));
    audio.changerFile([for (final c in _file) _element(c)]);
    notifyListeners();
    await _sauverFile();
  }

  void basculerLecture() {
    if (joue) {
      player.pause();
    } else {
      player.play();
    }
  }

  Future<void> suivant() async {
    if (player.hasNext) await player.seekToNext();
  }

  /// Revient au début du titre, ou au titre précédent si on y est déjà.
  Future<void> precedent() async {
    if (player.position > const Duration(seconds: 3) || !player.hasPrevious) {
      await player.seek(Duration.zero);
    } else {
      await player.seekToPrevious();
    }
  }

  /// Avance (ou recule si [vers] est négatif) dans le titre en cours.
  Future<void> sauter(Duration vers) async {
    final fin = player.duration ?? enCours?.duree ?? Duration.zero;
    var cible = player.position + vers;
    if (cible < Duration.zero) cible = Duration.zero;
    if (cible > fin) cible = fin;
    await player.seek(cible);
  }

  Future<void> allerA(int index) async {
    await player.seek(Duration.zero, index: index);
    if (!joue) unawaited(player.play());
  }

  Future<void> basculerAleatoire() async {
    final active = !aleatoire;
    if (active) await player.shuffle();
    await player.setShuffleModeEnabled(active);
  }

  /// Pas de répétition → toute la file → le titre en cours → …
  Future<void> changerRepetition() => player.setLoopMode(switch (repetition) {
    LoopMode.off => LoopMode.all,
    LoopMode.all => LoopMode.one,
    LoopMode.one => LoopMode.off,
  });

  // ---------- Écoutes ----------

  /// Compte une écoute quand un titre se met à jouer (une fois par titre).
  void _compterEcoute() {
    final c = enCours;
    if (c == null || !joue || c.id == _derniereEcoute) return;
    _derniereEcoute = c.id;
    memoire.enregistrerEcoute(c.id);
  }

  // ---------- Reprise de la dernière écoute ----------

  Future<void> _sauverFile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('reprise_file', [
      for (final c in _file) '${c.id}',
    ]);
    await _sauverPosition();
  }

  Future<void> _sauverPosition() async {
    final c = enCours;
    if (c == null || _enReprise) return;
    _derniereSauvegarde = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reprise_chanson', c.id);
    await prefs.setInt('reprise_position', player.position.inMilliseconds);
  }

  void _sauverPositionDeTempsEnTemps() {
    if (DateTime.now().difference(_derniereSauvegarde) >
        const Duration(seconds: 5)) {
      _sauverPosition();
    }
  }

  Future<void> _reprendre() async {
    final prefs = await SharedPreferences.getInstance();
    final file = chansons([
      for (final id in prefs.getStringList('reprise_file') ?? <String>[])
        ?int.tryParse(id),
    ]);
    if (file.isEmpty || _file.isNotEmpty) return;
    final idEnCours = prefs.getInt('reprise_chanson');
    final index = max(0, file.indexWhere((c) => c.id == idEnCours));
    final position = Duration(
      milliseconds: prefs.getInt('reprise_position') ?? 0,
    );

    _file = file;
    _enReprise = true;
    await bibliotheque.pochette(file[index]);
    audio.changerFile([for (final c in file) _element(c)]);
    try {
      await player.setAudioSources(
        [for (final c in file) _source(c)],
        initialIndex: index,
        initialPosition: position < file[index].duree
            ? position
            : Duration.zero,
      );
    } on PlayerException catch (e) {
      debugPrint('Reprise impossible : ${e.message}');
    }
    _enReprise = false;
    notifyListeners();
  }

  // ---------- Minuterie ----------

  /// Arrête la musique dans [duree] (null pour annuler).
  void programmerArret(Duration? duree) {
    _minuterie?.cancel();
    finMinuterie = duree == null ? null : DateTime.now().add(duree);
    if (duree != null) {
      _minuterie = Timer(duree, () {
        player.pause();
        finMinuterie = null;
        notifyListeners();
      });
    }
    notifyListeners();
  }

  // ---------- Favoris ----------

  bool estFavori(Chanson c) => _favoris.contains(c.id);

  Future<void> basculerFavori(Chanson c) async {
    if (!_favoris.remove(c.id)) _favoris.add(c.id);
    notifyListeners();
    await _sauverFavoris();
  }

  Future<void> _sauverFavoris() async {
    audio.rafraichir();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoris', [for (final id in _favoris) '$id']);
  }

  Future<void> _chargerFavoris() async {
    final prefs = await SharedPreferences.getInstance();
    _favoris = {
      for (final id in prefs.getStringList('favoris') ?? <String>[])
        ?int.tryParse(id),
    };
    notifyListeners();
    audio.rafraichir();
  }

  @override
  void dispose() {
    _minuterie?.cancel();
    for (final a in _abonnements) {
      a.cancel();
    }
    memoire
      ..removeListener(notifyListeners)
      ..dispose();
    player.dispose();
    super.dispose();
  }
}

/// Donne accès au lecteur partout dans l'application.
class LecteurScope extends InheritedNotifier<Lecteur> {
  const LecteurScope({
    super.key,
    required Lecteur lecteur,
    required super.child,
  }) : super(notifier: lecteur);

  /// Le lecteur, en reconstruisant le widget quand il change.
  static Lecteur of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LecteurScope>()!.notifier!;

  /// Le lecteur, sans s'abonner à ses changements.
  static Lecteur lire(BuildContext context) =>
      context.getInheritedWidgetOfExactType<LecteurScope>()!.notifier!;
}
