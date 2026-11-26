import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../modeles/chanson.dart';

/// Les façons de trier une liste de chansons.
enum Tri {
  /// L'ordre voulu par l'utilisateur (seulement dans une playlist).
  ordrePlaylist,
  titreAZ,
  titreZA,
  artiste,
  recent,
  nouveautesAZ,
}

/// Pour le tri « Nouveautés en haut » : une chanson ajoutée depuis moins
/// longtemps que ça est considérée comme nouvelle.
const dureeNouveaute = Duration(days: 30);

/// Une copie de [chansons] triée selon [tri].
List<Chanson> trier(List<Chanson> chansons, Tri tri) {
  final liste = [...chansons];
  int parTitre(Chanson a, Chanson b) =>
      cleTri(a.titre).compareTo(cleTri(b.titre));
  switch (tri) {
    case Tri.ordrePlaylist:
      break;
    case Tri.titreAZ:
      liste.sort(parTitre);
    case Tri.titreZA:
      liste.sort((a, b) => parTitre(b, a));
    case Tri.artiste:
      liste.sort((a, b) {
        final c = cleTri(a.artiste).compareTo(cleTri(b.artiste));
        return c != 0 ? c : parTitre(a, b);
      });
    case Tri.recent:
      liste.sort((a, b) => b.ajout.compareTo(a.ajout));
    case Tri.nouveautesAZ:
      // Les chansons ajoutées récemment d'abord, puis toutes les autres ;
      // chaque groupe de A à Z.
      final limite = DateTime.now().subtract(dureeNouveaute);
      liste.sort((a, b) {
        final na = a.ajout.isAfter(limite), nb = b.ajout.isAfter(limite);
        if (na != nb) return na ? -1 : 1;
        return parTitre(a, b);
      });
  }
  return liste;
}

/// Le tri gardé sous [cle], ou null s'il n'y en a pas.
Future<Tri?> lireTri(String cle) async {
  final prefs = await SharedPreferences.getInstance();
  final nom = prefs.getString(cle);
  for (final t in Tri.values) {
    if (t.name == nom) return t;
  }
  return null;
}

/// Garde [tri] sous [cle] pour la prochaine ouverture de l'application.
Future<void> garderTri(String cle, Tri tri) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(cle, tri.name);
}

/// Le bouton « Trier » de la barre du haut.
class MenuTri extends StatelessWidget {
  const MenuTri({
    super.key,
    required this.tri,
    required this.onChoisi,
    this.avecOrdrePlaylist = false,
  });

  final Tri tri;
  final ValueChanged<Tri> onChoisi;

  /// Propose aussi « Ordre de la playlist ».
  final bool avecOrdrePlaylist;

  static const _choix = {
    Tri.ordrePlaylist: (
      Icons.format_list_numbered_rounded,
      'Ordre de la playlist',
    ),
    Tri.titreAZ: (Icons.arrow_downward_rounded, 'Titre de A à Z'),
    Tri.titreZA: (Icons.arrow_upward_rounded, 'Titre de Z à A'),
    Tri.artiste: (Icons.person_rounded, 'Par artiste'),
    Tri.recent: (Icons.schedule_rounded, 'Ajoutés récemment'),
    Tri.nouveautesAZ: (Icons.fiber_new_rounded, 'Nouveautés en haut (A à Z)'),
  };

  @override
  Widget build(BuildContext context) {
    // MenuAnchor plutôt que PopupMenuButton : le menu ne bloque pas l'écran.
    // Toucher ailleurs le ferme ET agit tout de suite (défiler, ouvrir…).
    return MenuAnchor(
      builder: (context, menu, _) => IconButton(
        tooltip: 'Trier',
        icon: const Icon(Icons.sort_rounded),
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
      menuChildren: [
        for (final MapEntry(key: t, value: (icone, texte)) in _choix.entries)
          if (t != Tri.ordrePlaylist || avecOrdrePlaylist)
            MenuItemButton(
              leadingIcon: Icon(icone),
              trailingIcon: t == tri ? const Icon(Icons.check_rounded) : null,
              onPressed: () => onChoisi(t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(texte),
              ),
            ),
      ],
    );
  }
}
