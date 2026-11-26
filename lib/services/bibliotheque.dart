import 'package:flutter/services.dart';

import '../modeles/chanson.dart';

/// Accès à la musique du téléphone (code Android, canal « cka/musique »).
class Bibliotheque {
  static const MethodChannel _canal = MethodChannel('cka/musique');

  final Map<int, Future<String?>> _enCours = {};
  final Map<int, String?> _connues = {};

  Future<bool> aPermission() async =>
      await _canal.invokeMethod<bool>('aPermission') ?? false;

  Future<bool> demanderPermission() async =>
      await _canal.invokeMethod<bool>('demanderPermission') ?? false;

  Future<List<Chanson>> chansons() async {
    final liste =
        await _canal.invokeListMethod<Map<Object?, Object?>>('chansons') ?? [];
    return [for (final m in liste) Chanson.depuisMap(m)];
  }

  /// Chemin de la pochette de l'album de [c] (null s'il n'y en a pas).
  /// Chaque pochette n'est demandée qu'une fois.
  Future<String?> pochette(Chanson c) => _enCours.putIfAbsent(
    c.albumId,
    () => _canal
        .invokeMethod<String>('pochette', {
          'albumId': c.albumId,
          'chansonId': c.id,
        })
        .then((chemin) => _connues[c.albumId] = chemin)
        .catchError((Object _) => null),
  );

  /// Infos du fichier : nom, dossier, taille, format, débit, année, genre…
  Future<Map<String, Object?>> details(Chanson c) async {
    final infos = await _canal.invokeMapMethod<String, Object?>('details', {
      'id': c.id,
    });
    return infos ?? {};
  }

  /// Autorisation « Micro », nécessaire aux barres de décibels.
  Future<bool> aMicro() async =>
      await _canal.invokeMethod<bool>('aMicro') ?? false;

  Future<bool> demanderMicro() async =>
      await _canal.invokeMethod<bool>('demanderMicro') ?? false;

  /// Ouvre le menu de partage d'Android avec ces chansons.
  Future<bool> partager(Iterable<int> ids) async =>
      await _canal.invokeMethod<bool>('partager', {'ids': ids.toList()}) ??
      false;

  /// Efface ces chansons du téléphone (Android demande confirmation).
  /// Renvoie les identifiants vraiment effacés.
  Future<Set<int>> supprimer(Iterable<int> ids) async {
    final effaces = await _canal.invokeListMethod<num>('supprimer', {
      'ids': ids.toList(),
    });
    return {for (final id in effaces ?? <num>[]) id.toInt()};
  }

  /// Les fichiers en double (contenu identique), par groupes d'au moins 2.
  Future<List<List<FichierDouble>>> doublons() async {
    final groupes = await _canal.invokeListMethod<List<Object?>>('doublons');
    return [
      for (final g in groupes ?? <List<Object?>>[])
        [
          for (final f in g)
            FichierDouble.depuisMap(f! as Map<Object?, Object?>),
        ],
    ];
  }

  /// La pochette si elle est déjà chargée, sans attendre.
  String? pochetteConnue(Chanson c) => _connues[c.albumId];
}

/// Un fichier d'un groupe de doublons.
class FichierDouble {
  const FichierDouble({
    required this.id,
    required this.fichier,
    required this.dossier,
    required this.taille,
    required this.ajout,
  });

  factory FichierDouble.depuisMap(Map<Object?, Object?> m) => FichierDouble(
    id: (m['id'] as num).toInt(),
    fichier: m['fichier'] as String? ?? '',
    dossier: m['dossier'] as String? ?? '',
    taille: (m['taille'] as num? ?? 0).toInt(),
    ajout: DateTime.fromMillisecondsSinceEpoch(
      (m['ajout'] as num? ?? 0).toInt() * 1000,
    ),
  );

  final int id;

  /// Nom du fichier, par ex. « BALAFON DE … A TALERE-1.mp3 ».
  final String fichier;

  /// Dossier du fichier, par ex. « Xender/audio/ ».
  final String dossier;

  /// Taille en octets.
  final int taille;
  final DateTime ajout;

  /// Une copie faite par Android ou Xender : « titre-1.mp3 », « titre (2).mp3 ».
  bool get estCopie => RegExp(r'(-\d+|\s*\(\d+\))\.\w+$').hasMatch(fichier);
}
