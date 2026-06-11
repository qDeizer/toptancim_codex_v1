import 'package:flutter/foundation.dart';

class Constants {
  // Azure Canlı Sunucu Adresi (Deploy için):
  // static String get baseUrl => 'https://toptancim-api-taha.azurewebsites.net/api';

  // Lokal Geliştirme - Platform-specific base URLs
  static String get baseUrl {
    if (kIsWeb) {
      // Lokal geliştirmede backend'e doğrudan, sunucuda nginx /api proxy'si
      // üzerinden aynı origin'e bağlan
      final host = Uri.base.host;
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:3002/api';
      }
      return '${Uri.base.origin}/api';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:3002/api';
      case TargetPlatform.iOS:
        return 'http://127.0.0.1:3002/api';
      default:
        return 'http://localhost:3002/api';
    }
  }
}
