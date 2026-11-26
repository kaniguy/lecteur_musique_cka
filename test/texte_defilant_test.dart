import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lecteur_musique_cka/widgets/texte_defilant.dart';

Widget _dans(double largeur, String texte) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(width: largeur, child: TexteDefilant(texte)),
    ),
  ),
);

void main() {
  testWidgets('un titre court reste immobile', (tester) async {
    await tester.pumpWidget(_dans(300, 'Court'));
    expect(find.text('Court'), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('un titre trop long défile sans déborder', (tester) async {
    const long =
        'Un titre vraiment très très long qui ne tient pas sur la ligne';
    await tester.pumpWidget(_dans(120, long));
    await tester.pump(const Duration(seconds: 3));
    // Le texte est affiché deux fois (boucle continue) et aucune erreur
    // de débordement n'est signalée.
    expect(find.text(long), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    expect(tester.hasRunningAnimations, isTrue);
  });
}
