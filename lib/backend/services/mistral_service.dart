import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:money_owl/config/env.dart';
import 'package:path_provider/path_provider.dart';
import 'package:money_owl/utils/receipt_format.dart';
import 'package:money_owl/backend/models/transaction.dart'; // Import your Transaction model

class MistralService {
  static const String _baseUrl = 'https://api.mistral.ai/v1';
  final String _apiKey;

  MistralService._() : _apiKey = Env.mistralApiKey;

  static final MistralService instance = MistralService._();

  // Helper method to make API calls
  Future<http.Response> _postRequest(
      String endpoint, Map<String, dynamic> body) async {
    final url = Uri.parse('$_baseUrl/$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    return await http.post(url, headers: headers, body: jsonEncode(body));
  }

  // OCR Methods
  Future<String> analyzeImage(File imageFile) async {
    final base64Image = await _encodeFileToBase64(imageFile);
    final response = await _postRequest('ocr', {
      'model': 'mistral-ocr-latest',
      'document': {
        'type': 'image_url',
        'image_url': 'data:image/jpeg;base64,$base64Image',
      },
    });

    if (response.statusCode != 200) {
      throw Exception(
          'OCR API request failed: ${response.body} /n Status code: ${response.statusCode}');
    }

    return response.body;
  }

  Future<String> analyzePDF(File pdfFile) async {
    final base64PDF = await _encodeFileToBase64(pdfFile);
    final response = await _postRequest('ocr', {
      'model': 'mistral-ocr-latest',
      'document': {
        'type': 'document_url',
        'document_url': 'data:application/pdf;base64,$base64PDF',
      },
    });

    if (response.statusCode != 200) {
      throw Exception(
          'OCR API request failed: ${response.body} /n Status code: ${response.statusCode}');
    }

    return response.body;
  }

  // Analyze and format data
  Future<Map<String, dynamic>> analyzeAndFormat(
      File file, ReceiptFormat format, String enabledCategoryTitles) async {
    final base64File = await _encodeFileToBase64(file);
    final ocrResponse = await _postRequest('ocr', {
      'model': 'mistral-ocr-latest',
      'document': {
        'type': format.documentType,
        'document_url': 'data:${format.mimeType};base64,$base64File',
      },
    });

    if (ocrResponse.statusCode != 200) {
      throw Exception('OCR API request failed: ${ocrResponse.body}');
    }

    final ocrResponseBody = utf8.decode(ocrResponse.bodyBytes);
    final ocrJsonResponse = jsonDecode(ocrResponseBody);
    final pages = ocrJsonResponse['pages'] as List;
    final markdownTexts =
        pages.map((page) => page['markdown'] as String).join('\n\n');

    final llmResponse = await _postRequest('chat/completions', {
      'model': 'mistral-medium',
      'messages': [
        {
          'role': 'user',
          'content': '''
This is the OCR data in Markdown format:
$markdownTexts

First, apply discounts to the prices of each item in the list. Then,
convert into a structured JSON response.
- Don't include any other text or explanations, just the JSON response.
- Ensure the JSON is valid and well-formatted.
- Return the data in a JSON format with the following structure:
{
  "transactionName": "string",
  "date": "string",
  "transactions": [
    {
      "title": "string",
      "category": "string",
      "amount": "number"
    }
  ]
}
- category should be one of the following enabled categories: $enabledCategoryTitles
- transactionName should be the name of the shop or service where the transaction took place.
''',
        }
      ],
      'temperature': 0,
    });

    if (llmResponse.statusCode != 200) {
      throw Exception(
          'LLM API request failed: ${llmResponse.body} /n Status code: ${llmResponse.statusCode}');
    }

    final llmResponseBody = utf8.decode(llmResponse.bodyBytes);
    final llmJsonResponse = jsonDecode(llmResponseBody);
    final rawContent =
        llmJsonResponse['choices'][0]['message']['content'].trim();

    final json = _extractJson(rawContent);
    final parsedData = _validateAndExtractData(json);
    await saveApiOutput(parsedData);

    return parsedData;
  }

  // Utility Methods
  Future<String> _encodeFileToBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  // TODO: Remove. Just for testing purposes
  Future<void> saveApiOutput(Map<String, dynamic> data) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/mistral_output.json');
    await file.writeAsString(jsonEncode(data));
  }

  // TODO: Remove. Just for testing purposes
  Future<Map<String, dynamic>?> loadSavedApiOutput() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/mistral_output.json');
    if (await file.exists()) {
      try {
        final content = await file.readAsString();
        return jsonDecode(content) as Map<String, dynamic>;
      } catch (e) {
        print('Error decoding JSON: $e');
        return null;
      }
    }
    return null;
  }

  String _extractJson(String rawContent) {
    // Extract only the JSON part
    final jsonStartIndex = rawContent.indexOf('{');
    final jsonEndIndex = rawContent.lastIndexOf('}');
    if (jsonStartIndex == -1 || jsonEndIndex == -1) {
      throw Exception('Invalid response format: JSON not found in response');
    }

    final jsonString = rawContent.substring(jsonStartIndex, jsonEndIndex + 1);

    // Validate and parse the JSON
    return jsonString;
  }

  // Validate and extract data from the JSON response
  Map<String, dynamic> _validateAndExtractData(String jsonString) {
    final parsedData = jsonDecode(jsonString);

    // Extract transactionName
    final transactionName =
        parsedData['transactionName'] ?? 'Unnamed Transaction';

    // Extract and validate transactions
    final transactions = (parsedData['transactions'] as List<dynamic>)
        .map((transaction) => Transaction.fromJson(transaction))
        .toList();

    return {
      'transactionName': transactionName,
      'transactions': transactions,
    };
  }
}
