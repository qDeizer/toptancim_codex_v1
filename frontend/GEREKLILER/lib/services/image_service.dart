import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';

class ImageService {
  static String get baseUrl => Constants.baseUrl;
  final ImagePicker _picker = ImagePicker();

  // Resim seçme seçeneklerini göster
  Future<XFile?> showImageSourceDialog(BuildContext context) async {
    if (kIsWeb) {
      // Web için sadece dosya seçimi
      return await _picker.pickImage(source: ImageSource.gallery);
    }

    // Mobil için kamera ve galeri seçenekleri
    XFile? selectedImage;
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Resim Seç'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Kameradan Çek'),
                onTap: () async {
                  Navigator.of(context).pop();
                  selectedImage = await _picker.pickImage(source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galeriden Seç'),
                onTap: () async {
                  Navigator.of(context).pop();
                  selectedImage = await _picker.pickImage(source: ImageSource.gallery);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('İptal'),
            ),
          ],
        );
      },
    );
    return selectedImage;
  }

  // Çoklu resim seçimi
  Future<List<XFile>?> pickMultipleImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage();
      return images;
    } catch (e) {
      print('Çoklu resim seçme hatası: $e');
      return null;
    }
  }

  // Profil fotoğrafı yükleme
  Future<String?> uploadProfileImage(XFile imageFile) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/profile'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'profile',
          bytes,
          filename: imageFile.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'profile',
          imageFile.path,
        ));
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        return jsonData['url'];
      } else {
        throw Exception(jsonData['message'] ?? 'Yükleme başarısız');
      }
    } catch (e) {
      print('Profil fotoğrafı yükleme hatası: $e');
      rethrow;
    }
  }

  // Ürün resimleri yükleme
  Future<List<String>?> uploadProductImages(List<XFile> imageFiles) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      
      if (token == null) {
        throw Exception('Token bulunamadı');
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/upload/product'),
      );

      request.headers['Authorization'] = 'Bearer $token';
      
      for (var imageFile in imageFiles) {
        if (kIsWeb) {
          final bytes = await imageFile.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'products',
            bytes,
            filename: imageFile.name,
          ));
        } else {
          request.files.add(await http.MultipartFile.fromPath(
            'products',
            imageFile.path,
          ));
        }
      }

      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonData = json.decode(responseData);

      if (response.statusCode == 200) {
        final files = jsonData['files'] as List;
        return files.map((file) => file['url'] as String).toList();
      } else {
        throw Exception(jsonData['message'] ?? 'Yükleme başarısız');
      }
    } catch (e) {
      print('Ürün resimleri yükleme hatası: $e');
      rethrow;
    }
  }

  // Resim URL'sini tam URL'ye çevir
  static String getFullImageUrl(String? imageUrl) {
    if (imageUrl == null || imageUrl.isEmpty) {
      return '';
    }
    
    if (imageUrl.startsWith('http')) {
      return imageUrl;
    }

    String baseHost = baseUrl;
    if (baseHost.endsWith('/api')) {
      baseHost = baseHost.substring(0, baseHost.length - 4);
    }

    return '$baseHost$imageUrl';
  }
}
