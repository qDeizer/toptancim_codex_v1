import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactUtils {
  static String normalizePhoneNumber(String? phone) {
    if (phone == null) return '';

    final raw = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (raw.isEmpty) return '';

    var digits = raw.replaceAll(RegExp(r'\D'), '');

    if (digits.startsWith('00')) {
      digits = digits.substring(2);
    }

    if (digits.startsWith('900')) {
      digits = '90${digits.substring(3)}';
    } else if (digits.startsWith('0')) {
      digits = '90${digits.substring(1)}';
    } else if (digits.length == 10 && !digits.startsWith('90')) {
      digits = '90$digits';
    }

    return '+$digits';
  }

  static Future<void> copyToClipboard(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
  }

  static Future<bool> openPhoneDialer(String? phone) async {
    final normalized = normalizePhoneNumber(phone);
    if (normalized.isEmpty) return false;

    return launchUrl(Uri(scheme: 'tel', path: normalized));
  }

  static Future<bool> openWhatsApp(String? phone) async {
    final normalized = normalizePhoneNumber(phone);
    if (normalized.isEmpty) return false;

    final waDigits = normalized.replaceAll('+', '');
    final primaryUri = Uri.parse('https://wa.me/$waDigits');
    final fallbackUri =
        Uri.parse('https://api.whatsapp.com/send?phone=$waDigits');

    if (await launchUrl(primaryUri, mode: LaunchMode.externalApplication)) {
      return true;
    }
    return launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openDirections({
    double? latitude,
    double? longitude,
    String? query,
  }) async {
    Uri? uri;
    if (latitude != null && longitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
      );
    } else if (query != null && query.trim().isNotEmpty) {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(query)}',
      );
    }

    if (uri == null) return false;
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
