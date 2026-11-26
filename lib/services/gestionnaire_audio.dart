import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Relie le lecteur à Android : notification, écran verrouillé, casque et
/// Bluetooth. La notification a, en plus des commandes habituelles, un
/// bouton ♥ pour mettre le titre en cours en favori.
class GestionnaireAudio extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  GestionnaireAudio() {
    player.playbackEventStream.listen(
      (_) => _publierEtat(),
      onError: (Object _, StackTrace _) {},
    );
    player.playingStream.listen((_) => _publierEtat());
    player.currentIndexStream.listen((index) {
      final file = queue.value;
      if (index != null && index < file.length) mediaItem.add(file[index]);
      _publierEtat();
    });
  }

  static const Duration _saut = Duration(seconds: 15);
  static const String _actionFavori = 'favori';

  final AudioPlayer player = AudioPlayer();

  /// Dit si la chanson (par son identifiant) est en favori.
  bool Function(String id) estFavori = (_) => false;

  /// Appelé quand on touche ♥ dans la notification.
  void Function(String id) basculerFavori = (_) {};

  /// Remplace la file affichée par Android (notification, écran verrouillé).
  void changerFile(List<MediaItem> file) {
    queue.add(file);
    final index = player.currentIndex;
    if (index != null && index < file.length) mediaItem.add(file[index]);
  }

  /// Redessine la notification (par ex. après un changement de favori).
  void rafraichir() => _publierEtat();

  void _publierEtat() {
    final id = mediaItem.value?.id;
    final favori = id != null && estFavori(id);
    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
          MediaControl.custom(
            androidIcon: favori
                ? 'drawable/ic_favori'
                : 'drawable/ic_favori_vide',
            label: favori ? 'Retirer des favoris' : 'Ajouter aux favoris',
            name: _actionFavori,
          ),
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        // Boutons visibles quand la notification est repliée.
        androidCompactActionIndices: const [0, 1, 2],
        processingState: switch (player.processingState) {
          ProcessingState.idle => AudioProcessingState.idle,
          ProcessingState.loading => AudioProcessingState.loading,
          ProcessingState.buffering => AudioProcessingState.buffering,
          ProcessingState.ready => AudioProcessingState.ready,
          ProcessingState.completed => AudioProcessingState.completed,
        },
        playing: player.playing,
        updatePosition: player.position,
        bufferedPosition: player.bufferedPosition,
        speed: player.speed,
        queueIndex: player.currentIndex,
      ),
    );
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() => player.seekToNext();

  @override
  Future<void> skipToPrevious() => player.seekToPrevious();

  @override
  Future<void> skipToQueueItem(int index) =>
      player.seek(Duration.zero, index: index);

  @override
  Future<void> fastForward() => player.seek(player.position + _saut);

  @override
  Future<void> rewind() {
    final cible = player.position - _saut;
    return player.seek(cible < Duration.zero ? Duration.zero : cible);
  }

  @override
  Future<void> stop() async {
    await player.pause();
    await super.stop();
  }

  @override
  Future<dynamic> customAction(
    String name, [
    Map<String, dynamic>? extras,
  ]) async {
    final id = mediaItem.value?.id;
    if (name == _actionFavori && id != null) basculerFavori(id);
  }
}
