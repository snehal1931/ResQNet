import 'dart:convert';
import 'ml_model.dart';

class ScoreResult {
  final double priorityScore;
  final String severity;
  final double confidenceScore;
  final String explanation; // JSON String of attribution list

  ScoreResult({
    required this.priorityScore,
    required this.severity,
    required this.confidenceScore,
    required this.explanation,
  });
}

class AIScorer {
  Future<void> loadModel() async {
    print('Static Multi-Modal Prioritization Model and Random Forest NLP initialized.');
  }

  ScoreResult calculatePriority({
    required String content,
    required String disasterType,
    required String injurySeverity,
    required int headcount,
    required String connectivityStatus,
  }) {
    double scoreVal = 10.0; // Base score
    List<Map<String, dynamic>> attributions = [
      {'factor': 'Base risk baseline', 'impact': 10.0}
    ];

    // 1. Text distress parsing with NLP Random Forest
    var words = content.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').split(' ');
    List<double> features = List.filled(24, 0.0);
    List<String> matchedKeywords = [];
    for (var w in words) {
      if (modelVocabulary.containsKey(w)) {
        features[modelVocabulary[w]!] += 1.0;
        if (!matchedKeywords.contains(w)) matchedKeywords.add(w);
      }
    }

    List<double> textScores = score(features);
    
    // Argmax text prediction
    int maxIndex = 0;
    for (int i = 1; i < textScores.length; i++) {
      if (textScores[i] > textScores[maxIndex]) {
        maxIndex = i;
      }
    }
    String predictedTextSeverity = classes[maxIndex];
    double confidence = textScores[maxIndex];

    double nlpImpact = 0.0;
    if (predictedTextSeverity == 'CRITICAL') {
      nlpImpact = 25.0;
    } else if (predictedTextSeverity == 'HIGH') {
      nlpImpact = 15.0;
    } else {
      nlpImpact = 5.0;
    }
    scoreVal += nlpImpact;
    
    String matchedKeywordsStr = matchedKeywords.isNotEmpty ? " (keywords: ${matchedKeywords.join(', ')})" : "";
    attributions.add({
      'factor': 'Text Analysis: $predictedTextSeverity priority signal$matchedKeywordsStr',
      'impact': nlpImpact
    });

    // 2. Injury Severity Weights
    double injuryImpact = 0.0;
    switch (injurySeverity.toUpperCase()) {
      case 'CRITICAL':
      case 'LIFE-THREATENING':
        injuryImpact = 35.0;
        break;
      case 'HIGH':
      case 'SERIOUS':
        injuryImpact = 20.0;
        break;
      case 'MEDIUM':
      case 'MODERATE':
        injuryImpact = 10.0;
        break;
      case 'LOW':
      case 'MINOR':
      default:
        injuryImpact = 2.0;
        break;
    }
    scoreVal += injuryImpact;
    attributions.add({
      'factor': 'Injury Severity: $injurySeverity',
      'impact': injuryImpact
    });

    // 3. Headcount Impact
    double headcountImpact = (headcount * 5.0).clamp(0.0, 25.0);
    scoreVal += headcountImpact;
    attributions.add({
      'factor': 'Affected People: $headcount ${headcount == 1 ? 'person' : 'people'}',
      'impact': headcountImpact
    });

    // 4. Disaster Type Weights
    double disasterImpact = 5.0;
    if (['FLOOD', 'FIRE', 'EARTHQUAKE', 'BUILDING COLLAPSE', 'COLLAPSE'].contains(disasterType.toUpperCase())) {
      disasterImpact = 10.0;
    } else if (['MEDICAL', 'GAS LEAK', 'BLEEDING'].contains(disasterType.toUpperCase())) {
      disasterImpact = 8.0;
    }
    scoreVal += disasterImpact;
    attributions.add({
      'factor': 'Disaster Type: $disasterType',
      'impact': disasterImpact
    });

    // 5. Connectivity Weights
    double connectivityImpact = 0.0;
    if (connectivityStatus.toLowerCase().contains('offline') || connectivityStatus.toLowerCase().contains('mesh')) {
      connectivityImpact = 5.0;
      scoreVal += connectivityImpact;
      attributions.add({
        'factor': 'Connectivity Isolation (Mesh Network)',
        'impact': connectivityImpact
      });
    }

    // Clamp score to 100
    double finalScore = scoreVal.clamp(0.0, 100.0);

    // Determine final category
    String finalSeverity = 'LOW';
    if (finalScore >= 75.0) {
      finalSeverity = 'CRITICAL';
    } else if (finalScore >= 50.0) {
      finalSeverity = 'HIGH';
    } else if (finalScore >= 25.0) {
      finalSeverity = 'MEDIUM';
    } else {
      finalSeverity = 'LOW';
    }

    return ScoreResult(
      priorityScore: finalScore,
      severity: finalSeverity,
      confidenceScore: confidence,
      explanation: jsonEncode(attributions),
    );
  }

  // Backwards compatibility method
  String scoreSignal(String content) {
    try {
      final res = calculatePriority(
        content: content,
        disasterType: 'Other',
        injurySeverity: 'Low',
        headcount: 1,
        connectivityStatus: 'Offline',
      );
      return res.severity;
    } catch (e) {
      print('Error scoring text: $e');
      return 'LOW';
    }
  }
}
