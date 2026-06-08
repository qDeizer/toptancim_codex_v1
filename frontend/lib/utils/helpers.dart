
class Helpers {
  static Map<String, String> getHeaders(String? token) {
    if (token == null) {
      throw Exception('Authorization token is missing.');
    }
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }
}