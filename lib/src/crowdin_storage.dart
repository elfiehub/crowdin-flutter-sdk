import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:crowdin_sdk/src/crowdin_logger.dart';
import 'package:crowdin_sdk/src/exceptions/crowdin_exceptions.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

const String _kCrowdinFolder = 'crowdin_translations';
const String _kTranslationTimestamp = 'translation_timestamp';
const String _kIsPausedPermanentlyFile = 'is_paused_permanently.json';
const String _kErrorMapFile = 'error_map.json';

class CrowdinStorage {
  CrowdinStorage();

  late Directory _storageDirectory;
  late SharedPreferences _sharedPrefs;

  Future<void> init() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    _storageDirectory = Directory(path.join(appDocDir.path, _kCrowdinFolder));

    // Create the directory if it doesn't exist
    if (!await _storageDirectory.exists()) {
      await _storageDirectory.create(recursive: true);
    }

    _sharedPrefs = await SharedPreferences.getInstance();
  }

  Future<void> setTranslationTimeStamp(int? timestamp) async {
    try {
      await _sharedPrefs.setInt(_kTranslationTimestamp, timestamp ?? 1);
    } catch (_) {
      throw CrowdinException("Can't store translation timestamp");
    }
  }

  int? getTranslationTimestamp() {
    try {
      int? translationTimestamp = _sharedPrefs.getInt(_kTranslationTimestamp);
      return translationTimestamp;
    } catch (ex) {
      throw CrowdinException("Can't get translation timestamp from storage");
    }
  }

  Future<void> setDistribution(String distribution) async {
    try {
      // Parse the distribution to get locale
      final distributionData = await compute(decode, distribution);
      final locale = distributionData['@@locale'] as String?;
      if (locale == null) {
        throw CrowdinException("Distribution doesn't contain locale information");
      }

      // Save distribution as a separate JSON file per locale
      final fileName = '${locale.replaceAll('-', '_')}.json';
      final file = File(path.join(_storageDirectory.path, fileName));
      await file.writeAsString(distribution);
    } catch (e) {
      throw CrowdinException("Can't store the distribution: $e");
    }
  }

  Future<Map<String, dynamic>?> getTranslation(Locale locale) async {
    try {
      final fileName = '${locale.toString().replaceAll('-', '_')}.json';
      final file = File(path.join(_storageDirectory.path, fileName));

      if (!await file.exists()) {
        return null;
      }

      final content = await file.readAsString();
      final distribution = await compute(decode, content);

      return distribution;
    } catch (ex) {
      throw CrowdinException("Can't get distribution from storage: $ex");
    }
  }

  Future<void> setIsPausedPermanently(bool shouldPause) async {
    try {
      final file = File(path.join(_storageDirectory.path, _kIsPausedPermanentlyFile));
      await file.writeAsString(jsonEncode({'isPaused': shouldPause}));
    } catch (ex) {
      throw CrowdinException("Can't store the isPausedPermanently value");
    }
  }

  Future<bool?> getIsPausedPermanently() async {
    try {
      final file = File(path.join(_storageDirectory.path, _kIsPausedPermanentlyFile));
      if (!await file.exists()) {
        return null;
      }
      final content = await file.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return data['isPaused'] as bool?;
    } catch (ex) {
      throw CrowdinException("Can't get isPausedPermanently from storage");
    }
  }

  Future<void> setErrorMap(Map<String, int> errorMap) async {
    try {
      final file = File(path.join(_storageDirectory.path, _kErrorMapFile));
      await file.writeAsString(jsonEncode(errorMap));
    } catch (ex) {
      throw CrowdinException("Can't store the errorMap");
    }
  }

  Future<Map<String, int>?> getErrorMap() async {
    try {
      final file = File(path.join(_storageDirectory.path, _kErrorMapFile));
      if (!await file.exists()) {
        return null;
      }
      final content = await file.readAsString();
      final decodedMap = jsonDecode(content) as Map<String, dynamic>;
      return decodedMap.map((k, v) => MapEntry(k, v as int));
    } catch (ex) {
      CrowdinLogger.printLog("Can't get errorMap from storage");
      return null;
    }
  }

  Map<String, dynamic> decode(String content) {
    return jsonDecode(content) as Map<String, dynamic>;
  }

  String encode(Map<String, dynamic> json) {
    return jsonEncode(json);
  }
}
