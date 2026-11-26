import 'package:flutter/material.dart';

import '../modeles/chanson.dart';
import '../services/bibliotheque.dart';
import '../services/lecteur.dart';
import '../theme.dart';
import '../widgets/fond_cka.dart';
import '../widgets/mini_lecteur.dart';

/// Les sons présents plusieurs fois sur le téléphone (même contenu).
/// « Fusionner » garde un exemplaire, lui passe les écoutes, favoris,
/// playlists et moments marqués des copies, puis efface les copies.
class EcranDoublons extends StatefulWidget {
  const EcranDoublons({super.key});

  @override
  State<EcranDoublons> createState() => _EcranDoublonsState();
}

class _EcranDoublonsState extends State<EcranDoublons> {
  List<List<FichierDouble>>? _groupes;

  /// Pour chaque groupe (par son indice), l'identifiant du fichier gardé.
  final Map<int, int> _gardes = {};
  bool _enCours = false;

  @override
  void initState() {
    super.initState();
    _chercher();
  }

  Future<void> _chercher() async {
    final lecteur = LecteurScope.lire(context);
    final trouves = await lecteur.bibliotheque.doublons();
    if (!mounted) return;
    // Seulement les fichiers que l'application affiche.
    final groupes = [
      for (final g in trouves)
        [
          for (final f in g)
            if (lecteur.chansons([f.id]).isNotEmpty) f,
        ],
    ].where((g) => g.length >= 2).toList();
    setState(() {
      _groupes = groupes;
      _gardes
        ..clear()
        ..addAll({
          for (final (i, g) in groupes.indexed) i: _choixParDefaut(lecteur, g),
        });
    });
  }

  /// Garde de préférence l'original (pas « -1 »), puis le plus écouté,
  /// puis le plus ancien.
  int _choixParDefaut(Lecteur lecteur, List<FichierDouble> groupe) {
    final tries = [...groupe]
      ..sort((a, b) {
        if (a.estCopie != b.estCopie) return a.estCopie ? 1 : -1;
        final e = lecteur.memoire
            .ecoutes(b.id)
            .compareTo(lecteur.memoire.ecoutes(a.id));
        if (e != 0) return e;
        final n = a.fichier.length.compareTo(b.fichier.length);
        return n != 0 ? n : a.ajout.compareTo(b.ajout);
      });
    return tries.first.id;
  }

  /// Copie → fichier gardé, pour ces groupes.
  Map<int, int> _fusion(Iterable<int> indices) => {
    for (final i in indices)
      for (final f in _groupes![i])
        if (f.id != _gardes[i]) f.id: _gardes[i]!,
  };

  int _octetsLiberes(Iterable<int> indices) => [
    for (final i in indices)
      for (final f in _groupes![i])
        if (f.id != _gardes[i]) f.taille,
  ].fold(0, (a, b) => a + b);

  Future<void> _fusionner(Iterable<int> indices) async {
    final fusion = _fusion(indices);
    if (fusion.isEmpty || _enCours) return;
    final octets = _octetsLiberes(indices);
    setState(() => _enCours = true);
    final lecteur = LecteurScope.lire(context);
    final effaces = await lecteur.fusionnerDoublons(fusion);
    if (!mounted) return;
    setState(() => _enCours = false);
    final texte = effaces == 0
        ? 'Rien n\'a été supprimé.'
        : '${_copies(effaces)} supprimée${effaces > 1 ? 's' : ''}'
              '${effaces == fusion.length ? ' · ${_taille(octets)} libérés' : ''}';
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(texte)));
    if (effaces > 0) await _chercher();
  }

  @override
  Widget build(BuildContext context) {
    final groupes = _groupes;
    return FondCka(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(title: const Text('Doublons')),
        body: Column(
          children: [
            Expanded(
              child: switch (groupes) {
                null => const _Recherche(),
                [] => const _AucunDoublon(),
                _ => _liste(context, groupes),
              },
            ),
            const MiniLecteur(),
          ],
        ),
      ),
    );
  }

  Widget _liste(BuildContext context, List<List<FichierDouble>> groupes) {
    final tous = List.generate(groupes.length, (i) => i);
    final copies = _fusion(tous).length;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: groupes.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _Resume(
            sons: groupes.length,
            copies: copies,
            octets: _octetsLiberes(tous),
            enCours: _enCours,
            onToutFusionner: () => _fusionner(tous),
          );
        }
        final indice = i - 1;
        return _CarteGroupe(
          groupe: groupes[indice],
          garde: _gardes[indice]!,
          enCours: _enCours,
          onGarder: (id) => setState(() => _gardes[indice] = id),
          onFusionner: () => _fusionner([indice]),
        );
      },
    );
  }
}

