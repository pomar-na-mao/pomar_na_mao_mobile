import 'package:flutter/foundation.dart';

class AppLoadingController extends ChangeNotifier {
  var _pendingOperations = 0;

  bool get isLoading => _pendingOperations > 0;

  Future<T> track<T>(Future<T> Function() operation) async {
    _pendingOperations += 1;
    notifyListeners();

    try {
      return await operation();
    } finally {
      _pendingOperations -= 1;
      notifyListeners();
    }
  }
}
