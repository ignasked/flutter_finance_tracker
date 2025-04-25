// import 'dart:convert';
// import 'dart:io';
// import 'package:image_picker/image_picker.dart';
// import 'package:http/http.dart' as http;
// import 'package:pvp_projektas/config/env.dart';
// import 'package:flutter_image_compress/flutter_image_compress.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:file_picker/file_picker.dart';

// class MistralService {
//   static const String _baseUrl = 'https://api.mistral.ai/v1';
//   final String _apiKey;

//   MistralService._() : _apiKey = Env.mistralApiKey;

//   static final MistralService instance = MistralService._();

//   factory MistralService() => instance;

//   Future<String> analyzeImage(File imageFile) async {
//     try {
//       print('Reading image file...'); // Debug log
//       final bytes = await imageFile.readAsBytes();
//       final base64Image = base64Encode(bytes);
//       print(
//           'Image converted to base64, size: ${bytes.length} bytes'); // Debug log

//       final url = Uri.parse('$_baseUrl/ocr');
//       final headers = {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//         'Authorization': 'Bearer $_apiKey',
//       };

//       final body = jsonEncode({
//         'model': 'mistral-ocr-latest',
//         'document': {
//           'type': 'image_url',
//           'image_url': 'data:image/jpeg;base64,$base64Image',
//         },
//       });

//       print('Sending request to Mistral OCR API...'); // Debug log
//       final response = await http.post(url, headers: headers, body: body);
//       print('Response status code: ${response.statusCode}'); // Debug log

//       if (response.statusCode != 200) {
//         print('Error response: ${response.body}'); // Debug log
//         throw Exception(
//             'OCR API request failed with status: ${response.statusCode}');
//       }

//       final jsonResponse = jsonDecode(response.body);
//       // final content = jsonResponse[
//       //     'text']; // OCR response contains extracted text in 'text' field

//       // if (content == null || content.isEmpty) {
//       //   throw Exception('No text extracted from image');
//       // }

//       print('Successfully extracted text from image'); // Debug log
//       return response.body; // Return the full response for debugging
//     } catch (e) {
//       print('Error during OCR: $e'); // Debug log
//       throw Exception('Failed to perform OCR: $e');
//     }
//   }

//   Future<String> getChatResponse(String prompt) async {
//     try {
//       final url = Uri.parse('$_baseUrl/chat/completions');
//       final response = await http.post(
//         url,
//         headers: {
//           'Content-Type': 'application/json',
//           'Authorization': 'Bearer $_apiKey',
//         },
//         body: jsonEncode({
//           'model': 'mistral-medium',
//           'messages': [
//             {
//               'role': 'user',
//               'content': prompt,
//             }
//           ],
//           'temperature': 0.7,
//         }),
//       );

//       if (response.statusCode != 200) {
//         throw Exception('Failed to get chat response: ${response.body}');
//       }

//       final jsonResponse = jsonDecode(response.body);
//       return jsonResponse['choices'][0]['message']['content'] ?? '';
//     } catch (e) {
//       throw Exception('Failed to get chat response: $e');
//     }
//   }

//   Future<File?> pickImage({bool fromGallery = false}) async {
//     try {
//       final picker = ImagePicker();
//       final XFile? image = await picker.pickImage(
//         source: fromGallery ? ImageSource.gallery : ImageSource.camera,
//         imageQuality: 85,
//         maxWidth: 1280,
//         maxHeight: 1280,
//         preferredCameraDevice: CameraDevice.rear,
//         requestFullMetadata: false,
//       );

//       if (image == null) return null;

//       // Compress the image to reduce HDR metadata issues
//       final bytes = await image.readAsBytes();
//       final compressedBytes = await FlutterImageCompress.compressWithList(
//         bytes,
//         quality: 85,
//         format: CompressFormat.jpeg,
//       );

//       // Create a new compressed file
//       final tempDir = await getTemporaryDirectory();
//       final tempFile = File('${tempDir.path}/compressed_receipt.jpg');
//       await tempFile.writeAsBytes(compressedBytes);

//       return tempFile;
//     } catch (e) {
//       print('Error picking/processing image: $e');
//       return null;
//     }
//   }

//   Future<File?> pickPDF() async {
//     try {
//       final result = await FilePicker.platform.pickFiles(
//         type: FileType.custom,
//         allowedExtensions: ['pdf'],
//       );

