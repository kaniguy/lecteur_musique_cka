import 'package:flutter/material.dart';

import '../modeles/chanson.dart';
import '../services/lecteur.dart';
import '../services/selection.dart';
import '../theme.dart';
import 'actions_selection.dart';
import 'choix_playlist.dart';
import 'details_chanson.dart';
import 'marques.dart';
import 'pochette.dart';
import 'texte_defilant.dart';

/// Une ligne de la liste des titres, avec son menu d'actions.
/// Un appui long coche le titre pour agir sur plusieurs à la fois.
class TuileChanson extends StatelessWidget {
  const TuileChanson({
    super.key,
    required this.chanson,
    required this.onTap,
    this.liste = const [],
    this.detail,
    this.onRetirer,
  });

  final Chanson chanson;
  final VoidCallback onTap;

  /// La liste affichée autour du titre (pour « Tout sélectionner »).
  final List<Chanson> liste;

  /// Remplace la durée dans la 2e ligne (par ex. « 12 écoutes »).
  final String? detail;

  /// Si présent, le menu propose « Retirer de la playlist ».
  final VoidCallback? onRetirer;

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final actif = lecteur.enCours?.id == chanson.id;
    final favori = lecteur.estFavori(chanson);
    final aDesMarques = lecteur.memoire.aDesMarques(chanson.id);
    final selection = SelectionScope.of(context);
    final enSelection = selection?.active ?? false;
    final coche = selection?.contient(chanson) ?? false;
    void basculer() =>
        selection?.basculer(chanson, liste.isEmpty ? [chanson] : liste);

    return ListTile(
      onTap: enSelection ? basculer : onTap,
      onLongPress: selection == null ? null : basculer,
      selected: coche,
      selectedTileColor: accent.withValues(alpha: 0.18),
      // Le titre en cours ressort avec un léger fond rosé.
      tileColor: actif ? accent.withValues(alpha: 0.08) : null,
      shape: coche || actif
          ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
          : null,
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      leading: SizedBox.square(
        dimension: 52,
        child: Stack(
          children: [
            Pochette(chanson: chanson, taille: 52),
            if (coche)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        violet.withValues(alpha: 0.85),
                        rose.withValues(alpha: 0.85),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              )
            else if (actif)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    lecteur.joue
                        ? Icons.graphic_eq_rounded
                        : Icons.pause_rounded,
                    color: accent,
                  ),
                ),
              ),
          ],
        ),
      ),
      // Le titre en cours défile s'il est trop long.
      title: TexteDefilant(
        chanson.titre,
        actif: actif,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: actif ? accent : Colors.white,
        ),
      ),
      subtitle: Text(
        '${chanson.artiste} · ${detail ?? formaterDuree(chanson.duree)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white60),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (aDesMarques && !enSelection)
            IconButton(
              tooltip: 'Moments marqués',
              visualDensity: VisualDensity.compact,
              onPressed: () => afficherMarques(
                context,
                chanson,
                liste: liste.isEmpty ? null : liste,
              ),
              icon: const Icon(
                Icons.bookmark_rounded,
                size: 20,
                color: orMarque,
              ),
            ),
          if (favori)
            Icon(
              Icons.favorite_rounded,
              size: 18,
              color: accent,
              semanticLabel: 'Favori',
            ),
          if (enSelection)
            SizedBox.square(
              dimension: 48,
              child: Center(child: _Coche(coche: coche)),
            )
          else
            PopupMenuButton<_Action>(
              tooltip: 'Actions',
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white60),
              onSelected: (action) => _agir(context, lecteur, action),
              itemBuilder: (_) => [
                if (selection != null)
                  const PopupMenuItem(
                    value: _Action.selectionner,
                    child: ListTile(
                      leading: Icon(Icons.check_circle_outline_rounded),
                      title: Text('Sélectionner'),
                    ),
                  ),
                const PopupMenuItem(
                  value: _Action.marques,
                  child: ListTile(
                    leading: Icon(Icons.bookmarks_outlined),
                    title: Text('Moments marqués'),
                  ),
                ),
                const PopupMenuItem(
                  value: _Action.details,
                  child: ListTile(
                    leading: Icon(Icons.info_outline_rounded),
                    title: Text('Détails du titre'),
                  ),
                ),
                const PopupMenuItem(
                  value: _Action.ensuite,
                  child: ListTile(
                    leading: Icon(Icons.playlist_play_rounded),
                    title: Text('Lire ensuite'),
                  ),
                ),
                const PopupMenuItem(
                  value: _Action.file,
                  child: ListTile(
                    leading: Icon(Icons.queue_music_rounded),
                    title: Text('Ajouter à la file d\'attente'),
                  ),
                ),
                PopupMenuItem(
                  value: _Action.favori,
                  child: ListTile(
                    leading: Icon(
                      favori
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                    ),
                    title: Text(
                      favori ? 'Retirer des favoris' : 'Ajouter aux favoris',
                    ),
                  ),
                ),
                const PopupMenuItem(
                  value: _Action.playlist,
                  child: ListTile(
                    leading: Icon(Icons.playlist_add_rounded),
                    title: Text('Ajouter à une playlist'),
                  ),
                ),
                if (onRetirer != null)
                  const PopupMenuItem(
                    value: _Action.retirer,
                    child: ListTile(
                      leading: Icon(Icons.playlist_remove_rounded),
                      title: Text('Retirer de la playlist'),
                    ),
                  ),
                const PopupMenuItem(
                  value: _Action.partager,
                  child: ListTile(
                    leading: Icon(Icons.share_rounded),
                    title: Text('Partager'),
                  ),
                ),
                const PopupMenuItem(
                  value: _Action.supprimer,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline_rounded, color: danger),
                    title: Text(
                      'Supprimer du téléphone',
                      style: TextStyle(color: danger),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  void _agir(BuildContext context, Lecteur lecteur, _Action action) {
    final messager = ScaffoldMessenger.of(context);
    void informer(String texte) => messager
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(texte),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );

    switch (action) {
      case _Action.selectionner:
        SelectionScope.of(context)
            ?.basculer(chanson, liste.isEmpty ? [chanson] : liste);
      case _Action.marques:
        afficherMarques(context, chanson, liste: liste.isEmpty ? null : liste);
      case _Action.details:
        afficherDetails(context, chanson);
      case _Action.ensuite:
        lecteur.lireEnsuite(chanson);
        informer('« ${chanson.titre} » sera lu ensuite');
      case _Action.file:
        lecteur.ajouterALaFile(chanson);
        informer('Ajouté à la file d\'attente');
      case _Action.favori:
        lecteur.basculerFavori(chanson);
      case _Action.playlist:
        ajouterAUnePlaylist(context, chanson);
      case _Action.retirer:
        onRetirer?.call();
        informer('Retiré de la playlist');
      case _Action.partager:
        partagerTitres(context, [chanson]);
      case _Action.supprimer:
        supprimerDuTelephone(context, [chanson]);
    }
  }
}

enum _Action {
  partager,
  supprimer,
  selectionner,
  marques,
  details,
  ensuite,
  file,
  favori,
  playlist,
  retirer,
}

/// Petit rond coché / vide à droite d'un titre pendant une sélection.
class _Coche extends StatelessWidget {
  const _Coche({required this.coche});

  final bool coche;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: coche ? degradeCka : null,
        border: coche ? null : Border.all(color: Colors.white54, width: 2),
      ),
      child: coche
          ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
          : null,
    );
  }
}
