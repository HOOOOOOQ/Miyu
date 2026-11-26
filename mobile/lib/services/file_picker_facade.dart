import 'package:file_picker/file_picker.dart' as picker;

/// Isolates file_picker usage behind a tiny facade so media_service stays
/// testable and the plugin import stays in one place.
class FilePickerFacade {
  Future<String?> pickFile(List<String>? extensions) async {
    final result = await picker.FilePicker.platform.pickFiles(
      type: extensions == null || extensions.isEmpty
          ? picker.FileType.any
          : picker.FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: false,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.single.path;
  }
}