//       if (result == null || result.files.isEmpty) {
//         print('No PDF file selected');
//         return null;
//       }

//       final file = File(result.files.first.path!);

//       // Verify it's a PDF
//       if (!file.path.toLowerCase().endsWith('.pdf')) {
//         throw Exception('Selected file is not a PDF');
//       }

//       return file;
//     } catch (e) {
//       print('Error picking PDF: $e');
//       return null;
//     }
//   }

//   Future<String> analyzePDF(File pdfFile) async {
//     try {
//       print('Reading PDF file...'); // Debug log
//       final bytes = await pdfFile.readAsBytes();
//       final base64PDF = base64Encode(bytes);
//       print(
//           'PDF converted to base64, size: ${bytes.length} bytes'); // Debug log

//       final url = Uri.parse('$_baseUrl/ocr');
//       final headers = {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//         'Authorization': 'Bearer $_apiKey',
//       };

//       final body = jsonEncode({
//         'model': 'mistral-ocr-latest',
//         'document': {
//           'type': 'document_url',
//           'document_url': 'data:application/pdf;base64,$base64PDF',
//         },
//       });

//       print('Sending request to Mistral OCR API...'); // Debug log
//       final response = await http.post(url, headers: headers, body: body);
//       print('Response status code: ${response.statusCode}'); // Debug log

//       if (response.statusCode != 200) {
//         print('Error response: ${response.body}'); // Debug log
//         throw Exception(
//             'OCR API request failed with status: ${response.statusCode}');
//       }
//       print('Response body: ${response.body}'); // Debug log
//       final jsonResponse = jsonDecode(response.body);

//       // Extract Markdown text from the response
//       final pages = jsonResponse['pages'] as List;
//       final markdownTexts =
//           pages.map((page) => page['markdown'] as String).join('\n\n');

//       print('Successfully extracted Markdown text from PDF'); // Debug log
//       return markdownTexts;
//     } catch (e) {
//       print('Error during PDF OCR: $e'); // Debug log
//       throw Exception('Failed to perform PDF OCR: $e');
//     }
//   }

//   Future<Map<String, dynamic>> analyzeAndFormatPDF(File pdfFile,
//       {bool useSavedData = false}) async {
//     if (useSavedData) {
//       // Try to load saved data
//       final savedData = await loadSavedApiOutput();
//       if (savedData != null) {
//         print('Using saved API output.');
//         return savedData;
//       } else {
//         print('No saved data found. Falling back to API call.');
//       }
//     }

//     // Proceed with the API call if no saved data is available
//     try {
//       // Step 1: Extract OCR data
//       print('Reading PDF file...'); // Debug log
//       final bytes = await pdfFile.readAsBytes();
//       final base64PDF = base64Encode(bytes);
//       print(
//           'PDF converted to base64, size: ${bytes.length} bytes'); // Debug log

//       final ocrUrl = Uri.parse('$_baseUrl/ocr');
//       final ocrHeaders = {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//         'Authorization': 'Bearer $_apiKey',
//       };

//       final ocrBody = jsonEncode({
//         'model': 'mistral-ocr-latest',
//         'document': {
//           'type': 'document_url',
//           'document_url': 'data:application/pdf;base64,$base64PDF',
//         },
//       });

//       print('Sending request to Mistral OCR API...'); // Debug log
//       final ocrResponse =
//           await http.post(ocrUrl, headers: ocrHeaders, body: ocrBody);
//       print('OCR Response status code: ${ocrResponse.statusCode}'); // Debug log

//       if (ocrResponse.statusCode != 200) {
//         print('Error response: ${ocrResponse.body}'); // Debug log
//         throw Exception(
//             'OCR API request failed with status: ${ocrResponse.statusCode}');
//       }
//       print(ocrResponse.body); // Debug log

//       // Decode the OCR response body
//       final ocrResponseBody = utf8.decode(ocrResponse.bodyBytes);
//       final ocrJsonResponse = jsonDecode(ocrResponseBody);
//       final pages = ocrJsonResponse['pages'] as List;
//       final markdownTexts =
//           pages.map((page) => page['markdown'] as String).join('\n\n');

//       print('Successfully extracted Markdown text from PDF'); // Debug log

//       // Step 2: Send OCR data to LLM for formatting
//       final llmUrl = Uri.parse('$_baseUrl/chat/completions');
//       final llmHeaders = {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $_apiKey',
//       };

//       final llmPrompt = '''
// This is the OCR data in Markdown format:
// $markdownTexts

