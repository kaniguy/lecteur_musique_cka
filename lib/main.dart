import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import 'ecrans/ecran_accueil.dart';
import 'services/bibliotheque.dart';
import 'services/gestionnaire_audio.dart';
import 'services/lecteur.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Lecture en arrière-plan : notification (avec ♥) et commandes sur
  // l'écran verrouillé.
  final audio = await AudioService.init(
    builder: GestionnaireAudio.new,
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.cka.lecteur_musique_cka.lecture',
      androidNotificationChannelName: 'Lecture de musique',
      androidNotificationOngoing: true,
    ),
  );
  runApp(MusiqueApp(lecteur: Lecteur(Bibliotheque(), audio)));
}

class MusiqueApp extends StatelessWidget {
  const MusiqueApp({super.key, required this.lecteur});

  final Lecteur lecteur;

  @override
  Widget build(BuildContext context) {
    return LecteurScope(
      lecteur: lecteur,
      child: MaterialApp(
        title: 'Musique CKA',
        debugShowCheckedModeBanner: false,
        theme: themeCka(),
        home: const EcranAccueil(),
      ),
    );
  }
}
