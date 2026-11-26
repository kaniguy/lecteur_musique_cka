import 'package:flutter_test/flutter_test.dart';
import 'package:lecteur_musique_cka/modeles/chanson.dart';
import 'package:lecteur_musique_cka/services/memoire.dart';
import 'package:lecteur_musique_cka/services/selection.dart';
import 'package:shared_preferences/shared_preferences.dart';

Chanson _chanson(int id) => Chanson(
  id: id,
  titre: 'Titre $id',
  artiste: 'Artiste',
  album: 'Album',
  albumId: 1,
  duree: const Duration(minutes: 3),
  ajout: DateTime(2026),
  uri: 'content://media/$id',
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('coche, décoche et tout sélectionne', () {
    final liste = [for (var i = 1; i <= 4; i++) _chanson(i)];
    final s = Selection();
    expect(s.active, isFalse);

    s.basculer(liste[2], liste);
    s.basculer(liste[0], liste);
    expect(s.active, isTrue);
    expect(s.ids, [1, 3], reason: 'dans l\'ordre de la liste');

    s.basculer(liste[0], liste);
    expect(s.ids, [3]);

    s.toutBasculer();
    expect(s.toutEstCoche, isTrue);
    expect(s.nombre, 4);
    s.toutBasculer();
    expect(s.active, isFalse);
  });

  test('changer de liste oublie les titres absents', () {
    final a = [_chanson(1), _chanson(2)];
    final b = [_chanson(2), _chanson(3)];
    final s = Selection()
      ..basculer(a[0], a)
      ..basculer(a[1], a)
      ..basculer(b[1], b);
    expect(s.ids, [2, 3]);
  });

  test('ajoute plusieurs titres à une playlist sans doublon', () {
    final m = Memoire();
    final p = m.creerPlaylist('Mix');
    expect(m.ajouterPlusieurs(p, [1, 2, 3]), 3);
    expect(m.ajouterPlusieurs(p, [2, 4]), 1);
    expect(p.chansons, [1, 2, 3, 4]);
    m.retirerPlusieurs(p, {1, 3});
    expect(p.chansons, [2, 4]);
  });

  test('modifie et rétablit les infos, retrouvées après redémarrage', () async {
    final m = Memoire();
    await m.modifier([1, 2], artiste: 'Nouvel artiste');
    await m.modifier([1], titre: 'Nouveau titre');
    expect(m.appliquer(_chanson(1)).titre, 'Nouveau titre');
    expect(m.appliquer(_chanson(2)).artiste, 'Nouvel artiste');
    expect(m.appliquer(_chanson(2)).titre, 'Titre 2');

    final apres = Memoire();
    await apres.charger();
    expect(apres.appliquer(_chanson(1)).artiste, 'Nouvel artiste');

    await apres.retablir([1]);
    expect(apres.estModifiee(1), isFalse);
    expect(apres.appliquer(_chanson(1)).titre, 'Titre 1');
  });

  test('oublie les titres effacés du téléphone', () async {
    final m = Memoire();
    final p = m.creerPlaylist('Mix');
    m.ajouterPlusieurs(p, [1, 2, 3]);
    await m.enregistrerEcoute(2);
    await m.modifier([2], titre: 'X');
    await m.oublier({2});
    expect(p.chansons, [1, 3]);
    expect(m.recents, isEmpty);
    expect(m.ecoutes(2), 0);
    expect(m.estModifiee(2), isFalse);
  });

  test('marque des moments, les nomme, les retrouve et les efface', () async {
    final m = Memoire();
    await m.marquer(5, const Duration(minutes: 36, seconds: 12));
    await m.marquer(5, const Duration(minutes: 1));
    // À moins d'une seconde d'un moment existant : le remplace.
    final solo = await m.marquer(
      5,
      const Duration(minutes: 36, seconds: 12, milliseconds: 400),
    );
    expect(m.marques(5).map((x) => x.position.inSeconds), [60, 2172]);
    await m.nommerMarque(5, solo, 'le solo');

    final apres = Memoire();
    await apres.charger();
    expect(apres.aDesMarques(5), isTrue);
    expect(apres.marques(5).last.note, 'le solo');

    await apres.effacerMarque(5, apres.marques(5).first);
    expect(apres.marques(5).length, 1);
    await apres.oublier({5});
    expect(apres.aDesMarques(5), isFalse);
  });
}