// First, apply discounts to the prices of each item in the list. Then,
// convert into a structured JSON response.
// - Ensure the JSON is valid and well-formatted.
// - Return the data in a JSON format with the following structure:
// {
//   "transactionName": "string",
//   "transactions": [
//     {
//       "description": "string",
//       "category": "string",
//       "price": "number"
//     }
//   ]
// }
// - category should be one of the following: "food", "transportation", "entertainment", "utilities", "healthcare", "clothing", "other"
// - Don't include any other text or explanations, just the JSON response.
// ''';

//       final llmBody = jsonEncode({
//         'model': 'mistral-medium',
//         'messages': [
//           {
//             'role': 'user',
//             'content': llmPrompt,
//           }
//         ],
//         'temperature': 0,
//       });

//       print('Sending request to LLM API...'); // Debug log
//       final llmResponse =
//           await http.post(llmUrl, headers: llmHeaders, body: llmBody);
//       print('LLM Response status code: ${llmResponse.statusCode}'); // Debug log

//       if (llmResponse.statusCode != 200) {
//         print('Error response: ${llmResponse.body}'); // Debug log
//         throw Exception(
//             'LLM API request failed with status: ${llmResponse.statusCode}');
//       }

//       // Decode the LLM response body
//       final llmResponseBody = utf8.decode(llmResponse.bodyBytes);
//       final llmJsonResponse = jsonDecode(llmResponseBody);
//       var structuredData = llmJsonResponse['choices'][0]['message']['content'];

//       print('Raw Structured Data: $structuredData'); // Debug log

//       // Clean up the response
//       final cleanedData =
//           structuredData.trim().replaceAll('```json', '').replaceAll('```', '');
//       print('Cleaned Data: $cleanedData'); // Debug log

//       // Parse the cleaned JSON
//       final parsedData = jsonDecode(cleanedData);

//       // Save the API output after a successful call
//       await saveApiOutput(parsedData);

//       // Validate and extract transactions
//       if (parsedData is Map<String, dynamic> &&
//           parsedData.containsKey('transactions') &&
//           parsedData['transactions'] is List) {
//         return parsedData;
//       } else {
//         throw Exception('Invalid response format: Missing transactions');
//       }
//     } catch (e) {
//       print('Error during PDF OCR and formatting: $e'); // Debug log
//       throw Exception('Failed to process and format PDF: $e');
//     }
//   }

//   Future<Map<String, dynamic>> analyzeAndFormatImage(File imageFile,
//       {bool useSavedData = false}) async {
//     if (useSavedData) {
//       // Try to load saved data
//       final savedData = await loadSavedApiOutput();
//       if (savedData != null) {
//         print('Using saved API output.');
//         return savedData;
//       } else {
//         print('No saved data found. Falling back to API call.');
//       }
//     }

//     try {
//       // Step 1: Convert image to base64
//       print('Reading image file...'); // Debug log
//       final bytes = await imageFile.readAsBytes();
//       final base64Image = base64Encode(bytes);
//       print(
//           'Image converted to base64, size: ${bytes.length} bytes'); // Debug log

//       // Step 2: Send image to OCR API
//       final ocrUrl = Uri.parse('$_baseUrl/ocr');
//       final ocrHeaders = {
//         'Content-Type': 'application/json',
//         'Accept': 'application/json',
//         'Authorization': 'Bearer $_apiKey',
//       };

//       final ocrBody = jsonEncode({
//         'model': 'mistral-ocr-latest',
//         'document': {
//           'type': 'image_url',
//           'image_url': 'data:image/jpeg;base64,$base64Image',
//         },
//       });

//       print('Sending request to Mistral OCR API...'); // Debug log
//       final ocrResponse =
//           await http.post(ocrUrl, headers: ocrHeaders, body: ocrBody);
//       print('OCR Response status code: ${ocrResponse.statusCode}'); // Debug log

//       if (ocrResponse.statusCode != 200) {
//         print('Error response: ${ocrResponse.body}'); // Debug log
//         throw Exception(
//             'OCR API request failed with status: ${ocrResponse.statusCode}');
//       }
//       print(ocrResponse.body); // Debug log

//       // Decode the OCR response body
//       final ocrResponseBody = utf8.decode(ocrResponse.bodyBytes);
//       final ocrJsonResponse = jsonDecode(ocrResponseBody);
//       final pages = ocrJsonResponse['pages'] as List;
//       final markdownTexts =
//           pages.map((page) => page['markdown'] as String).join('\n\n');

