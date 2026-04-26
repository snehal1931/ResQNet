import 'ml_model.dart';

class AIScorer {
  Future<void> loadModel() async {
    // Model is now statically compiled into Dart via ml_model.dart!
    print('Static Random Forest model ready');
  }

  String scoreSignal(String content) {
    try {
      return scoreDistressText(content);
    } catch (e) {
      print('Error scoring text: $e');
      return 'LOW'; // Fallback
    }
  }
}
