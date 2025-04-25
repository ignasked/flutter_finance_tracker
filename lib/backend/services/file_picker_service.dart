import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';

class FilePickerService {
  static final FilePickerService instance = FilePickerService._();

  FilePickerService._();

  // Pick an image from the gallery or camera
  Future<File?> pickImage({bool fromGallery = false}) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: fromGallery ? ImageSource.gallery : ImageSource.camera,
      imageQuality: 85,
      maxWidth: 1280,
      maxHeight: 1280,
    );

    if (image == null) return null;

    final bytes = await image.readAsBytes();
    final compressedBytes = await FlutterImageCompress.compressWithList(
      bytes,
      quality: 85,
      format: CompressFormat.jpeg,
    );

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/compressed_receipt.jpg');
    await tempFile.writeAsBytes(compressedBytes);

    return tempFile;
  }

  // Pick a PDF file
  Future<File?> pickPDF() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.isEmpty) return null;

    final file = File(result.files.first.path!);
    if (!file.path.toLowerCase().endsWith('.pdf')) {
      throw Exception('Selected file is not a PDF');
    }

    return file;
  }
}
