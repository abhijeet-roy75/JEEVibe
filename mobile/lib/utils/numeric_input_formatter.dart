import 'package:flutter/services.dart';

/// Ultra-simple formatter: only filters invalid characters
/// NEVER blocks deletion - always allows empty strings and shorter text
/// Handles minus sign position and decimal point count as user types
class NumericInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    
    // CRITICAL: Always allow empty string and deletion
    // If text is empty or shorter, it's deletion - always allow
    if (text.isEmpty || text.length <= oldValue.text.length) {
      // During deletion, just filter invalid characters but allow the deletion
      final filtered = _filterCharacters(text);
      if (filtered != text) {
        return TextEditingValue(
          text: filtered,
          selection: TextSelection.collapsed(offset: filtered.length),
        );
      }
      return newValue;
    }
    
    // For typing (text is longer), filter characters
    final filtered = _filterCharacters(text);
    
    if (filtered != text) {
      final offset = newValue.selection.baseOffset.clamp(0, filtered.length);
      final extent = newValue.selection.extentOffset.clamp(0, filtered.length);
      return TextEditingValue(
        text: filtered,
        selection: TextSelection(baseOffset: offset, extentOffset: extent),
      );
    }
    
    return newValue;
  }
  
  String _filterCharacters(String text) {
    // Filter to only allow digits, decimal, and minus
    String filtered = text.replaceAll(RegExp(r'[^\d.\-]'), '');
    
    // Handle minus sign - only at start
    if (filtered.contains('-')) {
      final firstMinus = filtered.indexOf('-');
      if (firstMinus == 0) {
        filtered = '-' + filtered.substring(1).replaceAll('-', '');
      } else {
        filtered = filtered.replaceAll('-', '');
      }
    }
    
    // Handle decimal - only one
    final decimalCount = '.'.allMatches(filtered).length;
    if (decimalCount > 1) {
      final firstDecimal = filtered.indexOf('.');
      filtered = filtered.substring(0, firstDecimal + 1) + 
                 filtered.substring(firstDecimal + 1).replaceAll('.', '');
    }
    
    return filtered;
  }
}

