import 'package:flutter/foundation.dart';

enum NotificationDestination {
  prayer,
  morningAdhkar,
  eveningAdhkar,
  quran,
  memorization,
  review,
  khatma,
  dailyIslamic,
}

NotificationDestination? destinationForNotificationPayload(String payload) {
  if (payload.startsWith('prayer:') || payload == 'prayer') {
    return NotificationDestination.prayer;
  }
  return switch (payload) {
    'adhkar:morning' => NotificationDestination.morningAdhkar,
    'adhkar:evening' => NotificationDestination.eveningAdhkar,
    'quran' => NotificationDestination.quran,
    'memorization' => NotificationDestination.memorization,
    'memorization:review' => NotificationDestination.review,
    'khatma' => NotificationDestination.khatma,
    'daily' => NotificationDestination.dailyIslamic,
    _ => null,
  };
}

class NotificationRouteCoordinator extends ChangeNotifier {
  NotificationDestination? _pending;
  void Function(NotificationDestination destination)? _handler;

  NotificationDestination? get pending => _pending;

  void receivePayload(String payload) {
    final destination = destinationForNotificationPayload(payload);
    if (destination == null) return;
    final handler = _handler;
    if (handler == null) {
      _pending = destination;
      notifyListeners();
      return;
    }
    handler(destination);
  }

  void attach(void Function(NotificationDestination destination) handler) {
    _handler = handler;
    final pending = _pending;
    _pending = null;
    if (pending != null) handler(pending);
  }

  void detach() => _handler = null;
}
