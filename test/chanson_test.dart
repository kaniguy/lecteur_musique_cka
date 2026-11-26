import 'package:flutter_test/flutter_test.dart';
import 'package:lecteur_musique_cka/modeles/chanson.dart';

void main() {
  test('lit une chanson envoyée par Android', () {
    final c = Chanson.depuisMap({
      'id': 12,
      'titre': 'Ma chanson',
      'artiste': 'Mon artiste',
      'album': 'Mon album',
      'albumId': 5,
      'duree': 187000,
      'ajout': 1700000000,
      'uri': 'content://media/external/audio/media/12',
    });
    expect(c.id, 12);
    expect(c.titre, 'Ma chanson');
    expect(c.duree, const Duration(minutes: 3, seconds: 7));
    expect(c.ajout.year, 2023);
  });

  test('remplace les infos manquantes ou <unknown>', () {
    final c = Chanson.depuisMap({
      'id': 1,
      'titre': '  ',
      'artiste': '<unknown>',
      'album': null,
      'albumId': 2,
      'duree': 60000,
      'ajout': 0,
      'uri': 'content://x',
    });
    expect(c.titre, 'Titre inconnu');
    expect(c.artiste, 'Artiste inconnu');
    expect(c.album, 'Album inconnu');
  });

  test('trie de A à Z sans tenir compte des guillemets ni des accents', () {
    final titres = [
      '"Mattigui Allah"',
      'élégie',
      'Zouk',
      '"Ki mara"',
      'abba',
      '  Bamba',
    ];
    titres.sort((a, b) => cleTri(a).compareTo(cleTri(b)));
    expect(titres, [
      'abba',
      '  Bamba',
      'élégie',
      '"Ki mara"',
      '"Mattigui Allah"',
      'Zouk',
    ]);
  });

  test('formate les durées', () {
    expect(formaterDuree(const Duration(seconds: 7)), '0:07');
    expect(formaterDuree(const Duration(minutes: 3, seconds: 45)), '3:45');
    expect(
      formaterDuree(const Duration(hours: 1, minutes: 2, seconds: 5)),
      '1:02:05',
    );
  });

  test("lit l'année, même donnée comme une date, et ignore 0", () {
    Chanson lire(Object? annee) => Chanson.depuisMap({
      'id': 1,
      'titre': 'x',
      'albumId': 1,
      'uri': 'content://x',
      'annee': annee,
    });
    expect(lire(2025).annee, 2025);
    expect(lire(20240314).annee, 2024);
    expect(lire(0).annee, isNull);
    expect(lire(null).annee, isNull);
  });

  test("regroupe par année, la plus récente d'abord, Autres à la fin", () {
    Chanson c(int id, String titre, int? annee) => Chanson(
      id: id,
      titre: titre,
      artiste: 'a',
      album: 'b',
      albumId: 1,
      duree: Duration.zero,
      ajout: DateTime(2026),
      uri: 'u$id',
      annee: annee,
    );
    final groupes = grouperParAnnee([
      c(1, 'Zouk', 2025),
      c(2, 'Sans date', null),
      c(3, 'Afro', 2026),
      c(4, 'Abba', 2025),
    ]);
    expect(groupes.map((g) => g.nom), ['2026', '2025', 'Autres']);
    expect(groupes[1].chansons.map((x) => x.titre), ['Abba', 'Zouk']);
  });

  test("trouve l'année écrite dans les titres", () {
    expect(
      anneeDansTexte(
        'ALEXIS BALAFON DE WONVAGAVOGO DOGNIMIN 2025 10 A FONONVOGO',
      ),
      2025,
    );
    expect(
      anneeDansTexte('BALAFON DE ZOUANEKAHA N°1 LE 15-03-2025 A GBALELIVOGO'),
      2025,
    );
    expect(anneeDansTexte('AUD-20261115-WA0058'), 2026);
    expect(anneeDansTexte('balafon de tougouho à sononzo 02062025'), 2025);
    expect(
      anneeDansTexte('FOLOGO BALAFON DE PASCAL NAKAHA BONNBONKA DE 2O26 N3'),
      2026,
    );
    expect(
      anneeDansTexte('BALAFON DE KAGNAKAHA MINTANFOWA N22026 N2 A FODIOLOKAHA'),
      2026,
    );
    expect(anneeDansTexte('BALAFON DE SOULKAHA N°1 07-10-14'), 2014);
    expect(
      anneeDansTexte('BALAFON DE ZOUANEKAHA N°4 2025 A KARAFIGUE_123400'),
      2025,
    );
    // Pas d'année : numéros de piste, de téléphone, identifiants Telegram.
    expect(anneeDansTexte('01 Pitchanna wolo yičkini'), isNull);
    expect(anneeDansTexte('+225 07 88 17 6897'), isNull);
    expect(anneeDansTexte('4_5953767868549041329'), isNull);
    expect(anneeDansTexte('Carine_SORO__Wouho_go_gui(360p)'), isNull);
  });

  test("préfère l'année du titre, puis du nom de fichier", () {
    final c = Chanson.depuisMap({
      'id': 1,
      'titre': 'NABI  _0151.mp3',
      'fichier': 'BALAFON DE DONASI ZOUAGNIKAHA 2025 A DOMAINKAHA N5.mp3',
      'albumId': 1,
      'uri': 'u',
      'annee': 2014,
    });
    expect(c.annee, 2025);
  });
}
