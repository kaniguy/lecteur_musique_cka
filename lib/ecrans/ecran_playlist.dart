import 'package:flutter/material.dart';

import '../services/lecteur.dart';
import '../services/memoire.dart';
import '../services/tri.dart';
import '../widgets/choix_playlist.dart';
import '../widgets/fond_cka.dart';
import '../widgets/mini_lecteur.dart';
import 'ecran_collection.dart';

/// Une playlist : lecture, tri, renommer, supprimer, retirer des titres.
class EcranPlaylist extends StatefulWidget {
  const EcranPlaylist({super.key, required this.playlistId});

  final String playlistId;

  @override
  State<EcranPlaylist> createState() => _EcranPlaylistState();
}

class _EcranPlaylistState extends State<EcranPlaylist> {
  /// Chaque playlist garde son propre tri d'une ouverture à l'autre.
  String get _cleTri => 'tri_playlist_${widget.playlistId}';

  Tri _tri = Tri.ordrePlaylist;

  @override
  void initState() {
    super.initState();
    _chargerTri();
  }

  Future<void> _chargerTri() async {
    final tri = await lireTri(_cleTri);
    if (!mounted || tri == null) return;
    setState(() => _tri = tri);
  }

  Future<void> _choisirTri(Tri tri) async {
    setState(() => _tri = tri);
    await garderTri(_cleTri, tri);
  }

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final playlist = lecteur.memoire.playlist(widget.playlistId);
    if (playlist == null) return const Scaffold();
    final chansons = trier(lecteur.chansons(playlist.chansons), _tri);

    final actions = [
      MenuTri(tri: _tri, onChoisi: _choisirTri, avecOrdrePlaylist: true),
      PopupMenuButton<String>(
        onSelected: (choix) => choix == 'renommer'
            ? _renommer(context, lecteur, playlist)
            : _supprimer(context, lecteur, playlist),
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'renommer',
            child: ListTile(
              leading: Icon(Icons.edit_rounded),
              title: Text('Renommer'),
            ),
          ),
          PopupMenuItem(
            value: 'supprimer',
            child: ListTile(
              leading: Icon(Icons.delete_outline_rounded),
              title: Text('Supprimer la playlist'),
            ),
          ),
        ],
      ),
    ];

    if (chansons.isEmpty) {
      return FondCka(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(playlist.nom), actions: actions),
          body: const Column(
            children: [
              Expanded(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Cette playlist est vide.\n'
                      'Ajoutez des chansons avec le menu ⋮, ou cochez-en plusieurs\n'
                      '(appui long) puis touchez « Playlist ».',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                ),
              ),
              MiniLecteur(),
            ],
          ),
        ),
      );
    }

    return EcranCollection(
      titre: playlist.nom,
      sousTitre: 'Playlist',
      chansons: chansons,
      actions: actions,
      onRetirer: (c) => lecteur.memoire.retirer(playlist, c.id),
      onRetirerPlusieurs: (liste) => lecteur.memoire.retirerPlusieurs(
        playlist,
        {for (final c in liste) c.id},
      ),
    );
  }

  Future<void> _renommer(
    BuildContext context,
    Lecteur lecteur,
    Playlist p,
  ) async {
    final nom = await demanderNom(
      context,
      titre: 'Renommer la playlist',
      initial: p.nom,
      bouton: 'Renommer',
    );
    if (nom != null) lecteur.memoire.renommer(p, nom);
  }

  Future<void> _supprimer(
    BuildContext context,
    Lecteur lecteur,
    Playlist p,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Supprimer « ${p.nom} » ?'),
        content: const Text('Les chansons restent sur le téléphone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    Navigator.of(context).pop();
    lecteur.memoire.supprimer(p);
  }
}
