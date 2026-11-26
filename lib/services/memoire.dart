import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modeles/chanson.dart';

/// Une playlist créée par l'utilisateur : un nom et des identifiants de
/// chansons, dans l'ordre.
class Playlist {
  Playlist({required this.id, required this.nom, required this.chansons});

  factory Playlist.depuisJson(Map<String, Object?> json) => Playlist(
    id: json['id'] as String,
    nom: json['nom'] as String,
    chansons: [for (final id in json['chansons'] as List) (id as num).toInt()],
  );

  final String id;
  String nom;
  final List<int> chansons;

  Map<String, Object?> versJson() => {
    'id': id,
    'nom': nom,
    'chansons': chansons,
  };
}

/// Un moment marqué dans une chanson (par ex. 36:12, « le solo »).
class Marque {
  const Marque({required this.position, this.note = ''});

  factory Marque.depuisJson(Map<String, Object?> json) => Marque(
    position: Duration(milliseconds: (json['ms'] as num).toInt()),
    note: json['note'] as String? ?? '',
  );

  final Duration position;
  final String note;

  Map<String, Object?> versJson() => {
    'ms': position.inMilliseconds,
    if (note.isNotEmpty) 'note': note,
  };
}

/// Ce que l'application retient d'une fois sur l'autre : playlists,
/// nombre d'écoutes de chaque chanson et chansons écoutées récemment.
class Memoire extends ChangeNotifier {
  static const int tailleRecents = 50;

  final List<Playlist> _playlists = [];
  final Map<int, int> _ecoutes = {};
  final List<int> _recents = [];

  /// Infos modifiées dans l'application (titre, artiste, album), par chanson.
  final Map<int, Map<String, String>> _modifs = {};

  /// Moments marqués de chaque chanson, dans l'ordre du temps.
  final Map<int, List<Marque>> _marques = {};

  List<Playlist> get playlists => List.unmodifiable(_playlists);

  /// Chansons écoutées récemment, la plus récente en premier.
  List<int> get recents => List.unmodifiable(_recents);

  int ecoutes(int chansonId) => _ecoutes[chansonId] ?? 0;

  /// Les moments marqués de la chanson, du début à la fin.
  List<Marque> marques(int chansonId) =>
      List.unmodifiable(_marques[chansonId] ?? const <Marque>[]);

  bool aDesMarques(int chansonId) => _marques[chansonId]?.isNotEmpty ?? false;

  bool estModifiee(int chansonId) => _modifs.containsKey(chansonId);

  /// [c] avec les infos modifiées dans l'application, s'il y en a.
  Chanson appliquer(Chanson c) {
    final m = _modifs[c.id];
    if (m == null) return c;
    return c.avec(titre: m['titre'], artiste: m['artiste'], album: m['album']);
  }

  /// Identifiants des chansons les plus écoutées, de la plus écoutée à la moins.
  List<int> plusEcoutees({int nombre = 25}) {
    final ids = _ecoutes.keys.toList()
      ..sort((a, b) => _ecoutes[b]!.compareTo(_ecoutes[a]!));
    return ids.take(nombre).toList();
  }

  Playlist? playlist(String id) {
    for (final p in _playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> charger() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      _playlists
        ..clear()
        ..addAll([
          for (final p
              in jsonDecode(prefs.getString('playlists') ?? '[]') as List)
            Playlist.depuisJson((p as Map).cast<String, Object?>()),
        ]);
      final ecoutes = jsonDecode(prefs.getString('ecoutes') ?? '{}') as Map;
      _ecoutes
        ..clear()
        ..addAll({
          for (final MapEntry(:key, :value) in ecoutes.entries)
            int.parse(key as String): (value as num).toInt(),
        });
      final modifs =
          jsonDecode(prefs.getString('modifications') ?? '{}') as Map;
      _modifs
        ..clear()
        ..addAll({
          for (final MapEntry(:key, :value) in modifs.entries)
            int.parse(key as String): (value as Map).cast<String, String>(),
        });
      final marques = jsonDecode(prefs.getString('marques') ?? '{}') as Map;
      _marques
        ..clear()
        ..addAll({
          for (final MapEntry(:key, :value) in marques.entries)
            int.parse(key as String): [
              for (final m in value as List)
                Marque.depuisJson((m as Map).cast<String, Object?>()),
            ],
        });
    } on FormatException {
      // Données abîmées : on repart de zéro plutôt que de planter.
    }
    _recents
      ..clear()
      ..addAll([
        for (final id in prefs.getStringList('recents') ?? <String>[])
          ?int.tryParse(id),
      ]);
    notifyListeners();
  }

