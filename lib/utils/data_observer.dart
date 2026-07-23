import 'package:flutter/foundation.dart';

import '../models/saved_place.dart';
import '../models/trusted_source.dart';

typedef TrustedSourceObserver = DataObserver<TrustedSource>;
typedef SavedPlaceObserver = DataObserver<SavedPlace>;

class DataObserver<T> {
  static final Map<Type, DataObserver<dynamic>> _instances = {};

  final ValueNotifier<int> _notifier = ValueNotifier<int>(0);
  T? _data;

  DataObserver._internal();

  factory DataObserver() {
    return _instances.putIfAbsent(T, () => DataObserver<T>._internal())
        as DataObserver<T>;
  }

  T? get data => _data;

  set data(T? newData) {
    _data = newData;
    _notifier.value++;
  }
  /* 
  void notifyListeners() {
    if (_data != null) {
      _notifier.value++;
    }
  } */

  void addListener(VoidCallback listener) {
    _notifier.addListener(listener);
  }

  void removeListener(VoidCallback listener) {
    _notifier.removeListener(listener);
  }

  Future<void> refresh(Future<void> Function() refreshCallback) async {
    await refreshCallback();
    _notifier.value++;
  }
}
