import 'dart:async';
import 'dart:convert';

import 'package:frontend/models/product.dart';
import 'package:http/http.dart' as http;

import '../utils/constants.dart';
import '../utils/logger.dart';

class ShopService {
  final String _baseUrl = '${Constants.baseUrl}/shop';
  static const Duration _requestTimeout = Duration(seconds: 20);

  Future<List<Product>> fetchShopProducts(
    String token, {
    String? wholesalerId,
  }) async {
    var url = '$_baseUrl/products';
    if (wholesalerId != null) {
      url += '?wholesaler_id=$wholesalerId';
    }

    final stopwatch = Stopwatch()..start();

    try {
      AppLogger.info(
        'Shop service fetch started: wholesalerId=${wholesalerId ?? "all"}',
      );

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final body =
            jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
        final products =
            body.map((dynamic item) => Product.fromJson(item)).toList();
        AppLogger.info(
          'Shop service fetch completed: wholesalerId=${wholesalerId ?? "all"}, productCount=${products.length}, durationMs=${stopwatch.elapsedMilliseconds}',
        );
        return products;
      }

      final error = jsonDecode(utf8.decode(response.bodyBytes));
      AppLogger.warning(
        'Shop service fetch failed: status=${response.statusCode}, wholesalerId=${wholesalerId ?? "all"}, durationMs=${stopwatch.elapsedMilliseconds}',
        error,
      );
      throw Exception(error['message'] ?? 'Alisveris urunleri yuklenemedi');
    } on TimeoutException catch (error, stackTrace) {
      AppLogger.warning(
        'Shop service fetch timed out after ${_requestTimeout.inSeconds}s: wholesalerId=${wholesalerId ?? "all"}',
        error,
        stackTrace,
      );
      throw Exception('Alisveris verileri yuklenirken zaman asimi olustu.');
    } catch (error, stackTrace) {
      AppLogger.error(
        'Shop service fetch crashed: wholesalerId=${wholesalerId ?? "all"}',
        error,
        stackTrace,
      );
      rethrow;
    }
  }
}
