import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ParsedPlaceShare {
  const ParsedPlaceShare({required this.name, required this.link});
  final String name;
  final String link;
}

ParsedPlaceShare parseShareText(String rawText) {
  final urlRegex = RegExp(r'https?://[^\s]+', caseSensitive: false);
  final match = urlRegex.firstMatch(rawText);

  String url = '';
  if (match != null) {
    url = match.group(0) ?? '';
  }

  // Remove the URL from the text to get the place name
  String name = rawText.replaceAll(urlRegex, '').trim();
  // Clean up remaining linebreaks/extra punctuation
  name = name.replaceAll(RegExp(r'[\r\n]+'), ' ').trim();

  return ParsedPlaceShare(name: name, link: url);
}

class ShareIntentService {
  static const _channel = MethodChannel(
    'com.example.personal_manager/share_intent',
  );
  static String? _lastHandledText;

  static void initialize(
    WidgetRef ref,
    void Function(String name, String link) onOpenAddPlace,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShareIntent') {
        final text = call.arguments as String?;
        if (text != null) {
          _handleText(text, onOpenAddPlace);
        }
      }
    });

    // Check cold launch initial share intent
    _channel
        .invokeMethod<String>('getInitialShare')
        .then((text) {
          if (text != null) {
            _handleText(text, onOpenAddPlace);
          }
        })
        .catchError((_) {});
  }

  static void _handleText(
    String rawText,
    void Function(String name, String link) onOpenAddPlace,
  ) {
    final clean = rawText.trim();
    if (clean.isEmpty) return;
    if (clean == _lastHandledText) return; // Deduplicate
    _lastHandledText = clean;

    final parsed = parseShareText(clean);
    onOpenAddPlace(parsed.name, parsed.link);
  }
}
