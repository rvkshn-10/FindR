import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Schema validation utilities for JSON data
class SchemaValidator {
  /// Validates that a value is a proper Map<String, dynamic>
  static bool isValidMap(dynamic value) {
    return value is Map && value.keys.every((k) => k is String);
  }

  /// Validates that a value is a proper List
  static bool isValidList(dynamic value) {
    return value is List;
  }

  /// Validates search history entry schema
  static bool isValidSearchEntry(Map<String, dynamic> entry) {
    try {
      return entry.containsKey('id') &&
             entry.containsKey('item') &&
             entry.containsKey('lat') &&
             entry.containsKey('lng') &&
             entry.containsKey('locationLabel') &&
             entry.containsKey('timestamp') &&
             entry['id'] is String &&
             entry['item'] is String &&
             entry['lat'] is num &&
             entry['lng'] is num &&
             entry['locationLabel'] is String &&
             entry['timestamp'] is int;
    } catch (e) {
      debugPrint('[Wayvio] Schema validation error for search entry: $e');
      return false;
    }
  }

  /// Validates favorite store entry schema
  static bool isValidFavoriteEntry(Map<String, dynamic> entry) {
    try {
      return entry.containsKey('id') &&
             entry.containsKey('storeId') &&
             entry.containsKey('storeName') &&
             entry.containsKey('address') &&
             entry.containsKey('lat') &&
             entry.containsKey('lng') &&
             entry.containsKey('searchItem') &&
             entry.containsKey('timestamp') &&
             entry['id'] is String &&
             entry['storeId'] is String &&
             entry['storeName'] is String &&
             entry['address'] is String &&
             entry['lat'] is num &&
             entry['lng'] is num &&
             entry['searchItem'] is String &&
             entry['timestamp'] is int;
    } catch (e) {
      debugPrint('[Wayvio] Schema validation error for favorite entry: $e');
      return false;
    }
  }

  /// Validates recommendation entry schema
  static bool isValidRecommendationEntry(Map<String, dynamic> entry) {
    try {
      return entry.containsKey('id') &&
             entry.containsKey('title') &&
             entry.containsKey('content') &&
             entry.containsKey('basedOn') &&
             entry.containsKey('timestamp') &&
             entry['id'] is String &&
             entry['title'] is String &&
             entry['content'] is String &&
             entry['basedOn'] is String &&
             entry['timestamp'] is int;
    } catch (e) {
      debugPrint('[Wayvio] Schema validation error for recommendation entry: $e');
      return false;
    }
  }

  /// Safe JSON decode with validation
  static List<Map<String, dynamic>> safeDecodeList(String raw, bool Function(Map<String, dynamic>) validator) {
    try {
      if (raw.isEmpty) return [];
      
      final decoded = jsonDecode(raw);
      if (!isValidList(decoded)) {
        debugPrint('[Wayvio] Invalid JSON structure: expected list');
        return [];
      }

      final list = decoded as List;
      final validEntries = <Map<String, dynamic>>[];
      
      for (final item in list) {
        if (isValidMap(item)) {
          final map = item as Map<String, dynamic>;
          if (validator(map)) {
            validEntries.add(map);
          } else {
            debugPrint('[Wayvio] Invalid entry schema: $map');
          }
        }
      }
      
      return validEntries;
    } catch (e) {
      debugPrint('[Wayvio] JSON decode error: $e');
      return [];
    }
  }

  /// Safe JSON encode with validation
  static String safeEncodeList(List<Map<String, dynamic>> list) {
    try {
      // Validate all entries before encoding
      for (final entry in list) {
        if (!isValidMap(entry)) {
          debugPrint('[Wayvio] Invalid entry type during encode: $entry');
          return '[]';
        }
      }
      
      return jsonEncode(list);
    } catch (e) {
      debugPrint('[Wayvio] JSON encode error: $e');
      return '[]';
    }
  }
}
