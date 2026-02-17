/// Shared HTTP helper for SerpApi calls.
///
/// On web, tries multiple CORS proxies in sequence until one succeeds.
/// On native, calls serpapi.com directly.
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Fetches a SerpApi JSON response, trying multiple CORS proxies on web.
///
/// Returns the decoded JSON map, or null on failure.
Future<Map<String, dynamic>?> fetchSerpApi(Map<String, String> params) async {
  final uris = buildSerpApiUris(params);

  for (var i = 0; i < uris.length; i++) {
    final uri = uris[i];
    try {
      debugPrint('SerpApi: trying ${kIsWeb ? "proxy ${i + 1}/${uris.length}" : "direct"}: '
          '${uri.toString().substring(0, uri.toString().length.clamp(0, 60))}...');

      final res = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(kSerpApiTimeout);

      if (res.statusCode != 200) {
        debugPrint('SerpApi: HTTP ${res.statusCode} from proxy $i');
        continue; // try next proxy
      }

      final body = res.body;

      // Some CORS proxies return HTML error pages instead of JSON.
      if (body.trimLeft().startsWith('<')) {
        debugPrint('SerpApi: proxy $i returned HTML, trying next...');
        continue;
      }

      final data = jsonDecode(body) as Map<String, dynamic>;

      // Check for SerpApi-level errors.
      if (data.containsKey('error')) {
        debugPrint('SerpApi error: ${data['error']}');
        return null; // SerpApi error — don't try more proxies, the key/query is bad.
      }

      return data;
    } catch (e) {
      debugPrint('SerpApi: proxy $i failed: $e');
      continue; // try next proxy
    }
  }

  debugPrint('SerpApi: all ${uris.length} attempts failed');
  return null;
}
