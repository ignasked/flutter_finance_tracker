/// Enum representing different formats of receipts.
/// This enum is used to specify the format of a receipt, which can be either an image or a PDF.
enum ReceiptFormat {
  image,
  pdf,
}

/// Extension on [ReceiptFormat] to provide additional functionality.
/// This extension adds methods to get the MIME type and document type
/// based on the receipt format.
/// It is useful for handling different formats of receipts in a consistent way.
extension ReceiptFormatExtension on ReceiptFormat {
  /// Returns the MIME type associated with the receipt format.
  String get mimeType {
    switch (this) {
      case ReceiptFormat.image:
        return 'image/jpeg';
      case ReceiptFormat.pdf:
        return 'application/pdf';
    }
  }

  /// Returns the document type associated with the receipt format.
  String get documentType {
    switch (this) {
      case ReceiptFormat.image:
        return 'image_url';
      case ReceiptFormat.pdf:
        return 'document_url';
    }
  }
}
