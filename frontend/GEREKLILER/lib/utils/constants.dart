import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class Constants {
  // Azure Canlı Sunucu Adresi
  // Test ve sunum sırasında tüm platformların (Web, Android, iOS) bu adresi kullanması sağlanır.
  static String get baseUrl {
    return 'https://toptancim-api-taha.azurewebsites.net/api';
  }
}