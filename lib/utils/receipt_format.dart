enum ReceiptFormat {
  image,
  pdf,
}

extension ReceiptFormatExtension on ReceiptFormat {
  String get mimeType {
    switch (this) {
      case ReceiptFormat.image:
        return 'image/jpeg';
      case ReceiptFormat.pdf:
        return 'application/pdf';
    }
  }

  String get documentType {
    switch (this) {
      case ReceiptFormat.image:
        return 'image_url';
      case ReceiptFormat.pdf:
        return 'document_url';
    }
  }
}
