import 'dart:convert';
import 'package:http/http.dart' as http;

/// ============================================================
/// MEER LUXURY COLLECTION - API SERVICE
/// ============================================================
///
/// IMPORTANT:
/// - Chrome/Desktop testing: localhost:5000
/// - Android Emulator: 10.0.2.2:5000
/// - Physical Android phone: laptop ka local IP:5000
///
/// Jab hum final mobile testing karenge to BASE URL change karenge.
/// ============================================================

class ApiService {
  // ------------------------------------------------------------
  // LOCAL BACKEND
  // ------------------------------------------------------------

  static const String baseUrl = 'http://localhost:5000';

  // ------------------------------------------------------------
  // TOKEN
  // ------------------------------------------------------------

  static String? token;

  static Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // ============================================================
  // CUSTOMER AUTH
  // ============================================================

  static Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/register'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
      }),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> loginCustomer({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = _handleResponse(response);

    if (data['token'] != null) {
      token = data['token'].toString();
    }

    return data;
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  static Future<Map<String, dynamic>> getSettings() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/settings'),
      headers: _headers,
    );

    return _handleResponse(response);
  }

  // ============================================================
  // PRODUCTS
  // ============================================================

  static Future<List<dynamic>> getProducts() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/products'),
      headers: _headers,
    );

    final data = _handleResponse(response);

    if (data is List) {
      return data;
    }

    return [];
  }

  // ============================================================
  // ORDERS
  // ============================================================

  static Future<Map<String, dynamic>> createOrder({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String customerAddress,
    required String customerCity,
    required List<Map<String, dynamic>> products,
    required num totalAmount,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/orders'),
      headers: _headers,
      body: jsonEncode({
        'customerName': customerName,
        'customerEmail': customerEmail,
        'customerPhone': customerPhone,
        'customerAddress': customerAddress,
        'customerCity': customerCity,
        'products': products,
        'totalAmount': totalAmount,
      }),
    );

    return _handleResponse(response);
  }

  static Future<List<dynamic>> getMyOrders() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/my-orders'),
      headers: _headers,
    );

    final data = _handleResponse(response);

    if (data is List) {
      return data;
    }

    return [];
  }

  // ============================================================
  // REVIEWS
  // ============================================================

  static Future<List<dynamic>> getProductReviews(
    String productKey,
  ) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/reviews/product/$productKey'),
      headers: _headers,
    );

    final data = _handleResponse(response);

    if (data is List) {
      return data;
    }

    return [];
  }

  static Future<Map<String, dynamic>> addReview({
    required String productKey,
    required int rating,
    required String comment,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/reviews'),
      headers: _headers,
      body: jsonEncode({
        'productKey': productKey,
        'rating': rating,
        'comment': comment,
      }),
    );

    return _handleResponse(response);
  }

  // ============================================================
  // SELLER AUTH
  // ============================================================

  static Future<Map<String, dynamic>> registerSeller({
    required String name,
    required String shopName,
    required String email,
    required String phone,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/sellers/register'),
      headers: _headers,
      body: jsonEncode({
        'name': name,
        'shopName': shopName,
        'email': email,
        'phone': phone,
        'password': password,
      }),
    );

    return _handleResponse(response);
  }

  static Future<Map<String, dynamic>> loginSeller({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/sellers/login'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    final data = _handleResponse(response);

    if (data['token'] != null) {
      token = data['token'].toString();
    }

    return data;
  }

  static Future<Map<String, dynamic>> checkSellerStatus({
    required String email,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/sellers/check-status'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
      }),
    );

    return _handleResponse(response);
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  static Future<List<dynamic>> getNotifications() async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/notifications'),
      headers: _headers,
    );

    final data = _handleResponse(response);

    if (data is List) {
      return data;
    }

    return [];
  }

  // ============================================================
  // HELPER
  // ============================================================

  static dynamic _handleResponse(http.Response response) {
    dynamic data;

    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = {
        'message': response.body,
      };
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }

    String message = 'Something went wrong.';

    if (data is Map && data['message'] != null) {
      message = data['message'].toString();
    }

    throw Exception(message);
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static void logout() {
    token = null;
  }
}