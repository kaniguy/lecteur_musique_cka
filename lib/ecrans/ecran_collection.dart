import 'package:flutter/material.dart';

import '../modeles/chanson.dart';
import '../services/lecteur.dart';
import '../services/selection.dart';
import '../theme.dart';
import '../widgets/actions_selection.dart';
import '../widgets/fond_cka.dart';
import '../widgets/mini_lecteur.dart';
import '../widgets/pochette.dart';
import '../widgets/tuile_chanson.dart';

/// Les titres d'un album, d'un artiste ou d'une playlist, avec une grande
/// pochette en tête. Un appui long sur un titre permet d'en cocher plusieurs.
class EcranCollection extends StatefulWidget {
  const EcranCollection({
    super.key,
    required this.titre,
    required this.sousTitre,
    required this.chansons,
    this.actions = const [],
    this.onRetirer,
    this.onRetirerPlusieurs,
  });

  final String titre;
  final String sousTitre;
  final List<Chanson> chansons;

  /// Boutons en haut à droite (par ex. renommer ou supprimer une playlist).
  final List<Widget> actions;

  /// Pour une playlist : retire une chanson.
  final void Function(Chanson)? onRetirer;

  /// Pour une playlist : retire plusieurs chansons cochées.
  final void Function(List<Chanson>)? onRetirerPlusieurs;

  @override
  State<EcranCollection> createState() => _EcranCollectionState();
}

class _EcranCollectionState extends State<EcranCollection> {
  final Selection _selection = Selection();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    // Les titres à jour (infos modifiées, titres effacés retirés).
    final chansons = lecteur.chansons(widget.chansons.map((c) => c.id));
    final titre = widget.titre;
    final sousTitre = widget.sousTitre;
    final onRetirer = widget.onRetirer;
    if (chansons.isEmpty) {
      return FondCka(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(titre), actions: widget.actions),
          body: const Center(
            child: Text('Aucun titre', style: TextStyle(color: Colors.white60)),
          ),
        ),
      );
    }
    final duree = chansons.fold(Duration.zero, (total, c) => total + c.duree);

    return SelectionScope(
      selection: _selection,
      child: ListenableBuilder(
        listenable: _selection,
        builder: (context, _) => PopScope(
          canPop: !_selection.active,
          onPopInvokedWithResult: (fait, _) {
            if (!fait) _selection.vider();
          },
          child: _corps(
            context,
            lecteur,
            chansons,
            titre,
            sousTitre,
            onRetirer,
            duree,
          ),
        ),
      ),
    );
  }

  Widget _corps(
    BuildContext context,
    Lecteur lecteur,
    List<Chanson> chansons,
    String titre,
    String sousTitre,
    void Function(Chanson)? onRetirer,
    Duration duree,
  ) {
    final enSelection = _selection.active;
    return FondCka(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: enSelection
            ? BarreSelection(
                selection: _selection,
                onRetirer: widget.onRetirerPlusieurs,
              )
            : null,
        bottomNavigationBar: enSelection
            ? BarreActionsSelection(selection: _selection)
            : const MiniLecteur(),
        body: Column(
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (!enSelection)
                    SliverAppBar(
                      pinned: true,
                      expandedHeight: 320,
                      backgroundColor: fond,
                      actions: widget.actions,
                      flexibleSpace: FlexibleSpaceBar(
                        title: Text(
                          titre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            Pochette(chanson: chansons.first, rayon: 0),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [Colors.transparent, fond],
                                  stops: [0.4, 1],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$sousTitre · ${chansons.length} titres · '
                            '${duree.inMinutes} min',
                            style: const TextStyle(color: Colors.white60),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () => lecteur.lire(chansons),
                                  icon: const Icon(Icons.play_arrow_rounded),
                                  label: const Text('Lecture'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () =>
                                      lecteur.lire(chansons, aleatoire: true),
                                  icon: const Icon(Icons.shuffle_rounded),
                                  label: const Text('Aléatoire'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: chansons.length,
                    itemBuilder: (context, i) => TuileChanson(
                      chanson: chansons[i],
                      liste: chansons,
                      onTap: () => lecteur.lire(chansons, index: i),
                      onRetirer: onRetirer == null
                          ? null
                          : () => onRetirer(chansons[i]),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
