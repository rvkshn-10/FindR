import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config.dart';

/// Singleton-ish Gemini model instances (lazy).
GenerativeModel? _queryModel;
GenerativeModel? _summaryModel;

GenerativeModel get _getQueryModel => _queryModel ??= GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: kGeminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.1,
        maxOutputTokens: 300,
      ),
    );

GenerativeModel get _getSummaryModel => _summaryModel ??= GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: kGeminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.6,
        maxOutputTokens: 400,
      ),
    );

// ---------------------------------------------------------------------------
// 1. AI-enhanced search: convert user query → Overpass tags
// ---------------------------------------------------------------------------

/// Result of AI query enhancement.
class AiQueryEnhancement {
  /// Overpass shop/amenity tags to search for (e.g., ["supermarket","pharmacy"]).
  final List<String> shopTags;

  /// Overpass amenity tags (e.g., ["pharmacy","fuel"]).
  final List<String> amenityTags;

  /// A cleaned-up version of the user's item query for display.
  final String refinedQuery;

  const AiQueryEnhancement({
    required this.shopTags,
    required this.amenityTags,
    required this.refinedQuery,
  });
}

/// Ask Gemini to interpret a user's search query and return the best
/// Overpass shop/amenity tags to find stores that carry the item.
Future<AiQueryEnhancement?> enhanceSearchQuery(String userQuery) async {
  try {
    final prompt = '''You are a search assistant for Wayvio, an app that finds nearby stores using OpenStreetMap Overpass API.

Given the user's search query, determine:
1. Which OpenStreetMap "shop" tag values are most likely to carry this item (e.g., supermarket, convenience, pharmacy, electronics, hardware, doityourself, clothes, etc.)
2. Which OpenStreetMap "amenity" tag values might also be relevant (e.g., pharmacy, fuel, marketplace, etc.)
3. A cleaned-up version of what the user is looking for.

IMPORTANT: Return ONLY valid JSON, no markdown, no explanation. Use this exact format:
{"shopTags":["supermarket","convenience"],"amenityTags":["pharmacy"],"refinedQuery":"baby formula"}

User query: "$userQuery"''';

    final response = await _getQueryModel
        .generateContent([Content.text(prompt)])
        .timeout(const Duration(seconds: 8));

    final text = response.text?.trim();
    if (text == null || text.isEmpty) return null;

    // Strip markdown fences if present
    final cleaned = text
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .trim();

    final json = jsonDecode(cleaned) as Map<String, dynamic>;
    return AiQueryEnhancement(
      shopTags: (json['shopTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      amenityTags: (json['amenityTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      refinedQuery:
          json['refinedQuery']?.toString() ?? userQuery,
    );
  } catch (e) {
    debugPrint('AI query enhancement failed: $e');
    return null;
  }
}

// ---------------------------------------------------------------------------
// 2. AI result summary: analyze stores and generate a recommendation
// ---------------------------------------------------------------------------

/// AI-generated analysis of search results.
class AiResultSummary {
  /// Short 1-2 sentence recommendation.
  final String recommendation;

  /// Why the top pick is recommended.
  final String reasoning;

  /// Optional tips (e.g., "Call ahead to check stock").
  final List<String> tips;

  const AiResultSummary({
    required this.recommendation,
    required this.reasoning,
    this.tips = const [],
  });
}

/// Ask Gemini to analyze the search results and give a smart recommendation.
Future<AiResultSummary?> generateResultSummary({
  required String query,
  required List<Map<String, dynamic>> storeData,
}) async {
  if (storeData.isEmpty) return null;

  try {
    final storesJson = jsonEncode(storeData.take(6).toList());
    final prompt = '''You are Wayvio's AI assistant. The user searched for "$query" and found these nearby stores:

$storesJson

Each store has: name, distanceKm, durationMinutes (drive time, may be null), address, openingHours (may be null), brand, rating (Google rating 1-5, may be null), reviewCount (number of Google reviews, may be null), priceLevel ("\$", "\$\$", "\$\$\$", may be null), shopType (store category), serviceOptions (list like ["In-store shopping", "Delivery", "Curbside pickup"]).

Analyze these results considering distance, ratings, store type relevance, price level, and service options. Provide:
1. A short (1-2 sentence) recommendation for the user — which store should they go to and why. Factor in ratings, store type, and distance.
2. Brief reasoning (1 sentence) explaining why this is the best pick
3. 1-2 practical tips (e.g., "Call ahead to confirm stock", "This store has great reviews")

IMPORTANT: Return ONLY valid JSON, no markdown. Use this exact format:
{"recommendation":"Go to [Store] — it's [distance] away with [rating] stars and likely has [item].","reasoning":"[Store] is a [type] that typically stocks [category] and has strong reviews.","tips":["Call ahead to confirm availability","Consider [Store2] as a backup"]}''';

    final response = await _getSummaryModel
        .generateContent([Content.text(prompt)])
        .timeout(const Duration(seconds: 10));

    final text = response.text?.trim();
    if (text == null || text.isEmpty) return null;

    final cleaned = text
        .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
        .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
        .trim();

    final json = jsonDecode(cleaned) as Map<String, dynamic>;
    return AiResultSummary(
      recommendation:
          json['recommendation']?.toString() ?? 'Check the closest store first.',
      reasoning: json['reasoning']?.toString() ?? '',
      tips: (json['tips'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  } catch (e) {
    debugPrint('AI summary generation failed: $e');
    return null;
  }
}
