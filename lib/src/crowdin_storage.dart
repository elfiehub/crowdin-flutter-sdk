import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:crowdin_sdk/src/crowdin_logger.dart';
import 'package:crowdin_sdk/src/exceptions/crowdin_exceptions.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

const String _kCrowdinFolder = 'crowdin_translations';
const String _kTranslationTimestampFile = 'translation_timestamp.json';
const String _kIsPausedPermanentlyFile = 'is_paused_permanently.json';
const String _kErrorMapFile = 'error_map.json';

class CrowdinStorage {
  CrowdinStorage();

  late Directory _storageDirectory;

  Future<Directory> init() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    _storageDirectory = Directory(path.join(appDocDir.path, _kCrowdinFolder));
    
    // Create the directory if it doesn't exist
    if (!await _storageDirectory.exists()) {
      await _storageDirectory.create(recursive: true);
    }
    
    return _storageDirectory;
  }

  Future<void> setTranslationTimeStamp(int? timestamp) async {
    try {
      final file = File(path.join(_storageDirectory.path, _kTranslationTimestampFile));
      await file.writeAsString(jsonEncode({'timestamp': timestamp ?? 1}));
    } catch (_) {
      throw CrowdinException("Can't store translation timestamp");
    }
  }

  int? getTranslationTimestamp() {
    try {
      final file = File(path.join(_storageDirectory.path, _kTranslationTimestampFile));
      if (!file.existsSync()) {
        return null;
      }
      final content = file.readAsStringSync();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return data['timestamp'] as int?;
    } catch (ex) {
      throw CrowdinException("Can't get translation timestamp from storage");
    }
  }

  Future<void> setDistribution(String distribution) async {
    try {
      // Parse the distribution to get locale
      final distributionData = jsonDecode(distribution) as Map<String, dynamic>;
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

  Map<String, dynamic>? getTranslation(Locale locale) {
    try {
      final fileName = '${locale.toString().replaceAll('-', '_')}.json';
      final file = File(path.join(_storageDirectory.path, fileName));
      
      if (!file.existsSync()) {
        return null;
      }
      
      final content = file.readAsStringSync();
      final distribution = jsonDecode(content) as Map<String, dynamic>;
      
      return distribution;
    } catch (ex) {
      throw CrowdinException("Can't get distribution from storage: $ex");
    }
  }

  void setIsPausedPermanently(bool shouldPause) {
    try {
      final file = File(path.join(_storageDirectory.path, _kIsPausedPermanentlyFile));
      file.writeAsStringSync(jsonEncode({'isPaused': shouldPause}));
    } catch (ex) {
      throw CrowdinException("Can't store the isPausedPermanently value");
    }
  }

  bool? getIsPausedPermanently() {
    try {
      final file = File(path.join(_storageDirectory.path, _kIsPausedPermanentlyFile));
      if (!file.existsSync()) {
        return null;
      }
      final content = file.readAsStringSync();
      final data = jsonDecode(content) as Map<String, dynamic>;
      return data['isPaused'] as bool?;
    } catch (ex) {
      throw CrowdinException("Can't get isPausedPermanently from storage");
    }
  }

  void setErrorMap(Map<String, int> errorMap) {
    try {
      final file = File(path.join(_storageDirectory.path, _kErrorMapFile));
      file.writeAsStringSync(jsonEncode(errorMap));
    } catch (ex) {
      throw CrowdinException("Can't store the errorMap");
    }
  }

  Map<String, int>? getErrorMap() {
    try {
      final file = File(path.join(_storageDirectory.path, _kErrorMapFile));
      if (!file.existsSync()) {
        return null;
      }
      final content = file.readAsStringSync();
      final decodedMap = jsonDecode(content) as Map<String, dynamic>;
      return decodedMap.map((k, v) => MapEntry(k, v as int));
    } catch (ex) {
      CrowdinLogger.printLog("Can't get errorMap from storage");
      return null;
    }
  }
}