  // ---------- Écoutes ----------

  Future<void> enregistrerEcoute(int chansonId) async {
    _ecoutes[chansonId] = ecoutes(chansonId) + 1;
    _recents
      ..remove(chansonId)
      ..insert(0, chansonId);
    if (_recents.length > tailleRecents) _recents.removeLast();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ecoutes',
      jsonEncode({for (final e in _ecoutes.entries) '${e.key}': e.value}),
    );
    await prefs.setStringList('recents', [for (final id in _recents) '$id']);
  }

  // ---------- Moments marqués ----------

  /// Marque un moment. Un moment à moins d'une seconde d'un autre le remplace.
  Future<Marque> marquer(
    int chansonId,
    Duration position, {
    String note = '',
  }) async {
    final liste = _marques.putIfAbsent(chansonId, () => []);
    liste.removeWhere(
      (m) => (m.position - position).inMilliseconds.abs() < 1000,
    );
    final marque = Marque(position: position, note: note);
    liste
      ..add(marque)
      ..sort((a, b) => a.position.compareTo(b.position));
    await _sauverMarques();
    return marque;
  }

  Future<void> nommerMarque(int chansonId, Marque marque, String note) async {
    final liste = _marques[chansonId];
    final i = liste?.indexOf(marque) ?? -1;
    if (i < 0) return;
    liste![i] = Marque(position: marque.position, note: note.trim());
    await _sauverMarques();
  }

  Future<void> effacerMarque(int chansonId, Marque marque) async {
    final liste = _marques[chansonId];
    if (liste == null) return;
    liste.remove(marque);
    if (liste.isEmpty) _marques.remove(chansonId);
    await _sauverMarques();
  }

  Future<void> _sauverMarques() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'marques',
      jsonEncode({
        for (final e in _marques.entries)
          '${e.key}': [for (final m in e.value) m.versJson()],
      }),
    );
  }

  // ---------- Infos modifiées ----------

  /// Change les infos de ces chansons (null = ne pas changer ce champ).
  Future<void> modifier(
    Iterable<int> ids, {
    String? titre,
    String? artiste,
    String? album,
  }) async {
    for (final id in ids) {
      final m = _modifs.putIfAbsent(id, () => {});
      if (titre != null) m['titre'] = titre;
      if (artiste != null) m['artiste'] = artiste;
      if (album != null) m['album'] = album;
      if (m.isEmpty) _modifs.remove(id);
    }
    await _sauverModifs();
  }

  /// Rend à ces chansons les infos d'origine du fichier.
  Future<void> retablir(Iterable<int> ids) async {
    ids.forEach(_modifs.remove);
    await _sauverModifs();
  }

  Future<void> _sauverModifs() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'modifications',
      jsonEncode({for (final e in _modifs.entries) '${e.key}': e.value}),
    );
  }

  // ---------- Doublons ----------

  /// Fusionne des doublons : tout ce qui est retenu sur chaque copie (clé)
  /// passe à la chanson gardée (valeur). Écoutes additionnées, place dans les
  /// playlists et dans les récents, moments marqués, infos modifiées.
  /// Les copies sont ensuite à effacer avec [oublier].
  Future<void> fusionner(Map<int, int> copieVersGardee) async {
    int vers(int id) => copieVersGardee[id] ?? id;

    List<int> remplacer(List<int> ids) {
      final vus = <int>{};
      return [
        for (final id in ids)
          if (vus.add(vers(id))) vers(id),
      ];
    }

    for (final p in _playlists) {
      final nouvelles = remplacer(p.chansons);
      p.chansons
        ..clear()
        ..addAll(nouvelles);
    }
    final recents = remplacer(_recents);
    _recents
      ..clear()
      ..addAll(recents);
    for (final MapEntry(key: copie, value: gardee) in copieVersGardee.entries) {
      final n = _ecoutes.remove(copie);
      if (n != null) _ecoutes[gardee] = ecoutes(gardee) + n;
      final modif = _modifs.remove(copie);
      if (modif != null) _modifs.putIfAbsent(gardee, () => modif);
      final marques = _marques.remove(copie);
      if (marques != null) {
        final liste = _marques.putIfAbsent(gardee, () => []);
        for (final m in marques) {
          final proche = liste.any(
            (x) => (x.position - m.position).inMilliseconds.abs() < 1000,
          );
          if (!proche) liste.add(m);
        }
        liste.sort((a, b) => a.position.compareTo(b.position));
      }
    }
    await _sauverPlaylists();
    await _sauverModifs();
    await _sauverMarques();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ecoutes',
      jsonEncode({for (final e in _ecoutes.entries) '${e.key}': e.value}),
    );
    await prefs.setStringList('recents', [for (final id in _recents) '$id']);
  }

  /// Oublie tout ce qui concerne des chansons effacées du téléphone.
  Future<void> oublier(Set<int> ids) async {
    for (final p in _playlists) {
      p.chansons.removeWhere(ids.contains);
    }
    _recents.removeWhere(ids.contains);
    ids.forEach(_ecoutes.remove);
    ids.forEach(_modifs.remove);
    ids.forEach(_marques.remove);
    await _sauverPlaylists();
    await _sauverModifs();
    await _sauverMarques();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'ecoutes',
      jsonEncode({for (final e in _ecoutes.entries) '${e.key}': e.value}),
    );
    await prefs.setStringList('recents', [for (final id in _recents) '$id']);
  }

  // ---------- Playlists ----------

  Playlist creerPlaylist(String nom) {
    final p = Playlist(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nom: nom,
      chansons: [],
    );
    _playlists.add(p);
    _sauverPlaylists();
    return p;
  }

  void renommer(Playlist p, String nom) {
    p.nom = nom;
    _sauverPlaylists();
  }

  void supprimer(Playlist p) {
    _playlists.remove(p);
    _sauverPlaylists();
  }

  /// Ajoute la chanson à la fin de la playlist. Renvoie false si elle y était déjà.
  bool ajouter(Playlist p, int chansonId) {
    if (p.chansons.contains(chansonId)) return false;
    p.chansons.add(chansonId);
    _sauverPlaylists();
    return true;
  }

  /// Ajoute plusieurs chansons à la fin de la playlist. Renvoie le nombre
  /// de chansons vraiment ajoutées (celles déjà présentes sont ignorées).
  int ajouterPlusieurs(Playlist p, Iterable<int> ids) {
    var ajoutees = 0;
    for (final id in ids) {
      if (p.chansons.contains(id)) continue;
      p.chansons.add(id);
      ajoutees++;
    }
    if (ajoutees > 0) _sauverPlaylists();
    return ajoutees;
  }

  void retirer(Playlist p, int chansonId) {
    p.chansons.remove(chansonId);
    _sauverPlaylists();
  }

  void retirerPlusieurs(Playlist p, Set<int> ids) {
    p.chansons.removeWhere(ids.contains);
    _sauverPlaylists();
  }

  Future<void> _sauverPlaylists() async {
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'playlists',
      jsonEncode([for (final p in _playlists) p.versJson()]),
    );
  }
}
