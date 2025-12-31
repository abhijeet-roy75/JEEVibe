import 'package:flutter/material.dart';

class LocalizationService {
  static const Map<String, Map<String, String>> _strings = {
    'en': {
      'recognized_title': 'Question Recognized!',
      'see_header': 'HERE\'S WHAT I SEE:',
      'solution_header': 'Step-by-Step Solution',
      'priya_tip': 'Priya Ma\'am\'s Tip',
      'final_answer': 'FINAL ANSWER',
      'practice_title': 'Practice Similar Questions',
      'practice_subtitle': 'Master this concept with follow-up questions',
      'back_to_snap': 'Back to Snap and Solve',
    },
    'hi': {
      'recognized_title': 'सवाल पहचाना गया!',
      'see_header': 'यहाँ वह है जो मैं देखती हूँ:',
      'solution_header': 'चरण-दर-चरण समाधान',
      'priya_tip': 'प्रिया मैम की टिप',
      'final_answer': 'अंतिम उत्तर',
      'practice_title': 'समान प्रश्नों का अभ्यास करें',
      'practice_subtitle': 'फॉलो-अप प्रश्नों के साथ इस अवधारणा में महारत हासिल करें',
      'back_to_snap': 'स्नैप और सॉल्व पर वापस जाएं',
    },
  };

  static String getString(String key, String languageCode) {
    final language = _strings.containsKey(languageCode) ? languageCode : 'en';
    return _strings[language]?[key] ?? _strings['en']![key]!;
  }

  /// Get the Priya Ma'am welcome/context strings
  static String getContextString(String key, String languageCode) {
    // For now, most content comes from LLM, but we can localize small hints
    return getString(key, languageCode);
  }
}
