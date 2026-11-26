import 'package:flutter/material.dart';

import '../modeles/chanson.dart';
import '../services/lecteur.dart';
import '../services/selection.dart';
import '../theme.dart';
import 'choix_playlist.dart';

/// Les titres cochés, à jour (infos modifiées comprises).
List<Chanson> _cochees(BuildContext context, Selection selection) =>
    LecteurScope.lire(context).chansons(selection.ids);

void _informer(BuildContext context, String texte) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));

String _titres(int n) => '$n titre${n > 1 ? 's' : ''}';

/// Barre du haut pendant une sélection : nombre de titres cochés, tout
/// sélectionner, et les actions moins fréquentes.
class BarreSelection extends StatelessWidget implements PreferredSizeWidget {
  const BarreSelection({
    super.key,
    required this.selection,
    this.onRetirer,
    this.bottom,
  });

  final Selection selection;

  /// Pour une playlist : retire les titres cochés.
  final void Function(List<Chanson>)? onRetirer;
  final PreferredSizeWidget? bottom;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final cochees = _cochees(context, selection);
    final modifiees = cochees.any((c) => lecteur.memoire.estModifiee(c.id));

    return AppBar(
      backgroundColor: surface.withValues(alpha: 0.92),
      leading: IconButton(
        tooltip: 'Annuler la sélection',
        icon: const Icon(Icons.close_rounded),
        onPressed: selection.vider,
      ),
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        transitionBuilder: (enfant, animation) =>
            FadeTransition(opacity: animation, child: enfant),
        child: Text(
          '${selection.nombre} sélectionné${selection.nombre > 1 ? 's' : ''}',
          key: ValueKey(selection.nombre),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      actions: [
        IconButton(
          tooltip: selection.toutEstCoche
              ? 'Tout désélectionner'
              : 'Tout sélectionner',
          isSelected: selection.toutEstCoche,
          selectedIcon: Icon(Icons.select_all_rounded, color: accent),
          icon: const Icon(Icons.select_all_rounded),
          onPressed: selection.toutBasculer,
        ),
        if (onRetirer != null)
          IconButton(
            tooltip: 'Retirer de la playlist',
            icon: const Icon(Icons.playlist_remove_rounded),
            onPressed: () {
              onRetirer!(cochees);
              selection.vider();
              _informer(context, '${_titres(cochees.length)} retiré(s)');
            },
          ),
        PopupMenuButton<String>(
          tooltip: 'Plus d\'actions',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (choix) async {
            switch (choix) {
              case 'ensuite':
                await lecteur.lirePlusieursEnsuite(cochees);
                if (context.mounted) {
                  _informer(
                    context,
                    '${_titres(cochees.length)} lu(s) ensuite',
                  );
                }
              case 'file':
                await lecteur.ajouterPlusieursALaFile(cochees);
                if (context.mounted) {
                  _informer(
                    context,
                    '${_titres(cochees.length)} ajouté(s) à la file d\'attente',
                  );
                }
              case 'retablir':
                await lecteur.retablirInfos(cochees);
                if (context.mounted) {
                  _informer(context, 'Infos d\'origine rétablies');
                }
            }
            selection.vider();
          },
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'ensuite',
              child: ListTile(
                leading: Icon(Icons.playlist_play_rounded),
                title: Text('Lire ensuite'),
              ),
            ),
            const PopupMenuItem(
              value: 'file',
              child: ListTile(
                leading: Icon(Icons.queue_music_rounded),
                title: Text('Ajouter à la file d\'attente'),
              ),
            ),
            if (modifiees)
              const PopupMenuItem(
                value: 'retablir',
                child: ListTile(
                  leading: Icon(Icons.restore_rounded),
                  title: Text('Rétablir les infos d\'origine'),
                ),
              ),
          ],
        ),
      ],
      bottom: bottom,
    );
  }
}

/// Barre du bas pendant une sélection : les actions principales.
class BarreActionsSelection extends StatelessWidget {
  const BarreActionsSelection({super.key, required this.selection});

