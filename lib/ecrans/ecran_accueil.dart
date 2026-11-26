import 'package:flutter/material.dart';

import '../modeles/chanson.dart';
import '../services/lecteur.dart';
import '../services/selection.dart';
import '../services/tri.dart';
import '../theme.dart';
import '../widgets/actions_selection.dart';
import '../widgets/fond_cka.dart';
import '../widgets/mini_lecteur.dart';
import '../widgets/pochette.dart';
import '../widgets/tuile_chanson.dart';
import 'ecran_collection.dart';
import 'onglets_ecoutes.dart';

/// Clé où l'on garde le dernier tri choisi d'une ouverture à l'autre.
const _cleTri = 'tri';

/// Écran principal : autorisation, puis la bibliothèque en onglets.
class EcranAccueil extends StatefulWidget {
  const EcranAccueil({super.key});

  @override
  State<EcranAccueil> createState() => _EcranAccueilState();
}

class _EcranAccueilState extends State<EcranAccueil>
    with SingleTickerProviderStateMixin {
  bool? _autorise;
  bool _charge = false;
  Tri _tri = Tri.titreAZ;
  final Selection _selection = Selection();
  late final TabController _onglets = TabController(length: 6, vsync: this)
    // Changer d'onglet annule la sélection en cours.
    ..addListener(_selection.vider);

  // Le dernier tri calculé, pour ne pas retrier à chaque reconstruction.
  List<Chanson>? _sourceTri;
  Tri? _triCalcule;
  List<Chanson> _triCache = const [];

  @override
  void initState() {
    super.initState();
    _chargerTri();
    _demarrer();
  }

  /// Reprend le tri choisi la dernière fois.
  Future<void> _chargerTri() async {
    final tri = await lireTri(_cleTri);
    // « Ordre de la playlist » n'a pas de sens pour toute la bibliothèque.
    if (!mounted || tri == null || tri == Tri.ordrePlaylist) return;
    setState(() => _tri = tri);
  }

  Future<void> _choisirTri(Tri tri) async {
    setState(() => _tri = tri);
    await garderTri(_cleTri, tri);
  }

  @override
  void dispose() {
    _onglets.dispose();
    _selection.dispose();
    super.dispose();
  }

  Future<void> _demarrer() async {
    final bibliotheque = LecteurScope.lire(context).bibliotheque;
    final autorise = await bibliotheque.aPermission();
    if (!mounted) return;
    setState(() => _autorise = autorise);
    if (autorise) await _charger();
  }

  Future<void> _autoriser() async {
    final bibliotheque = LecteurScope.lire(context).bibliotheque;
    final autorise = await bibliotheque.demanderPermission();
    if (!mounted) return;
    setState(() => _autorise = autorise);
    if (autorise) await _charger();
  }

  Future<void> _charger() async {
    final lecteur = LecteurScope.lire(context);
    final chansons = await lecteur.bibliotheque.chansons();
    if (!mounted) return;
    // Reprend la dernière chanson écoutée, là où elle s'était arrêtée.
    final reprise = lecteur.bibliothequeChargee(chansons);
    setState(() => _charge = true);
    await reprise;
  }

  List<Chanson> _triees(List<Chanson> toutes) {
    if (identical(toutes, _sourceTri) && _tri == _triCalcule) return _triCache;
    _sourceTri = toutes;
    _triCalcule = _tri;
    final liste = trier(toutes, _tri);
    return _triCache = liste;
  }

  @override
  Widget build(BuildContext context) {
    final autorise = _autorise;
    final lecteur = LecteurScope.of(context);
    final chansons = lecteur.toutes;
    if (autorise == false) return _EcranAutorisation(onAutoriser: _autoriser);
    if (autorise == null || !_charge) {
      return const FondCka(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final triees = _triees(chansons);
    final onglets = TabBar(
      controller: _onglets,
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: const [
        Tab(text: 'Titres'),
        Tab(text: 'Récents'),
        Tab(text: 'Playlists'),
        Tab(text: 'Favoris'),
        Tab(text: 'Albums'),
        Tab(text: 'Artistes'),
      ],
    );
    final barreNormale = AppBar(
      titleSpacing: 16,
      title: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Image.asset('assets/logo.png', width: 34, height: 34),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Musique CKA',
                style: TextStyle(
                  fontFamily: policeTitre,
                  fontSize: 24,
                  letterSpacing: 0.6,
                  height: 1.1,
                ),
              ),
              SignatureKaniguy(),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Rechercher',
          icon: const Icon(Icons.search_rounded),
          onPressed: () =>
              showSearch(context: context, delegate: _Recherche(chansons)),
        ),
        MenuTri(tri: _tri, onChoisi: _choisirTri),
      ],
      bottom: onglets,
    );

    return SelectionScope(
      selection: _selection,
      child: FondCka(
        child: ListenableBuilder(
          listenable: _selection,
          builder: (context, corps) => PopScope(
            // Le bouton retour annule d'abord la sélection.
            canPop: !_selection.active,
            onPopInvokedWithResult: (fait, _) {
              if (!fait) _selection.vider();
            },
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: _selection.active
                  ? BarreSelection(selection: _selection, bottom: onglets)
                  : barreNormale,
              body: corps,
              bottomNavigationBar: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                transitionBuilder: (enfant, animation) => SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(animation),
                  child: FadeTransition(opacity: animation, child: enfant),
                ),
                child: _selection.active
                    ? BarreActionsSelection(
                        key: const ValueKey('actions'),
                        selection: _selection,
                      )
                    : const MiniLecteur(key: ValueKey('mini')),
              ),
            ),
          ),
          child: chansons.isEmpty
              ? const _Vide(
                  icone: Icons.library_music_outlined,
                  texte: 'Aucune musique trouvée sur le téléphone',
                )
              : TabBarView(
                  controller: _onglets,
                  children: [
                    _OngletTitres(chansons: triees, onActualiser: _charger),
                    const OngletRecents(),
                    const OngletPlaylists(),
                    _OngletFavoris(chansons: triees),
                    _OngletAlbums(chansons: chansons),
                    _OngletArtistes(chansons: chansons),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EcranAutorisation extends StatelessWidget {
  const _EcranAutorisation({required this.onAutoriser});

  final VoidCallback onAutoriser;

  @override
  Widget build(BuildContext context) {
    return FondCka(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(36),
                  child: Image.asset('assets/logo.png', width: 140),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Musique CKA',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Pour écouter vos musiques, autorisez l\'application '
                  'à accéder aux fichiers audio du téléphone.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 15),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: onAutoriser,
                    icon: const Icon(Icons.lock_open_rounded),
                    label: const Text(
                      'Autoriser l\'accès',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OngletTitres extends StatefulWidget {
  const _OngletTitres({required this.chansons, required this.onActualiser});

  final List<Chanson> chansons;
  final Future<void> Function() onActualiser;

  @override
  State<_OngletTitres> createState() => _OngletTitresState();
}

class _OngletTitresState extends State<_OngletTitres> {
  /// Hauteur fixe d'une ligne : permet de calculer où se trouve un titre.
  static const double _hauteurLigne = 72;

  final ScrollController _defilement = ScrollController();

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  /// Fait défiler la liste jusqu'au titre en cours, placé au milieu de l'écran.
  void _allerAuTitreEnCours(int index) {
    if (!_defilement.hasClients) return;
    final position = _defilement.position;
    final cible =
        index * _hauteurLigne -
        (position.viewportDimension - _hauteurLigne) / 2;
    _defilement.animateTo(
      cible.clamp(0.0, position.maxScrollExtent),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.lire(context);
    final chansons = widget.chansons;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          // Deux grands blocs de couleur : on lance la musique d'un geste.
          child: Row(
            children: [
              Expanded(
                child: _Bloc(
                  icone: Icons.shuffle_rounded,
                  texte: 'Aléatoire',
                  detail: '${chansons.length} titres',
                  degrade: true,
                  onTap: () => lecteur.lire(chansons, aleatoire: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Bloc(
                  icone: Icons.play_arrow_rounded,
                  texte: 'Tout lire',
                  detail: 'Dans l\'ordre',
                  onTap: () => lecteur.lire(chansons),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              // Une barre de défilement qu'on peut attraper pour parcourir
              // vite toute la liste de A à Z.
              RefreshIndicator(
                onRefresh: widget.onActualiser,
                child: Scrollbar(
                  controller: _defilement,
                  interactive: true,
                  thickness: 8,
                  radius: const Radius.circular(8),
                  child: ListView.builder(
                    controller: _defilement,
                    itemExtent: _hauteurLigne,
                    itemCount: chansons.length,
                    itemBuilder: (context, i) => TuileChanson(
                      chanson: chansons[i],
                      liste: chansons,
                      onTap: () => lecteur.lire(chansons, index: i),
                    ),
                  ),
                ),
              ),
              // Petit bouton « aller au titre en cours » (en lecture ou en pause).
              Positioned(
                right: 18,
                bottom: 12,
                child: Builder(
                  builder: (context) {
                    final enCours = LecteurScope.of(context).enCours;
                    final index = enCours == null
                        ? -1
                        : chansons.indexWhere((c) => c.id == enCours.id);
                    return AnimatedScale(
                      scale: index < 0 ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: FloatingActionButton.small(
                        heroTag: 'allerAuTitre',
                        tooltip: 'Aller au titre en cours',
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        onPressed: index < 0
                            ? null
                            : () => _allerAuTitreEnCours(index),
                        child: const Icon(Icons.my_location_rounded),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OngletFavoris extends StatelessWidget {
  const _OngletFavoris({required this.chansons});

  final List<Chanson> chansons;

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final favoris = [
      for (final c in chansons)
        if (lecteur.estFavori(c)) c,
    ];
    if (favoris.isEmpty) {
      return const _Vide(
        icone: Icons.favorite_border_rounded,
        texte: 'Pas encore de favoris.\nTouchez ♥ sur une chanson pour l\'ajouter.',
      );
    }
    return ListView.builder(
      itemCount: favoris.length,
      itemBuilder: (context, i) => TuileChanson(
        chanson: favoris[i],
        liste: favoris,
        onTap: () => lecteur.lire(favoris, index: i),
      ),
    );
  }
}

class _OngletAlbums extends StatelessWidget {
  const _OngletAlbums({required this.chansons});

  final List<Chanson> chansons;

  @override
  Widget build(BuildContext context) {
    final albums = <int, List<Chanson>>{};
    for (final c in chansons) {
      albums.putIfAbsent(c.albumId, () => []).add(c);
    }
    final liste = albums.values.toList()
      ..sort((a, b) => cleTri(a.first.album).compareTo(cleTri(b.first.album)));

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisSpacing: 18,
        crossAxisSpacing: 16,
        childAspectRatio: 0.74,
      ),
      itemCount: liste.length,
      itemBuilder: (context, i) {
        final titres = liste[i];
        final premier = titres.first;
        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _ouvrir(context, premier.album, premier.artiste, titres),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black54,
                              blurRadius: 16,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Pochette(chanson: premier, rayon: 18),
                      ),
                    ),
                    // Bouton rond pour lire l'album tout de suite.
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Material(
                        type: MaterialType.transparency,
                        child: Ink(
                          width: 44,
                          height: 44,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: degradeCka,
                          ),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () =>
                                LecteurScope.lire(context).lire(titres),
                            child: const Tooltip(
                              message: "Lire l'album",
                              child: Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                premier.album,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                '${premier.artiste} · ${titres.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OngletArtistes extends StatelessWidget {
  const _OngletArtistes({required this.chansons});

  final List<Chanson> chansons;

  @override
  Widget build(BuildContext context) {
    final artistes = <String, List<Chanson>>{};
    for (final c in chansons) {
      artistes.putIfAbsent(c.artiste, () => []).add(c);
    }
    final noms = artistes.keys.toList()
      ..sort((a, b) => cleTri(a).compareTo(cleTri(b)));

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: noms.length,
      itemBuilder: (context, i) {
        final titres = artistes[noms[i]]!;
        return ListTile(
          // Photo ronde entourée d'un anneau au dégradé de la marque.
          leading: Container(
            padding: const EdgeInsets.all(2.5),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: degradeCka,
            ),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: fond,
              ),
              child: Pochette(chanson: titres.first, taille: 46, rayon: 23),
            ),
          ),
          title: Text(
            noms[i],
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${titres.length} titre${titres.length > 1 ? 's' : ''}',
            style: const TextStyle(color: Colors.white60),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Colors.white38,
          ),
          onTap: () => _ouvrir(context, noms[i], 'Artiste', titres),
        );
      },
    );
  }
}

void _ouvrir(
  BuildContext context,
  String titre,
  String sousTitre,
  List<Chanson> chansons,
) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => EcranCollection(
        titre: titre,
        sousTitre: sousTitre,
        chansons: chansons,
      ),
    ),
  );
}

/// Grand bloc arrondi pour lancer la lecture (en dégradé ou en verre).
class _Bloc extends StatelessWidget {
  const _Bloc({
    required this.icone,
    required this.texte,
    required this.detail,
    required this.onTap,
    this.degrade = false,
  });

  final IconData icone;
  final String texte;
  final String detail;
  final VoidCallback onTap;
  final bool degrade;

  @override
  Widget build(BuildContext context) {
    final rayon = BorderRadius.circular(22);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: degrade ? degradeCka : null,
        color: degrade ? null : Colors.white.withValues(alpha: 0.07),
        borderRadius: rayon,
        border: degrade
            ? null
            : Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: degrade
            ? [
                BoxShadow(
                  color: rose.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: rayon,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: degrade
                        ? Colors.white.withValues(alpha: 0.22)
                        : null,
                    gradient: degrade ? null : degradeCka,
                  ),
                  child: Icon(icone, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        texte,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: degrade ? Colors.white : Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.icone, required this.texte});

  final IconData icone;
  final String texte;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    violet.withValues(alpha: 0.35),
                    rose.withValues(alpha: 0.25),
                  ],
                ),
              ),
              child: Icon(icone, size: 44, color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Text(
              texte,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recherche par titre, artiste ou album.
class _Recherche extends SearchDelegate<void> {
  _Recherche(this.chansons) : super(searchFieldLabel: 'Titre, artiste, album…');

  final List<Chanson> chansons;

  @override
  ThemeData appBarTheme(BuildContext context) {
    final theme = Theme.of(context);
    return theme.copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: Colors.white38),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(
        icon: const Icon(Icons.clear_rounded),
        onPressed: () => query = '',
      ),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back_rounded),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _resultats(context);

  @override
  Widget buildSuggestions(BuildContext context) => _resultats(context);

  Widget _resultats(BuildContext context) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      return const _Vide(
        icone: Icons.search_rounded,
        texte: 'Cherchez une chanson',
      );
    }
    final trouves = [
      for (final c in chansons)
        if (c.titre.toLowerCase().contains(q) ||
            c.artiste.toLowerCase().contains(q) ||
            c.album.toLowerCase().contains(q))
          c,
    ];
    if (trouves.isEmpty) {
      return const _Vide(
        icone: Icons.search_off_rounded,
        texte: 'Aucun résultat',
      );
    }
    final lecteur = LecteurScope.lire(context);
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: trouves.length,
            itemBuilder: (context, i) => TuileChanson(
              chanson: trouves[i],
              onTap: () => lecteur.lire(trouves, index: i),
            ),
          ),
        ),
        const MiniLecteur(),
      ],
    );
  }
}
