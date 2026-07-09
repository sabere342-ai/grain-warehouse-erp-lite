import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'phone_number_normalizer.dart';

class WhatsAppAssistedShareService {
  WhatsAppAssistedShareService._();

  /// Opens WhatsApp with a prepared Arabic message.
  /// Returns true if WhatsApp was launched, false otherwise.
  static Future<bool> openWhatsApp({
    required String phone,
    required String message,
    required BuildContext context,
  }) async {
    final normalized = PhoneNumberNormalizer.normalize(phone);
    if (normalized == null) {
      _showNoPhoneError(context);
      return false;
    }

    final encoded = Uri.encodeComponent(message);
    final waUrl = 'https://wa.me/$normalized?text=$encoded';
    final webUrl =
        'https://web.whatsapp.com/send?phone=$normalized&text=$encoded';

    try {
      final launched = await launchUrl(
        Uri.parse(waUrl),
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        if (!context.mounted) return true;
        _showInstruction(context);
        return true;
      }
    } catch (_) {
      // Fall through to web fallback
    }

    try {
      final launched = await launchUrl(
        Uri.parse(webUrl),
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        if (!context.mounted) return true;
        _showInstruction(context);
        return true;
      }
    } catch (_) {
      // Fall through to error
    }

    if (!context.mounted) return false;
    _showWhatsAppNotAvailable(context);
    return false;
  }

  static void _showInstruction(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '\u062A\u0645 \u0641\u062A\u062D \u0648\u0627\u062A\u0633\u0627\u0628 '
          '\u0628\u0631\u0633\u0627\u0644\u0629 \u062C\u0627\u0647\u0632\u0629. '
          '\u0631\u0627\u062C\u0639 \u0627\u0644\u0631\u0633\u0627\u0644\u0629 '
          '\u0648\u0623\u0631\u0641\u0642 \u0645\u0644\u0641 PDF '
          '\u0645\u0646 \u0645\u062C\u0644\u062F Exports '
          '\u062B\u0645 \u0627\u0636\u063A\u0637 \u0625\u0631\u0633\u0627\u0644 \u064A\u062F\u0648\u064A\u064B\u0627.',
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 8),
      ),
    );
  }

  static void _showNoPhoneError(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '\u0644\u0627 \u064A\u0648\u062C\u062F \u0631\u0642\u0645 \u0648\u0627\u062A\u0633\u0627\u0628 '
          '\u0645\u062D\u0641\u0648\u0638 \u0644\u0644\u062A\u0648\u0627\u0635\u0644.',
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 5),
      ),
    );
  }

  static void _showWhatsAppNotAvailable(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '\u062A\u0639\u0630\u0631 \u0641\u062A\u062D \u0648\u0627\u062A\u0633\u0627\u0628. '
          '\u062A\u0623\u0643\u062F \u0645\u0646 \u062A\u062B\u0628\u064A\u062A \u0648\u0627\u062A\u0633\u0627\u0628 '
          '\u0623\u0648 \u0627\u0641\u062A\u062D \u0648\u0627\u062A\u0633\u0627\u0628 \u0648\u064A\u0628 '
          '\u064A\u062F\u0648\u064A\u064B\u0627.',
          textDirection: TextDirection.rtl,
        ),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 6),
      ),
    );
  }
}
