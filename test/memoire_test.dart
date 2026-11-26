import 'package:flutter_test/flutter_test.dart';
import 'package:lecteur_musique_cka/services/memoire.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('compte les écoutes et garde les plus récentes en tête', () async {
    final m = Memoire();
    await m.enregistrerEcoute(1);
    await m.enregistrerEcoute(2);
    await m.enregistrerEcoute(1);
    await m.enregistrerEcoute(3);
    await m.enregistrerEcoute(1);

    expect(m.recents, [1, 3, 2]);
    expect(m.ecoutes(1), 3);
    expect(m.plusEcoutees().first, 1);
  });

  test('ne garde que les 50 écoutes les plus récentes', () async {
    final m = Memoire();
    for (var id = 0; id < 60; id++) {
      await m.enregistrerEcoute(id);
    }
    expect(m.recents.length, Memoire.tailleRecents);
    expect(m.recents.first, 59);
  });

  test('crée, remplit, renomme et supprime une playlist', () async {
    final m = Memoire();
    final p = m.creerPlaylist('Soirée');
    expect(m.ajouter(p, 10), isTrue);
    expect(m.ajouter(p, 11), isTrue);
    expect(m.ajouter(p, 10), isFalse, reason: 'pas de doublon');
    expect(p.chansons, [10, 11]);

    m.retirer(p, 10);
    m.renommer(p, 'Soirée 2');
    expect(m.playlist(p.id)!.nom, 'Soirée 2');
    expect(p.chansons, [11]);

    m.supprimer(p);
    expect(m.playlists, isEmpty);
  });

  test('tout est retrouvé après redémarrage', () async {
    final avant = Memoire();
    final p = avant.creerPlaylist('Route');
    avant.ajouter(p, 7);
    await avant.enregistrerEcoute(7);
    await Future<void>.delayed(Duration.zero);

    final apres = Memoire();
    await apres.charger();
    expect(apres.playlists.single.nom, 'Route');
    expect(apres.playlists.single.chansons, [7]);
    expect(apres.recents, [7]);
    expect(apres.ecoutes(7), 1);
  });

  test('fusionne les doublons vers la chanson gardée', () async {
    final m = Memoire();
    await m.enregistrerEcoute(1);
    await m.enregistrerEcoute(2);
    await m.enregistrerEcoute(2);
    final p = m.creerPlaylist('Balafon');
    m.ajouterPlusieurs(p, [5, 2, 1, 6]);
    await m.marquer(2, const Duration(seconds: 30), note: 'solo');
    await m.modifier([2], titre: 'Beau titre');

    // 2 est une copie de 1 : on garde 1.
    await m.fusionner({2: 1});
    await m.oublier({2});

    expect(m.ecoutes(1), 3);
    expect(m.ecoutes(2), 0);
    expect(p.chansons, [
      5,
      1,
      6,
    ], reason: 'à la place de la copie, sans doublon');
    expect(m.recents, [1]);
    expect(m.marques(1).single.note, 'solo');
    expect(m.estModifiee(1), isTrue);
  });
}
