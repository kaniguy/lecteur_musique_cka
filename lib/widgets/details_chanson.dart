import 'package:flutter/material.dart';

import '../modeles/chanson.dart';
import '../services/lecteur.dart';
import 'choix_playlist.dart';
import 'pochette.dart';
import 'texte_defilant.dart';

/// Ouvre la fiche détaillée d'une chanson.
Future<void> afficherDetails(BuildContext context, Chanson chanson) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, defilement) =>
          _Details(chanson: chanson, defilement: defilement),
    ),
  );
}

class _Details extends StatelessWidget {
  const _Details({required this.chanson, required this.defilement});

  final Chanson chanson;
  final ScrollController defilement;

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    final favori = lecteur.estFavori(chanson);
    final ecoutes = lecteur.memoire.ecoutes(chanson.id);

    return ListView(
      controller: defilement,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Row(
          children: [
            Pochette(chanson: chanson, taille: 96, rayon: 14),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TexteDefilant(
                    chanson.titre,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chanson.artiste,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  lecteur.lire([chanson]);
                },
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Lire'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: favori ? 'Retirer des favoris' : 'Ajouter aux favoris',
              onPressed: () => lecteur.basculerFavori(chanson),
              icon: Icon(
                favori ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: favori ? accent : null,
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Ajouter à une playlist',
              onPressed: () => ajouterAUnePlaylist(context, chanson),
              icon: const Icon(Icons.playlist_add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _Ligne(Icons.album_rounded, 'Album', chanson.album),
        _Ligne(Icons.timer_outlined, 'Durée', formaterDuree(chanson.duree)),
        _Ligne(Icons.event_rounded, 'Ajouté le', _date(chanson.ajout)),
        _Ligne(
          Icons.headphones_rounded,
          'Écoutes',
          ecoutes == 0 ? 'Jamais écouté' : '$ecoutes fois',
        ),
        FutureBuilder<Map<String, Object?>>(
          future: lecteur.bibliotheque.details(chanson),
          builder: (context, instantane) {
            final d = instantane.data;
            if (d == null) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final taille = d['taille'] as int?;
            final debit = d['debit'] as int?;
            final annee = d['annee'] as int?;
            final piste = d['piste'] as int?;
            return Column(
              children: [
                if (d['genre'] case final String genre when genre.isNotEmpty)
                  _Ligne(Icons.category_rounded, 'Genre', genre),
                if (annee != null && annee > 0)
                  _Ligne(Icons.calendar_today_rounded, 'Année', '$annee'),
                if (piste != null && piste > 0)
                  _Ligne(
                    Icons.format_list_numbered_rounded,
                    'Piste',
                    '${piste % 1000}',
                  ),
                if (d['compositeur'] case final String compositeur
                    when compositeur.isNotEmpty)
                  _Ligne(Icons.edit_note_rounded, 'Compositeur', compositeur),
                if (d['format'] case final String format)
                  _Ligne(Icons.audio_file_rounded, 'Format', _format(format)),
                if (debit != null && debit > 0)
                  _Ligne(
                    Icons.speed_rounded,
                    'Qualité',
                    '${(debit / 1000).round()} kb/s',
                  ),
                if (taille != null)
                  _Ligne(Icons.sd_storage_rounded, 'Taille', _taille(taille)),
                if (d['fichier'] case final String fichier)
                  _Ligne(Icons.insert_drive_file_rounded, 'Fichier', fichier),
                if (d['dossier'] case final String dossier)
                  _Ligne(Icons.folder_rounded, 'Dossier', dossier),
              ],
            );
          },
        ),
      ],
    );
  }

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static String _taille(int octets) {
    final mo = octets / (1024 * 1024);
    return mo >= 1
        ? '${mo.toStringAsFixed(1)} Mo'
        : '${(octets / 1024).round()} Ko';
  }

  /// « audio/mpeg » → « MP3 », etc.
  static String _format(String mime) => switch (mime) {
    'audio/mpeg' => 'MP3',
    'audio/mp4' || 'audio/x-m4a' || 'audio/m4a' || 'audio/aac' => 'AAC / M4A',
    'audio/flac' || 'audio/x-flac' => 'FLAC',
    'audio/ogg' || 'application/ogg' => 'OGG',
    'audio/x-wav' || 'audio/wav' => 'WAV',
    'audio/opus' => 'OPUS',
    _ => mime.replaceFirst('audio/', '').toUpperCase(),
  };
}

class _Ligne extends StatelessWidget {
  const _Ligne(this.icone, this.libelle, this.valeur);

  final IconData icone;
  final String libelle;
  final String valeur;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 20, color: Colors.white54),
          const SizedBox(width: 14),
          SizedBox(
            width: 96,
            child: Text(libelle, style: const TextStyle(color: Colors.white60)),
          ),
          Expanded(
            child: SelectableText(
              valeur,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
