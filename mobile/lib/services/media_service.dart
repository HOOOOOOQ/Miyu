import 'dart:io';

import 'package:image_picker/image_picker.dart';

import '../core/errors/api_exception.dart';
import '../core/network/api_client.dart';
import 'file_picker_facade.dart';

class UploadedMedia {
  const UploadedMedia({
    required this.url,
    required this.mimeType,
    this.fileName,
    this.fileSize,
    this.width,
    this.height,
    this.duration,
    this.thumbnailUrl,
  });

  final String url;
  final String mimeType;
  final String? fileName;
  final int? fileSize;
  final double? width;
  final double? height;
  final double? duration;
  final String? thumbnailUrl;

  Map<String, dynamic> toMediaMeta() => {
        'fileName': fileName,
        'fileSize': fileSize,
        'mimeType': mimeType,
        'width': width,
        'height': height,
        'duration': duration,
        'thumbnailUrl': thumbnailUrl,
      };
}

/// Picks and uploads media. Uploads stream through the backend which holds
/// the Cloudinary credentials — the API secret never reaches the APK.
class MediaService {
  MediaService({required ApiClient api, ImagePicker? picker, FilePickerFacade? filePicker})
      : _api = api,
        _picker = picker ?? ImagePicker(),
        _filePicker = filePicker ?? FilePickerFacade();

  final ApiClient _api;
  final ImagePicker _picker;
  final FilePickerFacade _filePicker;

  static const int maxBytes = 25 * 1024 * 1024;

  Future<UploadedMedia?> pickAndUploadImage({ImageSource source = ImageSource.gallery}) async {
    final file = await _picker.pickImage(source: source, imageQuality: 88, maxWidth: 2400);
    if (file == null) return null;
    return upload(file.path, mimeType: _guessMime(file.path), fileName: file.name, isImage: true);
  }

  Future<UploadedMedia?> pickAndUploadVideo({ImageSource source = ImageSource.gallery}) async {
    final file = await _picker.pickVideo(source: source, maxDuration: const Duration(minutes: 5));
    if (file == null) return null;
    return upload(file.path, mimeType: _guessMime(file.path), fileName: file.name);
  }

  Future<UploadedMedia?> pickAndUploadDocument({List<String>? extensions}) async {
    final path = await _filePicker.pickFile(extensions);
    if (path == null) return null;
    final name = path.split('/').last;
    return upload(path, mimeType: _guessMime(name), fileName: name);
  }

  Future<UploadedMedia> upload(
    String filePath, {
    required String mimeType,
    String? fileName,
    bool isImage = false,
    void Function(double progress)? onProgress,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw ApiException(message: 'That file is no longer available', code: 'FILE_MISSING');
    }
    final size = await file.length();
    if (size > maxBytes) {
      throw ApiException(
        message: 'Files must be smaller than 25 MB',
        code: 'FILE_TOO_LARGE',
      );
    }
    final response = await _api.upload(
      '/media/upload',
      filePath: filePath,
      fileName: fileName ?? filePath.split('/').last,
      onProgress: onProgress,
    );
    final data = response['data'] as Map<String, dynamic>;
    return UploadedMedia(
      url: data['url'] as String,
      mimeType: (data['mimeType'] ?? mimeType).toString(),
      fileName: fileName ?? data['originalName']?.toString(),
      fileSize: data['bytes'] is num ? (data['bytes'] as num).toInt() : size,
      width: data['width'] is num ? (data['width'] as num).toDouble() : null,
      height: data['height'] is num ? (data['height'] as num).toDouble() : null,
      duration: data['duration'] is num ? (data['duration'] as num).toDouble() : null,
      thumbnailUrl: isImage ? data['url'] as String : null,
    );
  }

  Future<UploadedMedia> uploadVoiceNote(String filePath, {double? durationSeconds}) async {
    final media = await upload(filePath, mimeType: 'audio/m4a', fileName: 'voice-note.m4a');
    return UploadedMedia(
      url: media.url,
      mimeType: media.mimeType,
      fileName: media.fileName,
      fileSize: media.fileSize,
      duration: durationSeconds,
    );
  }


  String _guessMime(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.txt')) return 'text/plain';
    return 'application/octet-stream';
  }
}
