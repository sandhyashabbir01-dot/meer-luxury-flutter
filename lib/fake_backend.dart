import 'dart:math';

/// ===============================================================
/// MEER LUXURY COLLECTION
/// FAKE / DEMO BACKEND
/// ===============================================================
///
/// Ye file sirf Flutter test app ke liye hai.
/// Original Meer Luxury Collection backend ko touch nahi karti.
///
/// Isme:
/// - Registration
/// - Login
/// - Logout
/// - Fake users
/// - Fake orders
/// - Order history
/// sab local memory mein handle hote hain.
/// ===============================================================

class FakeUser {
  final String name;
  final String email;
  final String password;

  FakeUser({
    required this.name,
    required this.email,
    required this.password,
  });
}

class FakeOrder {
  final String orderNumber;
  final String customerName;
  final String email;
  final String phone;
  final String address;
  final String city;
  final double totalAmount;
  final DateTime createdAt;

  FakeOrder({
    required this.orderNumber,
    required this.customerName,
    required this.email,
    required this.phone,
    required this.address,
    required this.city,
    required this.totalAmount,
    required this.createdAt,
  });
}

class FakeBackend {
  FakeBackend._();

  static final FakeBackend instance = FakeBackend._();

  // ---------------------------------------------------------------
  // FAKE USERS
  // ---------------------------------------------------------------

  final List<FakeUser> _users = [
    FakeUser(
      name: 'Demo Customer',
      email: 'demo@meerluxury.com',
      password: '123456',
    ),
  ];

  // ---------------------------------------------------------------
  // FAKE ORDERS
  // ---------------------------------------------------------------

  final List<FakeOrder> _orders = [];

  FakeUser? _currentUser;

  // ---------------------------------------------------------------
  // GET CURRENT USER
  // ---------------------------------------------------------------

  FakeUser? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  // ---------------------------------------------------------------
  // REGISTER
  // ---------------------------------------------------------------

  String? register({
    required String name,
    required String email,
    required String password,
  }) {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanName.isEmpty) {
      return 'Please enter your name.';
    }

    if (cleanEmail.isEmpty) {
      return 'Please enter your email.';
    }

    if (!cleanEmail.contains('@') || !cleanEmail.contains('.')) {
      return 'Please enter a valid email address.';
    }

    if (cleanPassword.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    final alreadyExists = _users.any(
      (user) => user.email.toLowerCase() == cleanEmail,
    );

    if (alreadyExists) {
      return 'An account with this email already exists.';
    }

    final newUser = FakeUser(
      name: cleanName,
      email: cleanEmail,
      password: cleanPassword,
    );

    _users.add(newUser);
    _currentUser = newUser;

    return null;
  }

  // ---------------------------------------------------------------
  // LOGIN
  // ---------------------------------------------------------------

  String? login({
    required String email,
    required String password,
  }) {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();

    if (cleanEmail.isEmpty || cleanPassword.isEmpty) {
      return 'Please enter your email and password.';
    }

    try {
      final user = _users.firstWhere(
        (user) =>
            user.email.toLowerCase() == cleanEmail &&
            user.password == cleanPassword,
      );

      _currentUser = user;

      return null;
    } catch (_) {
      return 'Invalid email or password.';
    }
  }

  // ---------------------------------------------------------------
  // LOGOUT
  // ---------------------------------------------------------------

  void logout() {
    _currentUser = null;
  }

  // ---------------------------------------------------------------
  // PLACE ORDER
  // ---------------------------------------------------------------

  FakeOrder placeOrder({
    required String customerName,
    required String email,
    required String phone,
    required String address,
    required String city,
    required double totalAmount,
  }) {
    final random = Random();

    final orderNumber =
        'ML-${DateTime.now().millisecondsSinceEpoch}-${100 + random.nextInt(900)}';

    final order = FakeOrder(
      orderNumber: orderNumber,
      customerName: customerName.trim(),
      email: email.trim(),
      phone: phone.trim(),
      address: address.trim(),
      city: city.trim(),
      totalAmount: totalAmount,
      createdAt: DateTime.now(),
    );

    _orders.add(order);

    return order;
  }

  // ---------------------------------------------------------------
  // GET ALL DEMO ORDERS
  // ---------------------------------------------------------------

  List<FakeOrder> get orders => List.unmodifiable(_orders);

  // ---------------------------------------------------------------
  // GET CURRENT USER ORDERS
  // ---------------------------------------------------------------

  List<FakeOrder> get currentUserOrders {
    if (_currentUser == null) {
      return [];
    }

    return _orders
        .where(
          (order) =>
              order.email.toLowerCase() ==
              _currentUser!.email.toLowerCase(),
        )
        .toList()
        .reversed
        .toList();
  }

  // ---------------------------------------------------------------
  // CLEAR DEMO DATA
  // ---------------------------------------------------------------

  void clearDemoData() {
    _orders.clear();
    _currentUser = null;
  }
}