String _copies(int n) => '$n copie${n > 1 ? 's' : ''}';

String _taille(int octets) {
  if (octets >= 1e9) {
    return '${(octets / 1e9).toStringAsFixed(1).replaceAll('.', ',')} Go';
  }
  return '${(octets / 1e6).round()} Mo';
}

class _Recherche extends StatelessWidget {
  const _Recherche();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 16),
        Text(
          'Recherche des doublons…',
          style: TextStyle(color: Colors.white70),
        ),
      ],
    ),
  );
}

class _AucunDoublon extends StatelessWidget {
  const _AucunDoublon();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 56, color: Colors.white70),
          SizedBox(height: 16),
          Text(
            'Aucun doublon.\nChaque son n\'est qu\'une fois sur le téléphone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ),
  );
}

class _Resume extends StatelessWidget {
  const _Resume({
    required this.sons,
    required this.copies,
    required this.octets,
    required this.enCours,
    required this.onToutFusionner,
  });

  final int sons;
  final int copies;
  final int octets;
  final bool enCours;
  final VoidCallback onToutFusionner;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceHaute.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$sons son${sons > 1 ? 's' : ''} en double',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '${_copies(copies)} en trop · ${_taille(octets)} à libérer',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          const Text(
            'Fusionner garde le son coché ✓ et lui donne les écoutes, favoris, '
            'playlists et moments marqués des copies. Les copies sont ensuite '
            'supprimées du téléphone (Android demande de confirmer).',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: enCours ? null : onToutFusionner,
              icon: enCours
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.merge_rounded),
              label: Text('Tout fusionner (${_copies(copies)})'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CarteGroupe extends StatelessWidget {
  const _CarteGroupe({
    required this.groupe,
    required this.garde,
    required this.enCours,
    required this.onGarder,
    required this.onFusionner,
  });

  final List<FichierDouble> groupe;
  final int garde;
  final bool enCours;
  final ValueChanged<int> onGarder;
  final VoidCallback onFusionner;

  @override
  Widget build(BuildContext context) {
    final lecteur = LecteurScope.of(context);
    final chanson = lecteur.chansons([garde]).firstOrNull;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              chanson?.titre ?? groupe.first.fichier,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
            child: Text(
              '${groupe.length} fichiers identiques (même son, même contenu)',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
          const SizedBox(height: 4),
          for (final f in groupe)
            _LigneFichier(
              fichier: f,
              gardee: f.id == garde,
              duree: lecteur.chansons([f.id]).firstOrNull?.duree,
              ecoutes: lecteur.memoire.ecoutes(f.id),
              favori: lecteur.chansons([f.id]).any(lecteur.estFavori),
              onTap: enCours ? null : () => onGarder(f.id),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: enCours ? null : onFusionner,
              icon: const Icon(Icons.merge_rounded),
              label: const Text('Fusionner'),
            ),
          ),
        ],
      ),
    );
  }
}

class _LigneFichier extends StatelessWidget {
  const _LigneFichier({
    required this.fichier,
    required this.gardee,
    required this.duree,
    required this.ecoutes,
    required this.favori,
    required this.onTap,
  });

  final FichierDouble fichier;
  final bool gardee;
  final Duration? duree;
  final int ecoutes;
  final bool favori;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final details = [
      if (duree case final d?) formaterDuree(d),
      _taille(fichier.taille),
      if (fichier.dossier.isNotEmpty) fichier.dossier,
      if (ecoutes > 0) '$ecoutes écoute${ecoutes > 1 ? 's' : ''}',
      if (favori) '♥',
    ].join(' · ');
    return ListTile(
      onTap: onTap,
      dense: true,
      leading: Icon(
        gardee ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
        color: gardee ? Theme.of(context).colorScheme.primary : Colors.white38,
      ),
      title: Text(
        fichier.fichier,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: gardee ? Colors.white : Colors.white70),
      ),
      subtitle: Text(details, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Text(
        gardee ? 'Garder' : 'Supprimer',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: gardee ? Theme.of(context).colorScheme.primary : danger,
        ),
      ),
    );
  }
}
