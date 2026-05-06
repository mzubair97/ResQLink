// widgets/haptics.dart
// Centralised haptic-feedback utility.
//   Haptics.light()  → taps, navigation, selection
//   Haptics.medium() → toggle changes, confirmations
//   Haptics.heavy()  → critical / emergency actions
import 'package:flutter/services.dart';

class Haptics {
  const Haptics._();

  /// Subtle tick — use for taps, icon presses, minor selections.
  static void light() => HapticFeedback.lightImpact();

  /// Moderate pulse — use for toggles, step completions, confirmations.
  static void medium() => HapticFeedback.mediumImpact();

  /// Strong thud — use for emergency submits, destructive actions, SOS.
  static void heavy() => HapticFeedback.heavyImpact();

  /// Double-tap pattern — use for critical alerts accepted by the user.
  static Future<void> doubleHeavy() async {
    HapticFeedback.heavyImpact();
    await Future<void>.delayed(const Duration(milliseconds: 120));
    HapticFeedback.heavyImpact();
  }
}
