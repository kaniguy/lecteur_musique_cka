import 'package:flutter/material.dart';

import '../modeles/chanson.dart';
import '../services/lecteur.dart';
import '../theme.dart';

/// Demande un nom de playlist. Renvoie null si l'utilisateur annule.
Future<String?> demanderNom(
  BuildContext context, {
  String titre = 'Nouvelle playlist',
  String initial = '',
  String bouton = 'Créer',
}) {
  final champ = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) {
      void valider() {
        final nom = champ.text.trim();
        if (nom.isNotEmpty) Navigator.of(context).pop(nom);
      }

      return AlertDialog(
        backgroundColor: surface,
        title: Text(titre),
        content: TextField(
          controller: champ,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Nom de la playlist'),
          onSubmitted: (_) => valider(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          FilledButton(onPressed: valider, child: Text(bouton)),
        ],
      );
    },
  );
}

/// Ouvre la liste des playlists pour y ajouter [chanson] (ou en créer une).
Future<void> ajouterAUnePlaylist(BuildContext context, Chanson chanson) =>
    ajouterPlusieursAUnePlaylist(context, [chanson]);

/// Ouvre la liste des playlists pour y ajouter [chansons] (ou en créer une).
/// Renvoie vrai si les titres ont été ajoutés quelque part.
Future<bool> ajouterPlusieursAUnePlaylist(
  BuildContext context,
  List<Chanson> chansons,
) async {
  if (chansons.isEmpty) return false;
  final ids = [for (final c in chansons) c.id];
  final seul = chansons.length == 1;
  var fait = false;
  final lecteur = LecteurScope.lire(context);
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

  String titres(int n) => n > 1 ? '$n titres ajoutés' : 'Ajouté';

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (feuille) {
      final playlists = lecteur.memoire.playlists;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(feuille).height * 0.7,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  seul
                      ? 'Ajouter à une playlist'
                      : 'Ajouter ${chansons.length} titres à une playlist',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ListTile(
                leading: const _IconeDegrade(icone: Icons.add_rounded),
                title: const Text(
                  'Nouvelle playlist',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                onTap: () async {
                  final nom = await demanderNom(feuille);
                  if (nom == null) return;
                  final p = lecteur.memoire.creerPlaylist(nom);
                  final n = lecteur.memoire.ajouterPlusieurs(p, ids);
                  fait = true;
                  if (feuille.mounted) Navigator.of(feuille).pop();
                  informer('${titres(n)} à « $nom »');
                },
              ),
              for (final p in playlists)
                ListTile(
                  leading: const _IconeDegrade(
                    icone: Icons.queue_music_rounded,
                  ),
                  title: Text(
                    p.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${p.chansons.length} titre${p.chansons.length > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white60),
                  ),
                  trailing: ids.every(p.chansons.contains)
                      ? const Icon(Icons.check_rounded, color: Colors.white60)
                      : null,
                  onTap: () {
                    final n = lecteur.memoire.ajouterPlusieurs(p, ids);
                    fait = true;
                    Navigator.of(feuille).pop();
                    informer(
                      n > 0
                          ? '${titres(n)} à « ${p.nom} »'
                          : 'Déjà dans « ${p.nom} »',
                    );
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
  return fait;
}

class _IconeDegrade extends StatelessWidget {
  const _IconeDegrade({required this.icone});

  final IconData icone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: degradeCka,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icone, color: Colors.white),
    );
  }
}
