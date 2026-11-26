/// Une chanson trouvée sur le téléphone.
class Chanson {
  const Chanson({
    required this.id,
    required this.titre,
    required this.artiste,
    required this.album,
    required this.albumId,
    required this.duree,
    required this.ajout,
    required this.uri,
    this.annee,
  });

  /// Construit une chanson à partir de ce que renvoie le code Android.
  factory Chanson.depuisMap(Map<Object?, Object?> m) => Chanson(
    id: (m['id'] as num).toInt(),
    titre: _texte(m['titre'], 'Titre inconnu'),
    artiste: _texte(m['artiste'], 'Artiste inconnu'),
    album: _texte(m['album'], 'Album inconnu'),
    albumId: (m['albumId'] as num? ?? 0).toInt(),
    duree: Duration(milliseconds: (m['duree'] as num? ?? 0).toInt()),
    ajout: DateTime.fromMillisecondsSinceEpoch(
      (m['ajout'] as num? ?? 0).toInt() * 1000,
    ),
    uri: m['uri'] as String,
    // L'année écrite dans le titre (« … 2025 A NATIO »), sinon dans le nom
    // du fichier, sinon celle des infos du fichier.
    annee:
        anneeDansTexte(_texte(m['titre'], '')) ??
        anneeDansTexte(m['fichier'] as String? ?? '') ??
        _annee(m['annee']),
  );

  final int id;
  final String titre;
  final String artiste;
  final String album;
  final int albumId;
  final Duration duree;
  final DateTime ajout;
  final String uri;

  /// Année du titre (ex. 2025), ou null si le fichier n'en indique pas.
  final int? annee;

  /// La même chanson avec d'autres infos (modifiées dans l'application).
  Chanson avec({String? titre, String? artiste, String? album}) => Chanson(
    id: id,
    titre: titre ?? this.titre,
    artiste: artiste ?? this.artiste,
    album: album ?? this.album,
    albumId: albumId,
    duree: duree,
    ajout: ajout,
    uri: uri,
    annee: annee,
  );

  /// Android peut renvoyer 0, une date (20250314) ou une année : on ne garde
  /// qu'une année plausible.
  static int? _annee(Object? valeur) {
    var a = (valeur as num?)?.toInt() ?? 0;
    if (a > 9999) a = int.tryParse('$a'.substring(0, 4)) ?? 0;
    return a >= 1900 && a <= 2100 ? a : null;
  }

  static String _texte(Object? valeur, String parDefaut) {
    final texte = (valeur as String?)?.trim() ?? '';
    return texte.isEmpty || texte == '<unknown>' ? parDefaut : texte;
  }
}

/// Clé de tri alphabétique : sans majuscules ni accents, et sans les
/// guillemets, tirets ou espaces du début (« "Ki mara…" » se range à K).
String cleTri(String texte) {
  const accents = {
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'á': 'a',
    'ã': 'a',
    'å': 'a',
    'ç': 'c',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'î': 'i',
    'ï': 'i',
    'í': 'i',
    'ì': 'i',
    'ô': 'o',
    'ö': 'o',
    'ó': 'o',
    'ò': 'o',
    'õ': 'o',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ú': 'u',
    'ÿ': 'y',
    'ñ': 'n',
    'œ': 'oe',
    'æ': 'ae',
  };
  final sansAccents = StringBuffer();
  for (final lettre in texte.toLowerCase().split('')) {
    sansAccents.write(accents[lettre] ?? lettre);
  }
  return sansAccents.toString().replaceFirst(RegExp(r'^[^a-z0-9]+'), '');
}

/// 3:07, ou 1:02:45 au-delà d'une heure.
String formaterDuree(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

/// Une playlist automatique : les titres d'une même année ([annee] null :
/// « Autres », les titres sans année).
class GroupeAnnee {
  const GroupeAnnee(this.annee, this.chansons);

  final int? annee;
  final List<Chanson> chansons;

  String get nom => annee?.toString() ?? 'Autres';
}

/// Range les titres par année, de la plus récente à la plus ancienne ;
/// « Autres » (sans année) vient en dernier. Dans chaque année, les titres
/// sont triés de A à Z.
List<GroupeAnnee> grouperParAnnee(Iterable<Chanson> chansons) {
  final groupes = <int?, List<Chanson>>{};
  for (final c in chansons) {
    groupes.putIfAbsent(c.annee, () => []).add(c);
  }
  final annees = groupes.keys.toList()
    ..sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      return b.compareTo(a);
    });
  return [
    for (final a in annees)
      GroupeAnnee(
        a,
        groupes[a]!..sort((x, y) => cleTri(x.titre).compareTo(cleTri(y.titre))),
      ),
  ];
}

/// Retrouve une année écrite dans un titre ou un nom de fichier :
/// « … 2025 A NATIO », « LE 15-03-2025 », « AUD-20261115-WA0058 »,
/// « 02062025 », « 07-10-14 », « 2O26 » (lettre O), « N22026 ».
/// Renvoie null s'il n'y en a pas.
int? anneeDansTexte(String texte) {
  if (texte.isEmpty) return null;
  final maxi = DateTime.now().year + 1;
  int? valide(int a) => a >= 1950 && a <= maxi ? a : null;

  // « 2O26 » : la lettre O tapée à la place du zéro.
  final t = texte.replaceAllMapped(
    RegExp(r'(?<![0-9A-Za-z])2[Oo]([0-9]{2})(?![0-9])'),
    (m) => '20${m[1]}',
  );

  // Une année seule (2025), ou suivie du mois et du jour (20261115).
  for (final m in RegExp(
    r'(?<![0-9])((?:19|20)[0-9]{2})(?:(?:0[1-9]|1[0-2])(?:0[1-9]|[12][0-9]|3[01]))?(?![0-9])',
  ).allMatches(t)) {
    final a = valide(int.parse(m[1]!));
    if (a != null) return a;
  }
  // Jour, mois et année collés : 02062025.
  for (final m in RegExp(
    r'(?<![0-9])(?:0[1-9]|[12][0-9]|3[01])(?:0[1-9]|1[0-2])((?:19|20)[0-9]{2})(?![0-9])',
  ).allMatches(t)) {
    final a = valide(int.parse(m[1]!));
    if (a != null) return a;
  }
  // Collée derrière un numéro : « N22026 ».
  for (final m in RegExp(
    r'N°?[0-9]((?:19|20)[0-9]{2})(?![0-9])',
    caseSensitive: false,
  ).allMatches(t)) {
    final a = valide(int.parse(m[1]!));
    if (a != null) return a;
  }
  // Date courte : 07-10-14 → 2014.
  for (final m in RegExp(
    r'(?<![0-9])[0-3]?[0-9][-/.][01]?[0-9][-/.]([0-9]{2})(?![0-9])',
  ).allMatches(t)) {
    final aa = int.parse(m[1]!);
    final a = valide(aa + 2000 <= maxi ? 2000 + aa : 1900 + aa);
    if (a != null) return a;
  }
  return null;
}