//       print('Successfully extracted Markdown text from image'); // Debug log

//       // Step 3: Send OCR data to LLM for formatting
//       final llmUrl = Uri.parse('$_baseUrl/chat/completions');
//       final llmHeaders = {
//         'Content-Type': 'application/json',
//         'Authorization': 'Bearer $_apiKey',
//       };

//       final llmPrompt = '''
// This is the OCR data in Markdown format:
// $markdownTexts

// First, apply discounts to the prices of each item in the list. Then,
// convert into a structured JSON response.
// - Ensure the JSON is valid and well-formatted.
// - Return the data in a JSON format with the following structure:
// {
//   "transactionName": "string",
//   "transactions": [
//     {
//       "description": "string",
//       "category": "string",
//       "price": "number"
//     }
//   ]
// }
// - Category should be one of the following: "food", "transportation", "entertainment", "utilities", "healthcare", "clothing", "other"
// - Don't include any other text or explanations, just the JSON response.
// ''';

//       final llmBody = jsonEncode({
//         'model': 'mistral-medium',
//         'messages': [
//           {
//             'role': 'user',
//             'content': llmPrompt,
//           }
//         ],
//         'temperature': 0,
//         'include_image_base64': false,
//       });

//       print('Sending request to LLM API...'); // Debug log
//       final llmResponse =
//           await http.post(llmUrl, headers: llmHeaders, body: llmBody);
//       print('LLM Response status code: ${llmResponse.statusCode}'); // Debug log

//       if (llmResponse.statusCode != 200) {
//         print('Error response: ${llmResponse.body}'); // Debug log
//         throw Exception(
//             'LLM API request failed with status: ${llmResponse.statusCode}');
//       }

//       // Decode the LLM response body
//       final llmResponseBody = utf8.decode(llmResponse.bodyBytes);
//       final llmJsonResponse = jsonDecode(llmResponseBody);
//       var structuredData = llmJsonResponse['choices'][0]['message']['content'];

//       print('Raw Structured Data: $structuredData'); // Debug log

//       // Clean up the response
//       final cleanedData =
//           structuredData.trim().replaceAll('```json', '').replaceAll('```', '');
//       print('Cleaned Data: $cleanedData'); // Debug log

//       // Parse and validate the cleaned JSON
//       final parsedData = _validateAndExtractData(cleanedData);

//       // Save the API output after a successful call
//       await saveApiOutput(parsedData);

//       return parsedData;
//     } catch (e) {
//       print('Error during image OCR and formatting: $e'); // Debug log
//       throw Exception('Failed to process and format image: $e');
//     }
//   }

//   // Save the API output to a local file
//   Future<void> saveApiOutput(Map<String, dynamic> data) async {
//     try {
//       final directory = await getApplicationDocumentsDirectory();
//       final file = File('${directory.path}/mistral_output.json');
//       await file.writeAsString(jsonEncode(data));
//       print('API output saved to ${file.path}');
//     } catch (e) {
//       print('Error saving API output: $e');
//     }
//   }

//   // Load the saved API output from the local file
//   Future<Map<String, dynamic>?> loadSavedApiOutput() async {
//     try {
//       final directory = await getApplicationDocumentsDirectory();
//       final file = File('${directory.path}/mistral_output.json');
//       if (await file.exists()) {
//         final content = await file.readAsString();
//         return jsonDecode(content) as Map<String, dynamic>;
//       } else {
//         print('No saved API output found.');
//         return null;
//       }
//     } catch (e) {
//       print('Error loading saved API output: $e');
//       return null;
//     }
//   }

//   // Validate and extract data from cleaned JSON
//   Map<String, dynamic> _validateAndExtractData(String jsonString) {
//     try {
//       final parsedData = jsonDecode(jsonString);

//       // Ensure the response contains the expected fields
//       if (parsedData is Map<String, dynamic> &&
//           parsedData.containsKey('transactionName') &&
//           parsedData.containsKey('transactions') &&
//           parsedData['transactions'] is List) {
//         return {
//           'transactionName': parsedData['transactionName'],
//           'transactions': parsedData['transactions'],
//         };
//       } else {
//         throw Exception('Invalid response format: Missing required fields');
//       }
//     } catch (e) {
//       throw Exception('Failed to validate and extract data: $e');
//     }
//   }
// }
