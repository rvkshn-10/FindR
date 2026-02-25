import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../config.dart';

final RegExp _jsonFence = RegExp(r'```(?:json)?\s*', multiLine: true);

GenerativeModel? _summaryModel;

GenerativeModel get _getSummaryModel => _summaryModel ??= GenerativeModel(
      model: 'gemini-2.0-flash-lite',
      apiKey: kGeminiApiKey,
      generationConfig: GenerationConfig(
        temperature: 0.3,
        maxOutputTokens: 200,
      ),
    );

class AiResultSummary {
  final String recommendation;
  final String reasoning;
  final List<String> tips;

  const AiResultSummary({
    required this.recommendation,
    required this.reasoning,
    this.tips = const [],
  });
}

/// Ask Gemini to pick the best store from search results.
/// Uses flash-lite with a minimal prompt to keep token usage low.
Future<AiResultSummary?> generateResultSummary({
  required String query,
  required List<Map<String, dynamic>> storeData,
}) async {
  if (storeData.isEmpty) return null;

  try {
    final compact = storeData.take(4).map((s) => {
      'n': s['name'],
      'd': s['distanceKm'],
      'r': s['rating'],
      'rc': s['reviewCount'],
      'p': s['priceLevel'],
      't': s['shopType'],
    }).toList();

    final prompt = 'User wants "$query". Nearby stores: ${jsonEncode(compact)}\n'
        'Keys: n=name,d=distanceKm,r=rating(1-5),rc=reviews,p=priceLevel,t=type.\n'
        'Pick the best store. Return ONLY JSON: '
        '{"recommendation":"1-2 sentences","reasoning":"1 sentence","tips":["1 tip"]}';

    final response = await _getSummaryModel
        .generateContent([Content.text(prompt)])
        .timeout(kAiTimeout);

    final text = response.text?.trim();
    if (text == null || text.isEmpty) return null;

    final cleaned = text.replaceAll(_jsonFence, '').trim();
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
    debugPrint('[Wayvio] AI summary failed: $e');
    return null;
  }
}
