import 'dart:io';

import 'package:flutter/material.dart';

import '../modeles/chanson.dart';
import '../services/lecteur.dart';

/// Pochette d'album d'une chanson, ou un joli dégradé s'il n'y en a pas.
/// Sans [taille], elle remplit tout l'espace disponible.
class Pochette extends StatelessWidget {
  const Pochette({
    super.key,
    required this.chanson,
    this.taille,
    this.rayon = 10,
  });

  final Chanson? chanson;
  final double? taille;
  final double rayon;

  @override
  Widget build(BuildContext context) {
    final c = chanson;
    final contenu = c == null
        ? _Vide(graine: 0, taille: taille)
        : _image(context, c);
    return ClipRRect(
      borderRadius: BorderRadius.circular(rayon),
      child: taille == null
          ? SizedBox.expand(child: contenu)
          : SizedBox.square(dimension: taille, child: contenu),
    );
  }

  Widget _image(BuildContext context, Chanson c) {
    final bibliotheque = LecteurScope.lire(context).bibliotheque;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    return FutureBuilder<String?>(
      future: bibliotheque.pochette(c),
      initialData: bibliotheque.pochetteConnue(c),
      builder: (context, instantane) {
        final chemin = instantane.data;
        if (chemin == null) return _Vide(graine: c.albumId, taille: taille);
        return Image.file(
          File(chemin),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          cacheWidth: taille == null ? 600 : (taille! * ratio).round(),
          errorBuilder: (_, _, _) => _Vide(graine: c.albumId, taille: taille),
        );
      },
    );
  }
}

class _Vide extends StatelessWidget {
  const _Vide({required this.graine, required this.taille});

  final int graine;
  final double? taille;

  @override
  Widget build(BuildContext context) {
    final teinte = (graine * 47) % 360;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            HSVColor.fromAHSV(1, teinte.toDouble(), 0.65, 0.55).toColor(),
            HSVColor.fromAHSV(1, (teinte + 50) % 360, 0.75, 0.3).toColor(),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: Colors.white60,
          size: (taille ?? 200) * 0.45,
        ),
      ),
    );
  }
}
