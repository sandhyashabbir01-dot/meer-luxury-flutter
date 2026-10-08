import 'dart:math';

class FakeApiService {
  FakeApiService._();

  static final List<Map<String, dynamic>> _users = [
    {
      'name': 'Demo Customer',
      'email': 'demo@meerluxury.com',
      'password': '123456',
    },
  ];

  static final List<Map<String, dynamic>> _orders = [];

  static Map<String, dynamic>? _currentUser;

  // ============================================================
  // REGISTER CUSTOMER
  // ============================================================

  static Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();

    if (cleanName.isEmpty) {
      throw Exception('Name is required.');
    }

    if (cleanEmail.isEmpty) {
      throw Exception('Email is required.');
    }

    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      throw Exception('Enter a valid email.');
    }

    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }

    final exists = _users.any(
      (user) => user['email'].toString().toLowerCase() == cleanEmail,
    );

    if (exists) {
      throw Exception('An account with this email already exists.');
    }

    final user = {
      'name': cleanName,
      'email': cleanEmail,
      'password': password,
    };

    _users.add(user);

    return {
      'success': true,
      'message': 'Account created successfully.',
      'user': {
        'name': cleanName,
        'email': cleanEmail,
      },
    };
  }

  // ============================================================
  // LOGIN CUSTOMER
  // ============================================================

  static Future<Map<String, dynamic>> loginCustomer({
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));

    final cleanEmail = email.trim().toLowerCase();

    Map<String, dynamic>? foundUser;

    for (final user in _users) {
      if (user['email'].toString().toLowerCase() == cleanEmail &&
          user['password'].toString() == password) {
        foundUser = user;
        break;
      }
    }

    if (foundUser == null) {
      throw Exception('Invalid email or password.');
    }

    _currentUser = foundUser;

    return {
      'success': true,
      'token': 'demo-token-${DateTime.now().millisecondsSinceEpoch}',
      'user': {
        'name': foundUser['name'],
        'email': foundUser['email'],
      },
    };
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static void logout() {
    _currentUser = null;
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  static Map<String, dynamic>? get currentUser => _currentUser;

  static bool get isLoggedIn => _currentUser != null;

  // ============================================================
  // CREATE ORDER
  // ============================================================

  static Future<Map<String, dynamic>> createOrder({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String customerAddress,
    required String customerCity,
    required List<Map<String, dynamic>> products,
    required double totalAmount,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));

    if (customerName.trim().isEmpty) {
      throw Exception('Customer name is required.');
    }

    if (customerEmail.trim().isEmpty) {
      throw Exception('Email is required.');
    }

    if (customerPhone.trim().isEmpty) {
      throw Exception('Phone number is required.');
    }

    if (customerAddress.trim().isEmpty) {
      throw Exception('Address is required.');
    }

    if (customerCity.trim().isEmpty) {
      throw Exception('City is required.');
    }

    if (products.isEmpty) {
      throw Exception('Your bag is empty.');
    }

    final random = Random();

    final orderNumber =
        'ML-${DateTime.now().millisecondsSinceEpoch}-${100 + random.nextInt(900)}';

    final order = {
      'orderNumber': orderNumber,
      'customerName': customerName.trim(),
      'customerEmail': customerEmail.trim(),
      'customerPhone': customerPhone.trim(),
      'customerAddress': customerAddress.trim(),
      'customerCity': customerCity.trim(),
      'products': products,
      'totalAmount': totalAmount,
      'paymentMethod': 'Cash on delivery',
      'status': 'Pending',
      'createdAt': DateTime.now().toIso8601String(),
    };

    _orders.add(order);

    return {
      'success': true,
      'message': 'Order placed successfully.',
      'order': order,
    };
  }

  // ============================================================
  // DEMO ORDER HISTORY
  // ============================================================

  static List<Map<String, dynamic>> get orders =>
      List<Map<String, dynamic>>.unmodifiable(_orders);

  // ============================================================
  // CLEAR DEMO DATA
  // ============================================================

  static void clearDemoData() {
    _users
      ..clear()
      ..add({
        'name': 'Demo Customer',
        'email': 'demo@meerluxury.com',
        'password': '123456',
      });

    _orders.clear();
    _currentUser = null;
  }
}