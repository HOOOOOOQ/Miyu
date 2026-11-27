import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:miyu/domain/models.dart';

/// Global shared engine instance (single source of playback truth).
final PlayerEngine playerEngine = PlayerEngine();

/// Playback engine — uses just_audio. Queue + queue APIs + state streams.
class PlayerEngine extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  final List<Song> _queue = [];
  int _index = -1;
  int _repeatMode = 0; // 0 off, 1 one, 2 all
  bool _shuffle = false;

  PlayerEngine() {
    player.playerStateStream.listen(_onPlayerState);
  }

  void setRepeat(int mode) {
    _repeatMode = mode;
    notifyListeners();
  }

  int get repeatMode => _repeatMode;

  void setShuffle(bool value) {
    _shuffle = value;
    notifyListeners();
  }

  bool get shuffle => _shuffle;

  void setPlaybackSpeed(double speed) => player.setSpeed(speed);

  // --- state streams (used by UI) ---
  Stream<Duration> get positionStream => player.positionStream;
  Stream<Duration> get durationStream => player.durationStream;
  Stream<bool> get playingStream => player.playingStream;
  ValueStream<PlayerState> get playerStateStream => player.playerStateStream;

  ValueStream<bool> get hasPrevious => Stream.value(_canPrevious()).asBroadcastStream() as ValueStream<bool>;
  ValueStream<bool> get hasNext => Stream.value(_canNext()).asBroadcastStream() as ValueStream<bool>;

  bool _canNext() => _index >= 0 && _index < _queue.length - 1;
  bool _canPrevious() => _index > 0;

  Song? get currentSong => _index >= 0 && _index < _queue.length ? _queue[_index] : null;

  // --- queue ---
  void setQueue(List<Song> songs, {int index = 0}) {
    _queue.clear();
    _queue.addAll(songs);
    _index = songs.isEmpty ? -1 : index.clamp(0, songs.length - 1);
    _maybePlayAtIndex();
  }

  void addToQueue(Song song) {
    if (_queue.isEmpty) {
      _queue.add(song);
      _index = 0;
    } else {
      _queue.insert(_index + 1, song);
    }
    notifyListeners();
  }

  void next() {
    if (_canNext()) {
      _index++;
      _maybePlayAtIndex();
    }
  }

  void previous() {
    if (_canPrevious()) {
      _index--;
      _maybePlayAtIndex(restart: true);
    }
  }

  void _maybePlayAtIndex({bool restart = false}) {
    final s = currentSong;
    if (s != null && (restart || !player.playing)) {
      player.setAudioSource(_urlFor(s));
    } else if (s == null) {
      // nothing
    }
  }

  String _urlFor(Song song) {
    // Fallback to local asset/file or provider URL (original streaming uses youtube).
    return song.sourceId ?? song.artworkUrl ?? '';
  }

  void playPause() async {
    if (player.playing) {
      await player.pause();
    } else {
      await player.play();
    }
  }

  Future<void> seek(Duration position) => player.seek(position);
  Future<void> setSpeed(double speed) => player.setSpeed(speed);

  void dispose() => player.dispose();
}
