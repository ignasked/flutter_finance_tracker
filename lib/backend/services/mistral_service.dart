import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:money_owl/config/env.dart';
import 'package:path_provider/path_provider.dart';
import 'package:money_owl/backend/utils/receipt_format.dart';
// Import your Transaction model

class MistralService {
  static const String _baseUrl = 'https://api.mistral.ai/v1';
  final String _apiKey;

  MistralService._() : _apiKey = Env.mistralApiKey;

  static final MistralService instance = MistralService._();

  Future<String> provideFinancialAnalysis(String data) async {
    final llmResponseText = await _askLLMForAnalysis(data);
    final rawContent =
        jsonDecode(llmResponseText)['choices'][0]['message']['content'].trim();

    return rawContent;
  }

  Future<Map<String, dynamic>> processReceiptAndExtractTransactions(
      File receiptFile,
      ReceiptFormat receiptFormat,
      String categoryMappings) async {
    final encodedReceipt = await _encodeFileToBase64(receiptFile);
    final ocrResultText = await _performOCR(encodedReceipt, receiptFormat);

    final parsedOcrResult = jsonDecode(ocrResultText);
    final extractedPages = parsedOcrResult['pages'] as List;
    final markdownTexts =
        extractedPages.map((page) => page['markdown'] as String).join('\n\n');

    final llmResponseText =
        await _processWithLLM(markdownTexts, categoryMappings);
    final rawContent =
        jsonDecode(llmResponseText)['choices'][0]['message']['content'].trim();

    final json = _extractJson(rawContent);

    await saveApiOutput(json);

    return json;
  }

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

  Future<String> _performOCR(
      String encodedReceipt, ReceiptFormat receiptFormat) async {
    String keyForFileURL = '';
    if (receiptFormat == ReceiptFormat.image) {
      keyForFileURL = 'image_url';
    } else if (receiptFormat == ReceiptFormat.pdf) {
      keyForFileURL = 'document_url';
    } else {
      throw Exception('Unsupported receipt format: $receiptFormat');
    }

    final ocrResult = await _postRequest('ocr', {
      'model': 'mistral-ocr-latest',
      'document': {
        'type': receiptFormat.documentType,
        keyForFileURL: 'data:${receiptFormat.mimeType};base64,$encodedReceipt',
      },
    });

    if (ocrResult.statusCode != 200) {
      throw Exception('OCR API request failed: ${ocrResult.body}');
    }

    return utf8.decode(ocrResult.bodyBytes);
  }

  Future<String> _processWithLLM(
      String markdownTexts, String categoryMappings) async {
    final llmResponse = await _postRequest('chat/completions', {
      'model': 'mistral-small-latest',
      'messages': [
        {
          'role': 'user',
          'content': '''
- You are a receipt analyzer.
- You will receive OCR data from receipt in Markdown format.
- In your response don't include any other text or explanations, just the JSON response.
- Ensure the JSON is valid and well-formatted.
- Use the following categories: $categoryMappings
- transactionName should be the name of the shop or service where the transaction took place.
- totalName should be the total amount of the receipt.
- date should be in YYYY-MM-DD format.
- for totalAmountPaid field just extract how much money was paid from the receipt ORC markdown (don't calculate yourself). The value should be extracted from total paid amount row.
- for title of transactions try to fix any typos and simplify the name but do it in the original language.
- Return the data in a JSON format with the following structure:
{
  "transactionName": "string",
  "date": "string",
  "totalAmountPaid": "number",
  "transactions": [
    {
      "title": "string",
      "category": "string",
      "amount": "number"
    }
  ]
}

This is the OCR data in Markdown format:
$markdownTexts
''',
        }
      ],
      'temperature': 0.7,
    });

    if (llmResponse.statusCode != 200) {
      throw Exception(
          'LLM API request failed: ${llmResponse.body} /n Status code: ${llmResponse.statusCode}');
    }

    return utf8.decode(llmResponse.bodyBytes);
  }

  Future<String> _askLLMForAnalysis(String markdownTexts) async {
    final llmResponse = await _postRequest('chat/completions', {
      'model': 'mistral-large-latest',
      'messages': [
        {
          'role': 'user',
          'content': '''
- You are the best personal finance analyst.
- You need to povide personalized suggestions how to improve my finances.
- Don't tell me about total balance or total income or expenses.
- Don't include beginning text like "Based on the provided transaction data..." and etc. Go straight to the point.

These are the transactions I made:
$markdownTexts
''',
        }
      ],
      'temperature': 0.7,
    });

    if (llmResponse.statusCode != 200) {
      throw Exception(
          'LLM API request failed: ${llmResponse.body} /n Status code: ${llmResponse.statusCode}');
    }

    return utf8.decode(llmResponse.bodyBytes);
  }

  // Utility Methods

  Future<void> saveApiOutput(Map<String, dynamic> data) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/mistral_output.json');
    await file.writeAsString(jsonEncode(data));
  }

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

  Future<String> _encodeFileToBase64(File file) async {
    final bytes = await file.readAsBytes();
    return base64Encode(bytes);
  }

  Map<String, dynamic> _extractJson(String rawContent) {
    // Extract only the JSON part
    final jsonStartIndex = rawContent.indexOf('{');
    final jsonEndIndex = rawContent.lastIndexOf('}');
    if (jsonStartIndex == -1 || jsonEndIndex == -1) {
      throw Exception('Invalid response format: JSON not found in response');
    }

    final jsonString = rawContent.substring(jsonStartIndex, jsonEndIndex + 1);

    // Parse and return the JSON
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to parse JSON: $e');
    }
  }
}
