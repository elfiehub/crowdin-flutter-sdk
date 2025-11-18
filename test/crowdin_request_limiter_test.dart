import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:crowdin_sdk/src/crowdin_request_limiter.dart';
import 'package:crowdin_sdk/src/crowdin_storage.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockCrowdinStorage extends Mock implements CrowdinStorage {}

// Mock path provider for testing
class MockPathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  final Directory tempDir;

  MockPathProviderPlatform(this.tempDir);

  @override
  Future<String?> getApplicationDocumentsPath() async {
    return tempDir.path;
  }
}

final DateFormat _formatter = DateFormat('yyyy-MM-dd');

@visibleForTesting
String getTodayDateString() {
  return _formatter.format(DateTime.now());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  late CrowdinRequestLimiter requestLimiter;
  late CrowdinStorage storage;
  late Directory tempDir;

  setUp(() async {
    // Create a temporary directory for testing
    tempDir = await Directory.systemTemp.createTemp('crowdin_test_');
    
    // Set up mock path provider
    PathProviderPlatform.instance = MockPathProviderPlatform(tempDir);
    
    storage = CrowdinStorage();
    requestLimiter = CrowdinRequestLimiter();
    await storage.init();
  });

  tearDown(() async {
    // Clean up the temporary directory
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('should initialize with storage values', () async {
    await storage.setIsPausedPermanently(true);
    await requestLimiter.init(storage);
    expect(await storage.getIsPausedPermanently(), true);
    expect(requestLimiter.pauseRequests, true);
  });

  test('should increment error counter', () async {
    await requestLimiter.init(storage);
    await requestLimiter.incrementErrorCounter();
    expect(await storage.getErrorMap(), {getTodayDateString(): 1});
    await requestLimiter.incrementErrorCounter();
    expect(await storage.getErrorMap(), {getTodayDateString(): 2});
  });

  test('should pause requests after max errors in a day', () async {
    await storage.setErrorMap({getTodayDateString(): 10});
    await requestLimiter.init(storage);
    expect(requestLimiter.pauseRequests, true);
  });

  test('should reset error map and pause state', () async {
    await storage.setErrorMap({getTodayDateString(): 10});
    await requestLimiter.init(storage);
    expect(requestLimiter.pauseRequests, true);
    await requestLimiter.reset();
    expect(requestLimiter.pauseRequests, false);
  });

  test('should stop requests permanently after max days in a row', () async {
    await storage.setErrorMap({
      _formatter.format(DateTime.now()): 10,
      _formatter.format(DateTime.now().subtract(const Duration(days: 1))): 10,
      _formatter.format(DateTime.now().subtract(const Duration(days: 2))): 10,
    });
    await requestLimiter.init(storage);
    await requestLimiter.incrementErrorCounter();
    expect(requestLimiter.pauseRequests, true);
  });
}