  final Selection selection;

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final cochees = _cochees(context, selection);
    final tousFavoris = cochees.isNotEmpty && cochees.every(lecteur.estFavori);

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _BoutonAction(
              icone: Icons.play_arrow_rounded,
              texte: 'Lire',
              principal: true,
              onTap: () {
                lecteur.lire(cochees);
                selection.vider();
              },
            ),
            _BoutonAction(
              icone: Icons.playlist_add_rounded,
              texte: 'Playlist',
              onTap: () async {
                final fait = await ajouterPlusieursAUnePlaylist(
                  context,
                  cochees,
                );
                if (fait) selection.vider();
              },
            ),
            _BoutonAction(
              icone: tousFavoris
                  ? Icons.heart_broken_rounded
                  : Icons.favorite_rounded,
              texte: tousFavoris ? 'Retirer ♥' : 'Favoris',
              onTap: () {
                lecteur.definirFavoris(cochees, !tousFavoris);
                _informer(
                  context,
                  tousFavoris
                      ? '${_titres(cochees.length)} retiré(s) des favoris'
                      : '${_titres(cochees.length)} ajouté(s) aux favoris',
                );
                selection.vider();
              },
            ),
            _BoutonAction(
              icone: Icons.share_rounded,
              texte: 'Partager',
              onTap: () async {
                final fait = await partagerTitres(context, cochees);
                if (fait) selection.vider();
              },
            ),
            _BoutonAction(
              icone: Icons.edit_rounded,
              texte: 'Modifier',
              onTap: () async {
                final fait = await modifierInfos(context, cochees);
                if (fait) selection.vider();
              },
            ),
            _BoutonAction(
              icone: Icons.delete_outline_rounded,
              texte: 'Supprimer',
              danger: true,
              onTap: () async {
                final fait = await supprimerDuTelephone(context, cochees);
                if (fait) selection.vider();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BoutonAction extends StatelessWidget {
  const _BoutonAction({
    required this.icone,
    required this.texte,
    required this.onTap,
    this.principal = false,
    this.danger = false,
  });

  final IconData icone;
  final String texte;
  final VoidCallback onTap;
  final bool principal;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final couleur = danger ? const Color(0xFFFF6B6B) : Colors.white;
    return Expanded(
      child: Semantics(
        button: true,
        label: texte,
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Column(
              // Hauteur minimale : sinon la barre remplit tout l'écran.
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: principal ? degradeCka : null,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icone, size: 22, color: couleur),
                ),
                const SizedBox(height: 4),
                Text(
                  texte,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: danger ? couleur : Colors.white70,
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

/// Change le titre, l'artiste ou l'album des [chansons] (dans l'application
/// seulement : le fichier n'est pas touché). Renvoie vrai si c'est fait.
Future<bool> modifierInfos(BuildContext context, List<Chanson> chansons) async {
  if (chansons.isEmpty) return false;
  final lecteur = LecteurScope.lire(context);
  final seul = chansons.length == 1;

  // Pré-remplit avec la valeur commune à tous les titres, s'il y en a une.
  String commun(String Function(Chanson) champ) {
    final valeurs = chansons.map(champ).toSet();
    return valeurs.length == 1 ? valeurs.first : '';
  }

  final titre = TextEditingController(text: seul ? chansons.first.titre : '');
  final artiste = TextEditingController(text: commun((c) => c.artiste));
  final album = TextEditingController(text: commun((c) => c.album));

  final ok = await showDialog<bool>(
    context: context,
    builder: (context) {
      InputDecoration deco(String label, IconData icone) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icone),
        helperText: seul ? null : 'Laisser vide pour ne pas changer',
      );
      return AlertDialog(
        title: Text(
          seul ? 'Modifier les infos' : 'Modifier ${_titres(chansons.length)}',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (seul) ...[
                TextField(
                  controller: titre,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: deco('Titre', Icons.music_note_rounded),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: artiste,
                autofocus: !seul,
                textCapitalization: TextCapitalization.words,
                decoration: deco('Artiste', Icons.person_rounded),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: album,
                textCapitalization: TextCapitalization.sentences,
                decoration: deco('Album', Icons.album_rounded),
              ),
              const SizedBox(height: 14),
              const Text(
                'Les changements s\'appliquent dans Musique CKA ; '
                'le fichier sur le téléphone n\'est pas modifié.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Enregistrer'),
          ),
        ],
      );
    },
  );

  String? valeur(TextEditingController champ) {
    final texte = champ.text.trim();
    return texte.isEmpty ? null : texte;
  }

  final nouveauTitre = seul ? valeur(titre) : null;
  final nouvelArtiste = valeur(artiste);
  final nouvelAlbum = valeur(album);
  titre.dispose();
  artiste.dispose();
  album.dispose();
  if (ok != true) return false;
  if (nouveauTitre == null && nouvelArtiste == null && nouvelAlbum == null) {
    return false;
  }
  await lecteur.modifierInfos(
    chansons,
    titre: nouveauTitre,
    artiste: nouvelArtiste,
    album: nouvelAlbum,
  );
  if (context.mounted) _informer(context, 'Infos enregistrées');
  return true;
}

/// Efface les [chansons] du téléphone, après confirmation.
/// Renvoie vrai si au moins un titre a été effacé.
Future<bool> supprimerDuTelephone(
  BuildContext context,
  List<Chanson> chansons,
) async {
  if (chansons.isEmpty) return false;
  final lecteur = LecteurScope.lire(context);
  final seul = chansons.length == 1;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(
        Icons.delete_forever_rounded,
        color: Color(0xFFFF6B6B),
        size: 32,
      ),
      title: Text(
        seul
            ? 'Supprimer « ${chansons.first.titre} » ?'
            : 'Supprimer ${_titres(chansons.length)} ?',
      ),
      content: const Text(
        'Les fichiers seront effacés du téléphone. '
        'Cette action est définitive.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE5484D),
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (ok != true) return false;
  try {
    final n = await lecteur.supprimerDuTelephone(chansons);
    if (context.mounted) {
      _informer(
        context,
        n == 0 ? 'Rien n\'a été supprimé' : '${_titres(n)} supprimé(s)',
      );
    }
    return n > 0;
  } catch (e) {
    if (context.mounted) _informer(context, 'Suppression impossible');
    return false;
  }
}

/// Ouvre le menu de partage d'Android (WhatsApp, Bluetooth, Xender…) avec
/// les fichiers audio des [chansons].
Future<bool> partagerTitres(
  BuildContext context,
  List<Chanson> chansons,
) async {
  if (chansons.isEmpty) return false;
  final ok = await LecteurScope.lire(context).bibliotheque
      .partager(chansons.map((c) => c.id));
  if (!ok && context.mounted) _informer(context, 'Partage impossible');
  return ok;
}
