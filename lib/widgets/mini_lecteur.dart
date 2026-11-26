import 'package:flutter/material.dart';

import '../ecrans/ecran_lecture.dart';
import '../services/lecteur.dart';
import '../theme.dart';
import 'pochette.dart';
import 'texte_defilant.dart';

/// Barre en bas de l'écran avec le titre en cours. Un appui ouvre le lecteur.
class MiniLecteur extends StatelessWidget {
  const MiniLecteur({super.key});

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final chanson = lecteur.enCours;
    if (chanson == null) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: GestureDetector(
        onTap: () => ouvrirLecture(context),
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -200) ouvrirLecture(context);
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
          decoration: BoxDecoration(
            // Fond teinté violet → rose, plus vivant qu'un gris uni.
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color.alphaBlend(violet.withValues(alpha: 0.28), surface),
                Color.alphaBlend(rose.withValues(alpha: 0.16), surface),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 4, 6),
                child: Row(
                  children: [
                    Hero(
                      tag: 'pochette',
                      child: Pochette(chanson: chanson, taille: 46, rayon: 10),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TexteDefilant(
                            chanson.titre,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            chanson.artiste,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Gros bouton rond au dégradé de la marque.
                    Tooltip(
                      message: lecteur.joue ? 'Pause' : 'Lecture',
                      child: Material(
                        type: MaterialType.transparency,
                        child: Ink(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: degradeCka,
                          ),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: lecteur.basculerLecture,
                            child: Icon(
                              lecteur.joue
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 30,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Titre suivant',
                      onPressed: lecteur.suivant,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  ],
                ),
              ),
              StreamBuilder<Duration>(
                stream: lecteur.player.positionStream,
                builder: (context, instantane) {
                  final total = chanson.duree.inMilliseconds;
                  final position = instantane.data?.inMilliseconds ?? 0;
                  final part = total == 0
                      ? 0.0
                      : (position / total).clamp(0.0, 1.0);
                  // Barre de progression au dégradé de la marque.
                  return SizedBox(
                    height: 3,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        const Positioned.fill(
                          child: ColoredBox(color: Colors.white12),
                        ),
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: part,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(gradient: degradeCka),
                            child: SizedBox.expand(),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ouvre l'écran de lecture en glissant depuis le bas.
void ouvrirLecture(BuildContext context) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) => const EcranLecture(),
      transitionsBuilder: (_, animation, _, enfant) => SlideTransition(
        position: Tween(begin: const Offset(0, 1), end: Offset.zero).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: enfant,
      ),
    ),
  );
}
