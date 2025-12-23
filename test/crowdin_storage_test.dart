import 'dart:convert';
import 'dart:io';

import 'package:crowdin_sdk/src/crowdin_storage.dart';
import 'package:crowdin_sdk/src/exceptions/crowdin_exceptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('CrowdinStorage', () {
    late CrowdinStorage crowdinStorage;
    late Directory tempDir;

    setUp(() async {
      // Create a temporary directory for testing
      tempDir = await Directory.systemTemp.createTemp('crowdin_test_');
      
      // Set up mock path provider
      PathProviderPlatform.instance = MockPathProviderPlatform(tempDir);
      
      crowdinStorage = CrowdinStorage();
      await crowdinStorage.init();
    });

    tearDown(() async {
      // Clean up the temporary directory
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('set and get translation timestamp', () async {
      const int timestamp = 123456;
      await crowdinStorage.setTranslationTimeStamp(timestamp);
      final int? retrievedTimestamp = await crowdinStorage.getTranslationTimestamp();
      expect(retrievedTimestamp, equals(timestamp));
    });

    test('set and get distribution', () async {
      const String distributionJson =
          '{"@@locale": "en_US", "hello_world": "Hello, world!"}';
      final Map<String, dynamic> expectedDistribution =
          jsonDecode(distributionJson);

      await crowdinStorage.setDistribution(distributionJson);

      final Map<String, dynamic>? retrievedDistribution =
          await crowdinStorage.getTranslation(const Locale('en', 'US'));

      expect(retrievedDistribution, equals(expectedDistribution));
    });

    test('get exception in case of empty distribution ', () async {
      expect(() async => await crowdinStorage.setDistribution(''),
          throwsA(const TypeMatcher<CrowdinException>()));
    });

    test('get null if timestamp is missed', () async {
      final int? retrievedTimestamp = await crowdinStorage.getTranslationTimestamp();

      expect(retrievedTimestamp, isNull);
    });

    test('get null if distribution is missed', () async {
      final Map<String, dynamic>? retrievedDistribution =
          await crowdinStorage.getTranslation(const Locale('en', 'US'));

      expect(retrievedDistribution, isNull);
    });

    test('get null if distribution locale mismatched', () async {
      const String distributionJson =
          '{"@@locale": "en_US", "hello_world": "Hello, world!"}';
      await crowdinStorage.setDistribution(distributionJson);

      final Map<String, dynamic>? retrievedDistribution =
          await crowdinStorage.getTranslation(const Locale('es', 'ES'));

      expect(retrievedDistribution, isNull);
    });
  });
}
