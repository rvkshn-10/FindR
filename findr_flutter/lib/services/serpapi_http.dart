/// Shared HTTP helper for SerpApi calls.
///
/// On web, uses the Firebase Cloud Function proxy (/api/serpapi).
/// On native, calls serpapi.com directly.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Fetches a SerpApi JSON response via the Cloud Function proxy on web.
///
/// Returns the decoded JSON map, or null on failure.
Future<Map<String, dynamic>?> fetchSerpApi(Map<String, String> params) async {
  final uris = buildSerpApiUris(params);

  for (var i = 0; i < uris.length; i++) {
    final uri = uris[i];
    try {
      print('[Wayvio] SerpApi: trying ${kIsWeb ? "cloud function" : "direct"}: '
          '${uri.toString().substring(0, uri.toString().length.clamp(0, 80))}...');

      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(kSerpApiTimeout);

      if (res.statusCode != 200) {
        print('[Wayvio] SerpApi: HTTP ${res.statusCode}');
        continue;
      }

      final body = res.body;

      if (body.trimLeft().startsWith('<')) {
        print('[Wayvio] SerpApi: got HTML instead of JSON');
        continue;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      if (data.containsKey('error')) {
        print('[Wayvio] SerpApi error: ${data['error']}');
        return null;
      }

      print('[Wayvio] SerpApi: success');
      return data;
    } catch (e) {
      print('[Wayvio] SerpApi attempt $i failed: $e');
      continue;
    }
  }

  print('[Wayvio] SerpApi: all ${uris.length} attempts failed');
  return null;
}
