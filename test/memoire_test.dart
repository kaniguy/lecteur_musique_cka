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
}
