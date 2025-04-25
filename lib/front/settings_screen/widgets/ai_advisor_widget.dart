import 'package:flutter/material.dart';
import 'package:pvp_projektas/backend/services/mistral_service.dart';

class AIAdvisorWidget extends StatefulWidget {
  const AIAdvisorWidget({super.key});

  @override
  State<AIAdvisorWidget> createState() => _AIAdvisorWidgetState();
}

class _AIAdvisorWidgetState extends State<AIAdvisorWidget> {
  late MistralService _mistralService;
  String _response = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mistralService = MistralService();
  }

  Future<void> _testMistral() async {
    setState(() {
      _isLoading = true;
      _response = 'Testing Mistral API...';
    });

    try {
      // Test listing models
      final models = await _mistralService.listModels();
      String modelResponse = 'Available Models:\n${models.join("\n")}\n\n';

      // Test chat completion
      final chatResponse = await _mistralService.getChatResponse(
        'Hello! Give me a quick financial tip.',
      );

      setState(() {
        _response = '''
Models Test:
$modelResponse

Chat Test:
$chatResponse
''';
      });
    } catch (e) {
      setState(() {
        _response = 'Error testing Mistral API: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: _isLoading ? null : _testMistral,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Test Mistral API'),
          ),
          const SizedBox(height: 16),
          if (_response.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_response),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
