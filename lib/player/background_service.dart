import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Android media notification + lock screen controls (audio_service + just_audio).
class MediaHandler extends BaseAudioHandler {
  final AudioPlayer player = AudioPlayer();

  MediaHandler() {
    player.playerStateStream.listen((state) {
      playbackState.value = PlaybackState(
        actions: const {
          MediaAction.pause,
          MediaAction.play,
          MediaAction.playFromMediaId,
          MediaAction.skipToNext,
          MediaAction.skipToPrevious,
          MediaAction.stop,
        },
        playing: state.playing,
        updatePosition: player.position,
        buffering: false,
      );
    });
  }

  @override
  Future<void> play() => player.play();

  @override
  Future<void> pause() => player.pause();

  @override
  Future<void> stop() => player.stop();

  @override
  Future<void> skipToNext() {
    // handled by shared player state in production
    return Future.value();
  }

  @override
  Future<void> skipToPrevious() => Future.value();

  @override
  Future<void> setSpeed(double speed) => player.setSpeed(speed);
}
