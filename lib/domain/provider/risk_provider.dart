import 'package:flutter/foundation.dart';
import '../../data/model/challenge.dart';
import '../../data/model/risk_assessment.dart';
import '../engine/risk_engine.dart';

class RiskProvider extends ChangeNotifier {
  final RiskEngine _engine = RiskEngine();
  final Map<String, RiskAssessment> _cache = {};

  RiskAssessment assess(Challenge challenge) {
    final result = _engine.assess(challenge);
    _cache[challenge.id] = result;
    return result;
  }

  RiskAssessment? getCached(String challengeId) => _cache[challengeId];

  void clearCache() {
    _cache.clear();
    notifyListeners();
  }
}
