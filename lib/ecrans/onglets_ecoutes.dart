import 'package:flutter/material.dart';

import '../modeles/chanson.dart';
import '../services/lecteur.dart';
import '../theme.dart';
import '../widgets/choix_playlist.dart';
import '../widgets/pochette.dart';
import '../widgets/tuile_chanson.dart';
import 'ecran_collection.dart';
import 'ecran_playlist.dart';

/// Onglet « Récents » : les 50 derniers titres écoutés, le plus récent
/// tout en haut. Un sélecteur affiche à la place les plus écoutés.
class OngletRecents extends StatefulWidget {
  const OngletRecents({super.key});

  @override
  State<OngletRecents> createState() => _OngletRecentsState();
}

class _OngletRecentsState extends State<OngletRecents> {
  bool _plusEcoutes = false;

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final recents = lecteur.chansons(lecteur.memoire.recents);
    final top = lecteur.chansons(lecteur.memoire.plusEcoutees(nombre: 50));

    if (recents.isEmpty) {
      return const _Vide(
        icone: Icons.history_rounded,
        texte:
            'Vos écoutes apparaîtront ici :\n'
            'les titres écoutés récemment et vos préférés.',
      );
    }

    final liste = _plusEcoutes ? top : recents;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.history_rounded),
                  label: Text('Écoutés récemment'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.trending_up_rounded),
                  label: Text('Plus écoutés'),
                ),
              ],
              selected: {_plusEcoutes},
              showSelectedIcon: false,
              onSelectionChanged: (choix) =>
                  setState(() => _plusEcoutes = choix.first),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            itemCount: liste.length,
            itemBuilder: (context, i) => Row(
              children: [
                SizedBox(
                  width: 36,
                  child: Text(
                    '${i + 1}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: _plusEcoutes && i < 3
                          ? Theme.of(context).colorScheme.primary
                          : Colors.white54,
                    ),
                  ),
                ),
                Expanded(
                  child: TuileChanson(
                    chanson: liste[i],
                    liste: liste,
                    detail: _plusEcoutes
                        ? _ecoutes(lecteur.memoire.ecoutes(liste[i].id))
                        : null,
                    onTap: () => lecteur.lire(liste, index: i),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static String _ecoutes(int n) => '$n écoute${n > 1 ? 's' : ''}';
}

/// Onglet « Playlists » : créer une playlist et ouvrir les siennes.
class OngletPlaylists extends StatelessWidget {
  const OngletPlaylists({super.key});

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final playlists = lecteur.memoire.playlists;
    final parAnnee = grouperParAnnee(lecteur.toutes);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // Playlists automatiques : une par année, et « Autres ».
        if (parAnnee.isNotEmpty) ...[
          const _Section(
            icone: Icons.auto_awesome_rounded,
            titre: 'Par année',
            detail: 'Créées automatiquement',
          ),
          SizedBox(
            height: 168,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: parAnnee.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) => _CarteAnnee(groupe: parAnnee[i]),
            ),
          ),
          const SizedBox(height: 8),
          const _Section(
            icone: Icons.queue_music_rounded,
            titre: 'Mes playlists',
          ),
        ],
        ListTile(
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: degradeCka,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.add_rounded, size: 30, color: Colors.white),
          ),
          title: const Text(
            'Nouvelle playlist',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          onTap: () async {
            final nom = await demanderNom(context);
            if (nom == null || !context.mounted) return;
            final p = lecteur.memoire.creerPlaylist(nom);
            _ouvrir(context, p.id);
          },
        ),
        if (playlists.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Créez une playlist, puis ajoutez-y des chansons avec le menu ⋮.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60),
            ),
          ),
        for (final p in playlists)
          ListTile(
            leading: _Mosaique(chansons: lecteur.chansons(p.chansons.take(4))),
            title: Text(
              p.nom,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${p.chansons.length} titre${p.chansons.length > 1 ? 's' : ''}',
              style: const TextStyle(color: Colors.white60),
            ),
            trailing: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
            ),
            onTap: () => _ouvrir(context, p.id),
          ),
      ],
    );
  }

  void _ouvrir(BuildContext context, String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => EcranPlaylist(playlistId: id)),
    );
  }
}

/// Titre de section (« Par année », « Mes playlists »).
class _Section extends StatelessWidget {
  const _Section({required this.icone, required this.titre, this.detail});

  final IconData icone;
  final String titre;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        children: [
          Icon(icone, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            titre,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          if (detail != null) ...[
            const Spacer(),
            Text(
              detail!,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

/// Carte d'une playlist automatique : l'année en grand sur un dégradé dont la
/// teinte change d'une année à l'autre.
class _CarteAnnee extends StatelessWidget {
  const _CarteAnnee({required this.groupe});

  final GroupeAnnee groupe;

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.lire(context);
    final annee = groupe.annee;
    final n = groupe.chansons.length;
    // Une teinte par année, entre violet et rose ; gris pour « Autres ».
    final teinte = annee == null ? 0.0 : 260.0 + (annee * 37) % 80;
    final couleurs = annee == null
        ? [const Color(0xFF3A3450), const Color(0xFF231D33)]
        : [
            HSLColor.fromAHSL(1, teinte % 360, 0.75, 0.52).toColor(),
            HSLColor.fromAHSL(1, (teinte + 40) % 360, 0.8, 0.42).toColor(),
          ];
    final rayon = BorderRadius.circular(22);

    return SizedBox(
      width: 136,
      child: Material(
        type: MaterialType.transparency,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: rayon,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: couleurs,
            ),
            boxShadow: [
              BoxShadow(
                color: couleurs.first.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: InkWell(
            borderRadius: rayon,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => EcranCollection(
                  titre: groupe.nom,
                  sousTitre: annee == null
                      ? 'Titres sans année'
                      : 'Playlist automatique',
                  chansons: groupe.chansons,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    annee == null
                        ? Icons.help_outline_rounded
                        : Icons.calendar_month_rounded,
                    color: Colors.white70,
                    size: 22,
                  ),
                  const Spacer(),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      groupe.nom,
                      style: const TextStyle(
                        fontFamily: policeTitre,
                        fontSize: 34,
                        height: 1,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$n titre${n > 1 ? 's' : ''}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      // Lecture directe sans ouvrir la playlist.
                      Semantics(
                        button: true,
                        label: 'Lire ${groupe.nom}',
                        child: InkResponse(
                          radius: 22,
                          onTap: () => lecteur.lire(groupe.chansons),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
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

/// Couverture de playlist : les pochettes de ses 4 premiers titres.
class _Mosaique extends StatelessWidget {
  const _Mosaique({required this.chansons});

  final List<Chanson> chansons;

  @override
  Widget build(BuildContext context) {
    const taille = 56.0;
    if (chansons.length < 4) {
      return chansons.isEmpty
          ? Container(
              width: taille,
              height: taille,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.queue_music_rounded,
                color: Colors.white38,
              ),
            )
          : Pochette(chanson: chansons.first, taille: taille, rayon: 12);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: taille,
        child: GridView.count(
          crossAxisCount: 2,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            for (final c in chansons)
              Pochette(chanson: c, taille: taille / 2, rayon: 0),
          ],
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
