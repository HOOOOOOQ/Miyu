import 'dart:async';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records voice notes to an m4a file with a live duration tick.
class VoiceRecorderService {
  VoiceRecorderService({AudioRecorder? recorder}) : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _path;
  DateTime? _startedAt;
  Timer? _ticker;
  final _tickController = StreamController<Duration>.broadcast();

  Stream<Duration> get ticks => _tickController.stream;

  bool get isRecording => _startedAt != null;
  Duration get elapsed =>
      _startedAt == null ? Duration.zero : DateTime.now().difference(_startedAt!);

  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/miyu_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100),
      path: path,
    );
    _path = path;
    _startedAt = DateTime.now();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!_tickController.isClosed) _tickController.add(elapsed);
    });
    return true;
  }

  /// Stops and returns (path, duration). Returns null when nothing was recorded.
  Future<({String path, Duration duration})?> stop() async {
    if (_startedAt == null) return null;
    final recorded = await _recorder.stop();
    final duration = Duration(milliseconds: elapsed.inMilliseconds);
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    final path = recorded ?? _path;
    _path = null;
    if (path == null) return null;
    return (path: path, duration: duration);
  }

  Future<void> cancel() async {
    _ticker?.cancel();
    _ticker = null;
    _startedAt = null;
    _path = null;
    try {
      await _recorder.cancel();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _ticker?.cancel();
    if (!_tickController.isClosed) await _tickController.close();
    await _recorder.dispose();
  }
}
