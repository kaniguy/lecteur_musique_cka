import 'package:flutter/material.dart';

import '../modeles/chanson.dart';
import '../services/lecteur.dart';
import '../services/memoire.dart';

/// Couleur des moments marqués : un or chaud, bien visible sur le violet.
const Color orMarque = Color(0xFFFFC857);

String _libelle(Marque m) => m.note.isEmpty
    ? formaterDuree(m.position)
    : '${formaterDuree(m.position)} · ${m.note}';

/// Marque le moment en cours et propose de lui donner un nom.
Future<void> marquerMaintenant(BuildContext context) async {
  final lecteur = LecteurScope.lire(context);
  final chanson = lecteur.enCours;
  final marque = await lecteur.marquerMaintenant();
  if (marque == null || chanson == null || !context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.bookmark_added_rounded, color: orMarque),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Moment ${formaterDuree(marque.position)} marqué'),
            ),
          ],
        ),
        // Se ferme tout seul, même avec le bouton « Nommer ».
        duration: const Duration(seconds: 4),
        persist: false,
        action: SnackBarAction(
          label: 'Nommer',
          textColor: orMarque,
          onPressed: () => nommerMarque(context, chanson, marque),
        ),
      ),
    );
}

/// Demande un nom pour le moment (« le refrain », « le solo »…).
Future<void> nommerMarque(
  BuildContext context,
  Chanson chanson,
  Marque marque,
) async {
  final memoire = LecteurScope.lire(context).memoire;
  final champ = TextEditingController(text: marque.note);
  final note = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Moment ${formaterDuree(marque.position)}'),
      content: TextField(
        controller: champ,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Nom du moment',
          hintText: 'Ex. : le refrain, le solo…',
          prefixIcon: Icon(Icons.edit_note_rounded),
        ),
        onSubmitted: (texte) => Navigator.of(context).pop(texte),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(champ.text),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
  champ.dispose();
  if (note != null) await memoire.nommerMarque(chanson.id, marque, note);
}

/// Feuille avec tous les moments marqués d'une chanson : on touche un moment
/// pour l'écouter directement.
Future<void> afficherMarques(
  BuildContext context,
  Chanson chanson, {
  List<Chanson>? liste,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (feuille) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(feuille).height * 0.7,
        ),
        child: _ListeMarques(chanson: chanson, liste: liste),
      ),
    ),
  );
}

class _ListeMarques extends StatelessWidget {
  const _ListeMarques({required this.chanson, this.liste});

  final Chanson chanson;
  final List<Chanson>? liste;

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final marques = lecteur.memoire.marques(chanson.id);
    final enCours = lecteur.enCours?.id == chanson.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: Row(
            children: [
              const Icon(Icons.bookmarks_rounded, color: orMarque),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Moments marqués',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
              if (enCours)
                TextButton.icon(
                  onPressed: () => marquerMaintenant(context),
                  icon: const Icon(Icons.bookmark_add_rounded),
                  label: const Text('Marquer'),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            chanson.titre,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white60),
          ),
        ),
        if (marques.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Text(
              'Aucun moment marqué.\n'
              'Pendant l\'écoute, touchez le signet du lecteur au moment '
              'que vous aimez.',
              style: TextStyle(color: Colors.white70, height: 1.45),
            ),
          )
        else
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: marques.length,
              itemBuilder: (context, i) {
                final m = marques[i];
                return ListTile(
                  leading: Container(
                    width: 64,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: orMarque.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      formaterDuree(m.position),
                      style: const TextStyle(
                        color: orMarque,
                        fontWeight: FontWeight.w800,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  title: Text(
                    m.note.isEmpty ? 'Moment ${i + 1}' : m.note,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text(
                    'Toucher pour écouter',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    lecteur.allerAuMoment(chanson, m.position, liste: liste);
                  },
                  trailing: PopupMenuButton<String>(
                    tooltip: 'Options du moment',
                    onSelected: (choix) => choix == 'nommer'
                        ? nommerMarque(context, chanson, m)
                        : lecteur.memoire.effacerMarque(chanson.id, m),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'nommer',
                        child: ListTile(
                          leading: Icon(Icons.edit_rounded),
                          title: Text('Nommer'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'effacer',
                        child: ListTile(
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Effacer'),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

/// Puces des moments marqués, sous le titre dans le lecteur.
class PucesMarques extends StatelessWidget {
  const PucesMarques({super.key, required this.chanson});

  final Chanson chanson;

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final marques = lecteur.memoire.marques(chanson.id);
    if (marques.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: marques.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final m = marques[i];
          return Material(
            color: orMarque.withValues(alpha: 0.14),
            shape: StadiumBorder(
              side: BorderSide(color: orMarque.withValues(alpha: 0.5)),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () => lecteur.allerAuMoment(chanson, m.position),
              onLongPress: () => afficherMarques(context, chanson),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.bookmark_rounded,
                      size: 16,
                      color: orMarque,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _libelle(m),
                      style: const TextStyle(
                        color: orMarque,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Petits repères dorés posés sur la barre de progression ; un appui sur un
/// repère y amène directement.
class ReperesMarques extends StatelessWidget {
  const ReperesMarques({
    super.key,
    required this.chanson,
    required this.total,
    required this.marge,
  });

  final Chanson chanson;
  final Duration total;

  /// Marge à gauche et à droite de la piste du curseur.
  final double marge;

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final marques = lecteur.memoire.marques(chanson.id);
    if (marques.isEmpty || total.inMilliseconds <= 0) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, contraintes) {
        final largeur = contraintes.maxWidth - 2 * marge;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            for (final m in marques)
              Positioned(
                left:
                    marge +
                    largeur *
                        (m.position.inMilliseconds / total.inMilliseconds)
                            .clamp(0.0, 1.0) -
                    16,
                top: 0,
                bottom: 0,
                child: Tooltip(
                  message: _libelle(m),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => lecteur.allerAuMoment(chanson, m.position),
                    child: const SizedBox(
                      width: 32,
                      child: Center(
                        child: Icon(
                          Icons.arrow_drop_down_rounded,
                          size: 30,
                          color: orMarque,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
