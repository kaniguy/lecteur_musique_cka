import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../modeles/chanson.dart';
import '../services/lecteur.dart';
import '../theme.dart';
import '../widgets/actions_selection.dart';
import '../widgets/barres_decibels.dart';
import '../widgets/choix_playlist.dart';
import '../widgets/details_chanson.dart';
import '../widgets/marques.dart';
import '../widgets/pochette.dart';
import '../widgets/texte_defilant.dart';

/// Lecteur plein écran : grande pochette, progression et toutes les commandes.
class EcranLecture extends StatelessWidget {
  const EcranLecture({super.key});

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final chanson = lecteur.enCours;
    final accent = Theme.of(context).colorScheme.primary;

    if (chanson == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Rien en lecture')),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          // Fond : la pochette floutée, assombrie.
          Positioned.fill(
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
              child: Pochette(chanson: chanson, rayon: 0),
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x99000000), Color(0xDD0E0B16), fond],
                  stops: [0, 0.55, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  _BarreHaut(chanson: chanson),
                  const Spacer(),
                  LayoutBuilder(
                    builder: (context, contraintes) {
                      // Assez grande, sans pousser les commandes hors de l'écran.
                      final cote = contraintes.maxWidth.clamp(
                        0.0,
                        MediaQuery.sizeOf(context).height * 0.36,
                      );
                      return AnimatedScale(
                        scale: lecteur.joue ? 1 : 0.86,
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeOutBack,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              const BoxShadow(
                                color: Colors.black87,
                                blurRadius: 40,
                                offset: Offset(0, 18),
                              ),
                              // Halo violet-rose autour de la pochette.
                              BoxShadow(
                                color: violet.withValues(alpha: 0.45),
                                blurRadius: 60,
                                spreadRadius: -6,
                                offset: const Offset(-12, 0),
                              ),
                              BoxShadow(
                                color: rose.withValues(alpha: 0.35),
                                blurRadius: 60,
                                spreadRadius: -6,
                                offset: const Offset(12, 10),
                              ),
                            ],
                          ),
                          child: Hero(
                            tag: 'pochette',
                            child: Pochette(
                              chanson: chanson,
                              taille: cote,
                              rayon: 24,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const BarresDecibels(hauteur: 54),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TexteDefilant(
                              chanson.titre,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              chanson.artiste,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Signet : marque le moment en cours (appui long :
                      // voir tous les moments marqués).
                      Semantics(
                        button: true,
                        label: 'Marquer ce moment',
                        child: InkResponse(
                          radius: 26,
                          onTap: () => marquerMaintenant(context),
                          onLongPress: () => afficherMarques(context, chanson),
                          child: SizedBox.square(
                            dimension: 52,
                            child: Icon(
                              lecteur.memoire.aDesMarques(chanson.id)
                                  ? Icons.bookmark_added_rounded
                                  : Icons.bookmark_add_outlined,
                              size: 30,
                              color: lecteur.memoire.aDesMarques(chanson.id)
                                  ? orMarque
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        iconSize: 30,
                        tooltip: 'Favori',
                        onPressed: () => lecteur.basculerFavori(chanson),
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (enfant, a) =>
                              ScaleTransition(scale: a, child: enfant),
                          child: lecteur.estFavori(chanson)
                              ? Icon(
                                  Icons.favorite_rounded,
                                  key: const ValueKey(1),
                                  color: accent,
                                )
                              : const Icon(
                                  Icons.favorite_border_rounded,
                                  key: ValueKey(0),
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (lecteur.memoire.aDesMarques(chanson.id)) ...[
                    const SizedBox(height: 12),
                    PucesMarques(chanson: chanson),
                  ],
                  const SizedBox(height: 14),
                  // Panneau de commandes en verre dépoli.
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Column(
                          children: [
                            _BarreProgression(chanson: chanson),
                            const SizedBox(height: 6),
                            _Commandes(lecteur: lecteur),
                            const SizedBox(height: 8),
                            _Options(
                              lecteur: lecteur,
                              onFile: () => _ouvrirFile(context),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _ouvrirFile(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.92,
        builder: (context, defilement) => _FileAttente(defilement: defilement),
      ),
    );
  }
}

class _BarreHaut extends StatelessWidget {
  const _BarreHaut({required this.chanson});

  final Chanson chanson;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          iconSize: 32,
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              const Text(
                'EN COURS DE LECTURE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  color: Colors.white60,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                chanson.album,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Partager',
          onPressed: () => partagerTitres(context, [chanson]),
          icon: const Icon(Icons.share_rounded),
        ),
        PopupMenuButton<String>(
          tooltip: 'Plus d\'options',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (choix) async {
            if (choix == 'details') return afficherDetails(context, chanson);
            final lecteur = LecteurScope.lire(context);
            final fait = await supprimerDuTelephone(context, [chanson]);
            // Plus rien à écouter : on referme le lecteur.
            if (fait && lecteur.enCours == null && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
              value: 'details',
              child: ListTile(
                leading: Icon(Icons.info_outline_rounded),
                title: Text('Détails du titre'),
              ),
            ),
            PopupMenuItem(
              value: 'supprimer',
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
    );
  }
}

/// Barre de progression que l'on peut faire glisser.
class _BarreProgression extends StatefulWidget {
  const _BarreProgression({required this.chanson});

  final Chanson chanson;

  @override
  State<_BarreProgression> createState() => _BarreProgressionState();
}

class _BarreProgressionState extends State<_BarreProgression> {
  double? _glissement;

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    return StreamBuilder<Duration>(
      stream: lecteur.player.positionStream,
      builder: (context, instantane) {
        final total = lecteur.player.duration ?? widget.chanson.duree;
        final max = total.inMilliseconds.toDouble().clamp(1.0, double.infinity);
        final position =
            (_glissement ??
                    (instantane.data ?? Duration.zero).inMilliseconds
                        .toDouble())
                .clamp(0.0, max);
        return Column(
          children: [
            // Repères dorés des moments marqués, au-dessus de la piste.
            SizedBox(
              height: lecteur.memoire.aDesMarques(widget.chanson.id) ? 20 : 0,
              child: ReperesMarques(
                chanson: widget.chanson,
                total: total,
                marge: 24,
              ),
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              ),
              child: Slider(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                value: position,
                max: max,
                onChanged: (v) => setState(() => _glissement = v),
                onChangeEnd: (v) {
                  lecteur.player.seek(Duration(milliseconds: v.round()));
                  setState(() => _glissement = null);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formaterDuree(Duration(milliseconds: position.round())),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  Text(
                    formaterDuree(total),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Ligne principale : reculer de 15 s, précédent, lecture, suivant,
/// avancer de 15 s.
class _Commandes extends StatelessWidget {
  const _Commandes({required this.lecteur});

  final Lecteur lecteur;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _BoutonSaut(
          enAvant: false,
          onPressed: () => lecteur.sauter(-Lecteur.saut),
        ),
        IconButton(
          iconSize: 44,
          onPressed: lecteur.precedent,
          icon: const Icon(Icons.skip_previous_rounded),
        ),
        GestureDetector(
          onTap: lecteur.basculerLecture,
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: degradeCka,
              boxShadow: [
                BoxShadow(
                  color: rose.withValues(alpha: 0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (enfant, a) =>
                  ScaleTransition(scale: a, child: enfant),
              child: Icon(
                lecteur.joue ? Icons.pause_rounded : Icons.play_arrow_rounded,
                key: ValueKey(lecteur.joue),
                size: 44,
                color: Colors.white,
              ),
            ),
          ),
        ),
        IconButton(
          iconSize: 44,
          onPressed: lecteur.suivant,
          icon: const Icon(Icons.skip_next_rounded),
        ),
        _BoutonSaut(
          enAvant: true,
          onPressed: () => lecteur.sauter(Lecteur.saut),
        ),
      ],
    );
  }
}

/// Flèche circulaire avec « 15 » au milieu.
class _BoutonSaut extends StatelessWidget {
  const _BoutonSaut({required this.enAvant, required this.onPressed});

  final bool enAvant;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: enAvant ? 'Avancer de 15 s' : 'Reculer de 15 s',
      onPressed: onPressed,
      icon: SizedBox.square(
        dimension: 34,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.flip(
              flipX: enAvant,
              child: const Icon(Icons.replay_rounded, size: 34),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 3),
              child: Text(
                '15',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ligne du bas : aléatoire, minuterie, playlist, file d'attente, répétition.
class _Options extends StatelessWidget {
  const _Options({required this.lecteur, required this.onFile});

  final Lecteur lecteur;
  final VoidCallback onFile;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final chanson = lecteur.enCours;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          tooltip: 'Aléatoire',
          onPressed: lecteur.basculerAleatoire,
          icon: Icon(
            Icons.shuffle_rounded,
            color: lecteur.aleatoire ? accent : Colors.white60,
          ),
        ),
        _BoutonMinuterie(lecteur: lecteur),
        IconButton(
          tooltip: 'Ajouter à une playlist',
          onPressed: chanson == null
              ? null
              : () => ajouterAUnePlaylist(context, chanson),
          icon: const Icon(Icons.playlist_add_rounded, color: Colors.white70),
        ),
        IconButton(
          tooltip: 'File d\'attente',
          onPressed: onFile,
          icon: const Icon(Icons.queue_music_rounded, color: Colors.white70),
        ),
        IconButton(
          tooltip: 'Répéter',
          onPressed: lecteur.changerRepetition,
          icon: Icon(
            lecteur.repetition == LoopMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            color: lecteur.repetition == LoopMode.off ? Colors.white60 : accent,
          ),
        ),
      ],
    );
  }
}

class _BoutonMinuterie extends StatelessWidget {
  const _BoutonMinuterie({required this.lecteur});

  final Lecteur lecteur;

  @override
  Widget build(BuildContext context) {
    final fin = lecteur.finMinuterie;
    final accent = Theme.of(context).colorScheme.primary;
    return IconButton(
      tooltip: 'Minuterie',
      onPressed: () => _choisir(context),
      icon: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bedtime_rounded,
            color: fin != null ? accent : Colors.white60,
          ),
          if (fin != null)
            Text(
              '${fin.hour}h${fin.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  void _choisir(BuildContext context) {
    const choix = [15, 30, 45, 60, 90];
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Arrêter la musique dans…',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
            for (final minutes in choix)
              ListTile(
                leading: const Icon(Icons.timer_outlined),
                title: Text('$minutes minutes'),
                onTap: () {
                  lecteur.programmerArret(Duration(minutes: minutes));
                  Navigator.of(context).pop();
                },
              ),
            if (lecteur.finMinuterie != null)
              ListTile(
                leading: const Icon(Icons.timer_off_outlined),
                title: const Text('Désactiver la minuterie'),
                onTap: () {
                  lecteur.programmerArret(null);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _FileAttente extends StatelessWidget {
  const _FileAttente({required this.defilement});

  final ScrollController defilement;

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final file = lecteur.file;
    final ordre = lecteur.ordre;
    final enCours = lecteur.player.currentIndex;
    final accent = Theme.of(context).colorScheme.primary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Row(
            children: [
              const Text(
                'File d\'attente',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Text(
                '${file.length} titres',
                style: const TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: defilement,
            itemCount: ordre.length,
            itemBuilder: (context, i) {
              final index = ordre[i];
              if (index >= file.length) return const SizedBox.shrink();
              final c = file[index];
              final actif = index == enCours;
              return ListTile(
                onTap: () => lecteur.allerA(index),
                leading: Pochette(chanson: c, taille: 44, rayon: 8),
                title: Text(
                  c.titre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: actif ? accent : null,
                    fontWeight: actif ? FontWeight.w800 : FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  c.artiste,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60),
                ),
                trailing: actif
                    ? Icon(Icons.graphic_eq_rounded, color: accent)
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}
