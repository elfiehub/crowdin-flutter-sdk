import 'package:crowdin_sdk/src/crowdin_storage.dart';
import 'package:intl/intl.dart';

const int maxErrors = 10;
const int maxDaysInRow = 3;

class CrowdinRequestLimiter {
  CrowdinRequestLimiter._();

  static final CrowdinRequestLimiter _instance = CrowdinRequestLimiter._();

  factory CrowdinRequestLimiter() {
    return _instance;
  }

  late CrowdinStorage _storage;

  final DateFormat _formatter = DateFormat('yyyy-MM-dd');
  Map<String, int> _errorMap = {};
  bool _pauseRequests = false;
  bool _stopPermanently = false;

  bool get pauseRequests =>
      _stopPermanently || _pauseRequests || _checkIsPausedForToday();

  Future<void> init(CrowdinStorage storage) async {
    _storage = storage;
    _stopPermanently = await _storage.getIsPausedPermanently() ?? false;
    _errorMap = await _storage.getErrorMap() ?? {};
  }

  /// Checks if the requests should be paused for today based on the error count.
  bool _checkIsPausedForToday() {
    String currentDateString = _formatter.format(DateTime.now());
    if (_errorMap[currentDateString] != null &&
        _errorMap[currentDateString]! >= maxErrors) {
      _pauseRequests = true;
      return true;
    } else {
      _pauseRequests = false;
      return false;
    }
  }

  /// Increments the error counter for the current date.
  Future<void> incrementErrorCounter() async {
    DateFormat formatter = DateFormat('yyyy-MM-dd');
    String currentDateString = formatter.format(DateTime.now());
    if (_errorMap[currentDateString] != null) {
      if (_errorMap[currentDateString]! < maxErrors) {
        _errorMap[currentDateString] = _errorMap[currentDateString]! + 1;
      }
      if (_errorMap[currentDateString]! >= maxErrors) {
        await checkPausedDays(currentDateString);
      }
    } else {
      _errorMap[currentDateString] = 1;
    }
    await _storage.setErrorMap(await _cleanErrorMapFromUnusedDays());
  }

  Future<void> reset() async {
    if (!_stopPermanently) {
      _pauseRequests = false;
      _errorMap = {};
      await _storage.setErrorMap(_errorMap);
    }
  }

  /// Checks if the number of errors in the last `maxDaysInRow` days exceeds `maxErrors`.
  Future<void> checkPausedDays(String newDate) async {
    int daysInRow = 0;
    if (_errorMap.length >= maxDaysInRow) {
      DateTime currentDate = DateTime.parse(newDate);
      for (String date in _errorMap.keys) {
        if (DateTime.parse(date).isAfter(
                currentDate.add(const Duration(days: -maxDaysInRow))) &&
            _errorMap[date]! >= maxErrors) {
          daysInRow++;
          _pauseRequests = true;
        }
      }
      if (daysInRow >= maxDaysInRow) {
        _errorMap.clear();
        await _stopRequestsPermanently();
      }
    }
  }

  /// Cleans the error map from unused days, keeping only the last `maxDaysInRow` days.
  Future<Map<String, int>> _cleanErrorMapFromUnusedDays() async {
    DateTime currentDate = DateTime.now();
    _errorMap.removeWhere((date, _) {
      DateTime dateTime = DateTime.parse(date);
      return dateTime
          .isBefore(currentDate.subtract(const Duration(days: maxDaysInRow)));
    });
    await _storage.setErrorMap(_errorMap);
    return _errorMap;
  }

  /// Permanently stops requests by setting the pause flag and updating the storage.
  Future<void> _stopRequestsPermanently() async {
    _pauseRequests = true;
    _stopPermanently = true;
    await _storage.setIsPausedPermanently(true);
    await _storage.setErrorMap(_errorMap);
  }
}
