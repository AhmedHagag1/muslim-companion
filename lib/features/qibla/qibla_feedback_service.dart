import 'package:flutter/services.dart';

abstract interface class QiblaFeedbackService {
  Future<void> alignmentEntered();
}

class SystemQiblaFeedbackService implements QiblaFeedbackService {
  const SystemQiblaFeedbackService();

  @override
  Future<void> alignmentEntered() => HapticFeedback.selectionClick();
}
