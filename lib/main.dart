import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'fake_api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // folders ki saari images khud dhoond kar products banata hai
  await loadCatalogFromAssets();
  runApp(const MeerLuxuryApp());
}

// ============================================================================
// SETTINGS - yahan se apni details change karein
// ============================================================================
const String kContactAddress = 'Your Address Line, City, Country';
const String kContactPhone = '+00 000 0000000';
const String kContactEmail = 'info@meerluxury.com';

const int kFreeShippingLimit = 100; // is amount se upar shipping free
const int kShippingFee = 10; // is amount se neeche shipping charge

// ---------------------------------------------------------------------------
// BACKEND ADDRESS - yahan apna server address likhein
// Phone par 'localhost' kaam nahi karta. Laptop ka IPv4 address likhein
// (cmd mein `ipconfig`), jaise: 'http://192.168.1.5:5000'
// Phone aur laptop ek hi WiFi par hon.
// ---------------------------------------------------------------------------
const String kBaseUrl = 'http://localhost:5000';

// ============================================================================
// COLORS (aapki website wali theme)
// ============================================================================
const Color kDark = Color(0xFF171310);
const Color kCream = Color(0xFFF8F5F0);
const Color kGold = Color(0xFFD4AF37);
const Color kGoldSoft = Color(0xFFD4AF70);
const Color kGoldDark = Color(0xFF8A6D1D);
const Color kBronze = Color(0xFFB08D57);
const Color kLine = Color(0xFFDCCFB4);

// ============================================================================
// APP
// ============================================================================
class MeerLuxuryApp extends StatelessWidget {
  const MeerLuxuryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Meer Luxury Collection',
      theme: ThemeData(
        fontFamily: 'Arial',
        scaffoldBackgroundColor: kCream,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC9A227)),
      ),
      home: const HomePage(),
    );
  }
}

// ============================================================================
// PRODUCT MODEL + DATA
// ============================================================================
class Product {
  final String name;
  final String image;
  final int price;
  final String category; // fashion, jewellery, bags, india, uk
  final String group; // sub category (sirf bags ke liye)

  const Product(this.name, this.image, this.price, this.category,
      [this.group = '']);

  String get id => image;

  String get priceText => '\$$price';

  String get categoryLabel {
    switch (category) {
      case 'fashion':
        return 'FASHION';
      case 'jewellery':
        return 'JEWELLERY';
      case 'bags':
        return 'BAGS';
      case 'india':
        return 'INDIA COLLECTION';
      case 'uk':
        return 'UK COLLECTION';
      default:
        return 'COLLECTION';
    }
  }

  String get navKey {
    switch (category) {
      case 'fashion':
        return 'cat_fashion';
      case 'jewellery':
        return 'cat_jewellery';
      case 'bags':
        return 'cat_bags';
      case 'india':
        return 'india';
      case 'uk':
        return 'uk';
      default:
        return 'home';
    }
  }
}

// Default (fallback) lists - asal list loadCatalogFromAssets() se bhi ban jati hai
const String _bannerBase = 'assets/images/banners';

List<Product> fashionProducts = List<Product>.generate(
  22,
  (i) => Product(
    'Fashion Collection ${_two(i + 1)}',
    '$_bannerBase/fashion/F W${i + 1}.jpeg',
    i == 0 ? 120 : (i == 1 ? 135 : 145 + (i - 2) * 10),
    'fashion',
  ),
);

List<Product> jewelleryProducts = List<Product>.generate(
  20,
  (i) => Product(
    'Jewellery Collection ${_two(i + 1)}',
    '$_bannerBase/jewellery/J W${i + 1}.jpeg',
    150 + i * 15,
    'jewellery',
  ),
);

List<Product> _bagGroup(String title, String folder, String filePrefix,
    int count, int startNo, int basePrice, int step) {
  return List<Product>.generate(
    count,
    (i) => Product(
      '$title ${_two(i + 1)}',
      '$_bannerBase/bags/$folder/$filePrefix B W${startNo + i}.jpeg',
      basePrice + i * step,
      'bags',
      title,
    ),
  );
}

List<Product> bagsProducts = [
  ..._bagGroup('Automobiles & Motorcycle', 'Automobiles & Motorcycle',
      'Automobiles & Motorcycle', 12, 1, 120, 15),
  ..._bagGroup('Sports & Outdoor', 'Sports & outdoor', 'Sports & outdoor', 12,
      13, 140, 15),
  ..._bagGroup('Kids & Toy', 'Kids & toy', 'Kids & Toy', 11, 25, 100, 10),
  ..._bagGroup('Computer & Accessories', 'Computer & Accessories',
      'Computer & Accessories', 12, 36, 130, 15),
];

List<Product> indiaProducts = [
  Product('India Collection 01', 'assets/images/banners/banner5.jpeg', 180,
      'india'),
];

List<Product> ukProducts = [
  Product('UK Collection 01', 'assets/images/banners/banner6.jpeg', 200, 'uk'),
];

List<Product> allProducts = [
  ...fashionProducts,
  ...jewelleryProducts,
  ...bagsProducts,
  ...indiaProducts,
  ...ukProducts,
];

List<Product> newArrivalProducts = [
  ...fashionProducts.reversed.take(4),
  ...jewelleryProducts.reversed.take(4),
  ...bagsProducts.reversed.take(4),
  ...indiaProducts,
  ...ukProducts,
];

List<Product> bestSellerProducts = [
  ...fashionProducts.take(4),
  ...jewelleryProducts.take(4),
  ...bagsProducts.take(4),
];

// ============================================================================
// AUTO CATALOG: folders ki saari images khud dhoond leta hai
//   fashion/            -> Fashion
//   jewellery/          -> Jewellery
//   bags/<folder>/      -> Bags (har subfolder ek group)
// Folder mein nayi image daalein, app dobara chalayein, wo khud show hogi.
// (Folder pubspec.yaml ke assets mein likha hona zaroori hai.)
// ============================================================================
String _two(int n) => n.toString().padLeft(2, '0');

bool _isImage(String path) {
  final l = path.toLowerCase();
  return l.endsWith('.jpg') ||
      l.endsWith('.jpeg') ||
      l.endsWith('.png') ||
      l.endsWith('.webp');
}

int _numIn(String path) {
  final name = path.split('/').last;
  final m = RegExp(r'(\d+)').allMatches(name).toList();
  if (m.isEmpty) return 0;
  return int.tryParse(m.last.group(1)!) ?? 0;
}

List<String> _sortedAssets(Iterable<String> list) {
  final l = list.toList();
  l.sort((a, b) {
    final c = _numIn(a).compareTo(_numIn(b));
    return c != 0 ? c : a.compareTo(b);
  });
  return l;
}

String _titleCase(String s) {
  return s
      .split(' ')
      .map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1))
      .join(' ');
}

// folder ka naam ek jaisa bana deta hai:
// 'Kids & toy' / 'Kids_and_toy' / 'kids-toy'  ->  'kids_and_toy'
String _norm(String s) {
  final n = s
      .toLowerCase()
      .replaceAll('&', ' and ')
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_');
  return n.replaceAll(RegExp(r'^_+|_+$'), '');
}

String _prettyGroup(String folder) {
  switch (_norm(folder)) {
    case 'automobiles_and_motorcycle':
      return 'Automobiles & Motorcycle';
    case 'sports_and_outdoor':
      return 'Sports & Outdoor';
    case 'kids_and_toy':
      return 'Kids & Toy';
    case 'computer_and_accessories':
      return 'Computer & Accessories';
    default:
      return _titleCase(folder.replaceAll('_', ' ').replaceAll('-', ' '));
  }
}

int _bagPrice(String folder, int i) {
  switch (_norm(folder)) {
    case 'automobiles_and_motorcycle':
      return 120 + i * 15;
    case 'sports_and_outdoor':
      return 140 + i * 15;
    case 'kids_and_toy':
      return 100 + i * 10;
    case 'computer_and_accessories':
      return 130 + i * 15;
    default:
      return 120 + i * 15;
  }
}

int _bagOrder(String folder) {
  const order = [
    'automobiles_and_motorcycle',
    'sports_and_outdoor',
    'kids_and_toy',
    'computer_and_accessories',
  ];
  final i = order.indexOf(_norm(folder));
  return i == -1 ? 99 : i;
}

void rebuildCatalog() {
  allProducts = [
    ...fashionProducts,
    ...jewelleryProducts,
    ...bagsProducts,
    ...indiaProducts,
    ...ukProducts,
  ];
  newArrivalProducts = [
    ...fashionProducts.reversed.take(4),
    ...jewelleryProducts.reversed.take(4),
    ...bagsProducts.reversed.take(4),
    ...indiaProducts,
    ...ukProducts,
  ];
  bestSellerProducts = [
    ...fashionProducts.take(4),
    ...jewelleryProducts.take(4),
    ...bagsProducts.take(4),
  ];
  appState.resetIndex();
}

Future<void> loadCatalogFromAssets() async {
  try {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final all = manifest.listAssets().where(_isImage).toList();
    const base = 'assets/images/banners/';

    Iterable<String> inFolder(String folder) {
      final prefix = '$base$folder/'.toLowerCase();
      return all.where((a) => a.toLowerCase().startsWith(prefix));
    }

    // ---- fashion ----
    final fashion = _sortedAssets(inFolder('fashion'));
    if (fashion.isNotEmpty) {
      fashionProducts = [
        for (int i = 0; i < fashion.length; i++)
          Product(
            'Fashion Collection ${_two(i + 1)}',
            fashion[i],
            i == 0 ? 120 : (i == 1 ? 135 : 145 + (i - 2) * 10),
            'fashion',
          ),
      ];
    }

    // ---- jewellery ----
    final jewel = _sortedAssets(inFolder('jewellery'));
    if (jewel.isNotEmpty) {
      jewelleryProducts = [
        for (int i = 0; i < jewel.length; i++)
          Product(
            'Jewellery Collection ${_two(i + 1)}',
            jewel[i],
            150 + i * 15,
            'jewellery',
          ),
      ];
    }

    // ---- india / uk (folder ka naam india... ya uk... ho) ----
    List<String> topFolderFiles(bool Function(String n) test) {
      final prefix = base.toLowerCase();
      final out = <String>[];
      for (final a in all) {
        if (!a.toLowerCase().startsWith(prefix)) continue;
        final parts = a.substring(prefix.length).split('/');
        if (parts.length < 2) continue; // seedhi banners folder ki files nahi
        if (test(_norm(parts.first))) out.add(a);
      }
      return _sortedAssets(out);
    }

    final india = topFolderFiles((n) => n.startsWith('india'));
    if (india.isNotEmpty) {
      indiaProducts = [
        for (int i = 0; i < india.length; i++)
          Product('India Collection ${_two(i + 1)}', india[i], 180 + i * 15,
              'india'),
      ];
    }

    final uk = topFolderFiles((n) => n == 'uk' || n.startsWith('uk_'));
    if (uk.isNotEmpty) {
      ukProducts = [
        for (int i = 0; i < uk.length; i++)
          Product('UK Collection ${_two(i + 1)}', uk[i], 200 + i * 15, 'uk'),
      ];
    }

    // ---- bags (har subfolder ek group) ----
    final bagsPrefix = '${base}bags/'.toLowerCase();
    final Map<String, List<String>> groups = {};
    for (final a in all) {
      if (!a.toLowerCase().startsWith(bagsPrefix)) continue;
      final rest = a.substring(bagsPrefix.length);
      final parts = rest.split('/');
      final folder = parts.length > 1 ? parts.first : 'Bags';
      groups.putIfAbsent(folder, () => []).add(a);
    }

    if (groups.isNotEmpty) {
      final names = groups.keys.toList();
      names.sort((a, b) {
        final c = _bagOrder(a).compareTo(_bagOrder(b));
        return c != 0 ? c : a.toLowerCase().compareTo(b.toLowerCase());
      });

      final out = <Product>[];
      for (final folder in names) {
        final files = _sortedAssets(groups[folder]!);
        final title = _prettyGroup(folder);
        for (int i = 0; i < files.length; i++) {
          out.add(Product(
            '$title ${_two(i + 1)}',
            files[i],
            _bagPrice(folder, i),
            'bags',
            title,
          ));
        }
      }
      bagsProducts = out;
    }

    debugPrint('MEER catalog -> fashion: ${fashion.length}, '
        'jewellery: ${jewel.length}, india: ${india.length}, uk: ${uk.length}, '
        'bags folders: ${groups.map((k, v) => MapEntry(k, v.length))}');
    if (groups.isEmpty) {
      final sample = manifest
          .listAssets()
          .where((a) => a.toLowerCase().contains('bags'))
          .take(10)
          .toList();
      debugPrint(
          'MEER catalog -> bags images NOT found. Assets with "bags": $sample');
    }

    rebuildCatalog();
  } catch (e) {
    debugPrint('MEER catalog error: $e');
    // manifest na mile to code mein likhi hui purani lists hi chalengi
  }
}

String describeProduct(Product p) {
  switch (p.category) {
    case 'jewellery':
      return 'A beautifully crafted piece designed to add a touch of timeless '
          'elegance to every occasion. Fine detailing and a luxurious finish '
          'make it a statement you will love to wear.';
    case 'bags':
      return 'A refined bag that blends everyday practicality with luxury '
          'styling. Spacious, durable and designed to carry you through your '
          'day in style.';
    case 'fashion':
      return 'An elegant fashion piece tailored for comfort and style. '
          'Designed with a graceful fit and premium feel, perfect for both '
          'special occasions and everyday luxury.';
    default:
      return 'A signature piece from our exclusive collection, chosen for its '
          'elegance, quality and timeless appeal.';
  }
}

// ============================================================================
// APP STATE (cart + wishlist)
// ============================================================================
class AppState extends ChangeNotifier {
  final Map<String, int> _cart = {};
  final Set<String> _wishlist = {};

  Map<String, Product>? _idx;

  Map<String, Product> get _byId =>
      _idx ??= {for (final p in allProducts) p.id: p};

  void resetIndex() {
    _idx = null;
  }

  // ---- cart ----
  List<MapEntry<Product, int>> get cartItems {
    final out = <MapEntry<Product, int>>[];
    _cart.forEach((id, qty) {
      final p = _byId[id];
      if (p != null) out.add(MapEntry(p, qty));
    });
    return out;
  }

  int get cartCount {
    int t = 0;
    for (final q in _cart.values) {
      t += q;
    }
    return t;
  }

  int get subtotal {
    int t = 0;
    for (final e in cartItems) {
      t += e.key.price * e.value;
    }
    return t;
  }

  int get shipping =>
      (cartCount == 0 || subtotal >= kFreeShippingLimit) ? 0 : kShippingFee;

  int get total => subtotal + shipping;

  void addToCart(Product p, {int qty = 1}) {
    _cart[p.id] = (_cart[p.id] ?? 0) + qty;
    notifyListeners();
  }

  void setQty(Product p, int qty) {
    if (qty <= 0) {
      _cart.remove(p.id);
    } else {
      _cart[p.id] = qty;
    }
    notifyListeners();
  }

  void removeFromCart(Product p) {
    _cart.remove(p.id);
    notifyListeners();
  }

  void clearCart() {
    _cart.clear();
    notifyListeners();
  }

  // ---- wishlist ----
  bool isWished(Product p) => _wishlist.contains(p.id);

  void toggleWish(Product p) {
    if (_wishlist.contains(p.id)) {
      _wishlist.remove(p.id);
    } else {
      _wishlist.add(p.id);
    }
    notifyListeners();
  }

  int get wishCount => _wishlist.length;

  List<Product> get wishlist =>
      allProducts.where((p) => _wishlist.contains(p.id)).toList();
}

final AppState appState = AppState();

// ============================================================================
// AUTH STATE (login / logout)
// ============================================================================
class AuthState extends ChangeNotifier {
  bool loggedIn = false;
  String? token;
  String? name;
  String? email;

  void signIn(dynamic data, String fallbackEmail) {
    String? tok;
    String? nm;
    if (data is Map) {
      final t = data['token'] ?? data['accessToken'];
      if (t != null) tok = t.toString();
      final u = data['user'];
      if (u is Map) {
        final n = u['name'] ?? u['username'] ?? u['fullName'];
        if (n != null) nm = n.toString();
      }
      if (nm == null) {
        final n = data['name'] ?? data['username'];
        if (n != null) nm = n.toString();
      }
    }
    token = tok;
    name = nm ?? fallbackEmail.split('@').first;
    email = fallbackEmail;
    loggedIn = true;
    notifyListeners();
  }

  void signOut() {
    FakeApiService.logout();
    loggedIn = false;
    token = null;
    name = null;
    email = null;
    notifyListeners();
  }
}

final AuthState authState = AuthState();

// ============================================================================
// API SERVICE (real backend ke liye - abhi app FakeApiService use kar rahi hai)
// ============================================================================
class ApiService {
  static const String baseUrl = kBaseUrl;

  static String? token;

  static Map<String, String> get _headers {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Map<String, dynamic> _handle(http.Response response) {
    dynamic data;
    try {
      data = jsonDecode(response.body);
    } catch (_) {
      data = {'message': response.body};
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (data is Map) return Map<String, dynamic>.from(data);
      return {'data': data};
    }

    String message = 'Something went wrong.';
    if (data is Map && data['message'] != null) {
      message = data['message'].toString();
    }
    throw Exception(message);
  }

  static Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final response = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: jsonEncode(body),
    );
    return _handle(response);
  }

  // ---- customer auth ----
  static Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String email,
    required String password,
  }) {
    return _post('/api/register', {
      'name': name,
      'email': email,
      'password': password,
    });
  }

  static Future<Map<String, dynamic>> loginCustomer({
    required String email,
    required String password,
  }) async {
    final data = await _post('/api/login', {
      'email': email,
      'password': password,
    });
    if (data['token'] != null) {
      token = data['token'].toString();
    }
    return data;
  }

  // ---- orders ----
  static Future<Map<String, dynamic>> createOrder({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String customerAddress,
    required String customerCity,
    required List<Map<String, dynamic>> products,
    required num totalAmount,
  }) {
    return _post('/api/orders', {
      'customerName': customerName,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'customerCity': customerCity,
      'products': products,
      'totalAmount': totalAmount,
    });
  }

  static void logout() {
    token = null;
  }
}

// ============================================================================
// HELPERS
// ============================================================================
bool isMobile(BuildContext c) => MediaQuery.of(c).size.width < 700;

String money(int v) => '\$$v';

Widget wrapMax(Widget child) {
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1320),
      child: child,
    ),
  );
}

void showMsg(BuildContext context, String text,
    {String? actionLabel, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(text, style: const TextStyle(letterSpacing: 1)),
      backgroundColor: kDark,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: kGoldSoft,
              onPressed: onAction ?? () {},
            ),
    ),
  );
}

String friendlyError(Object e) {
  if (e is TimeoutException) {
    return 'Server did not respond. Check WiFi and server address.';
  }
  final msg = e.toString().replaceFirst('Exception: ', '');
  if (msg.contains('SocketException') ||
      msg.contains('ClientException') ||
      msg.contains('Connection') ||
      msg.contains('Failed host lookup')) {
    return 'Cannot reach the server. Check WiFi and server address.';
  }
  return msg;
}

void pushPage(BuildContext c, Widget page) {
  Navigator.of(c).push(MaterialPageRoute(builder: (_) => page));
}

class ScrollReq {
  final String key;
  ScrollReq(this.key);
}

final ValueNotifier<ScrollReq?> homeScroll = ValueNotifier<ScrollReq?>(null);

void goHomeAndScroll(BuildContext context, String key) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  WidgetsBinding.instance.addPostFrameCallback((_) {
    homeScroll.value = ScrollReq(key);
  });
}

// Poori website ka navigation ek jagah
void siteNav(BuildContext context, String key) {
  switch (key) {
    case 'home':
    case 'categories':
      goHomeAndScroll(context, key);
      break;
    case 'new':
      pushPage(
        context,
        CategoryPage(
          eyebrow: 'JUST LANDED',
          title: 'NEW ARRIVALS',
          products: newArrivalProducts,
        ),
      );
      break;
    case 'best':
      pushPage(
        context,
        CategoryPage(
          eyebrow: 'MOST LOVED',
          title: 'BEST SELLERS',
          products: bestSellerProducts,
        ),
      );
      break;
    case 'india':
      pushPage(
        context,
        CategoryPage(
          eyebrow: 'TRADITIONAL ELEGANCE',
          title: 'INDIA COLLECTION',
          products: indiaProducts,
        ),
      );
      break;
    case 'uk':
      pushPage(
        context,
        CategoryPage(
          eyebrow: 'MODERN LUXURY',
          title: 'UK COLLECTION',
          products: ukProducts,
        ),
      );
      break;
    case 'cat_fashion':
      pushPage(
        context,
        CategoryPage(
          eyebrow: 'FASHION COLLECTION',
          title: 'LATEST FASHION',
          products: fashionProducts,
        ),
      );
      break;
    case 'cat_jewellery':
      pushPage(
        context,
        CategoryPage(
          eyebrow: 'JEWELLERY COLLECTION',
          title: 'TIMELESS JEWELLERY',
          products: jewelleryProducts,
        ),
      );
      break;
    case 'cat_bags':
      pushPage(
        context,
        CategoryPage(
          eyebrow: 'BAGS COLLECTION',
          title: 'LUXURY BAGS',
          products: bagsProducts,
        ),
      );
      break;
    case 'contact':
    case 'shipping':
    case 'returns':
    case 'privacy':
    case 'blogs':
      pushPage(context, InfoPage(pageKey: key));
      break;
    case 'cart':
      pushPage(context, const CartPage());
      break;
    case 'wishlist':
      pushPage(context, const WishlistPage());
      break;
    case 'search':
      pushPage(context, const SearchPage());
      break;
    default:
      break;
  }
}

InputDecoration fieldDeco(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle:
        const TextStyle(color: kGoldDark, fontSize: 13, letterSpacing: 1),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: kLine),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: kGold, width: 1.5),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
    ),
  );
}

// ============================================================================
// SMALL REUSABLE WIDGETS
// ============================================================================
class Clickable extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;

  const Clickable({super.key, required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: child,
      ),
    );
  }
}

class HoverText extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final Color color;
  final Color hoverColor;
  final double fontSize;
  final double letterSpacing;
  final FontWeight weight;
  final bool underline;

  const HoverText(
    this.text, {
    super.key,
    required this.onTap,
    this.color = Colors.white,
    this.hoverColor = kGoldSoft,
    this.fontSize = 12,
    this.letterSpacing = 1.5,
    this.weight = FontWeight.w500,
    this.underline = false,
  });

  @override
  State<HoverText> createState() => _HoverTextState();
}

class _HoverTextState extends State<HoverText> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 3),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: widget.underline && _hover
                    ? kGoldSoft
                    : Colors.transparent,
                width: 1,
              ),
            ),
          ),
          child: Text(
            widget.text,
            style: TextStyle(
              color: _hover ? widget.hoverColor : widget.color,
              fontSize: widget.fontSize,
              letterSpacing: widget.letterSpacing,
              fontWeight: widget.weight,
            ),
          ),
        ),
      ),
    );
  }
}

class LuxButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final bool onDark;
  final IconData? icon;
  final bool expand;
  final double? height;

  const LuxButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = true,
    this.onDark = false,
    this.icon,
    this.expand = false,
    this.height,
  });

  @override
  State<LuxButton> createState() => _LuxButtonState();
}

class _LuxButtonState extends State<LuxButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    Color border;

    if (widget.filled && !widget.onDark) {
      bg = _hover ? kGold : kDark;
      fg = _hover ? kDark : Colors.white;
      border = bg;
    } else if (widget.filled && widget.onDark) {
      bg = _hover ? Colors.white : kGold;
      fg = kDark;
      border = bg;
    } else if (!widget.filled && !widget.onDark) {
      bg = _hover ? kDark : Colors.transparent;
      fg = _hover ? Colors.white : kDark;
      border = kDark;
    } else {
      bg = _hover ? kGold : Colors.transparent;
      fg = _hover ? kDark : Colors.white;
      border = kGoldSoft;
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: widget.expand ? double.infinity : null,
          height: widget.height,
          alignment: (widget.expand || widget.height != null)
              ? Alignment.center
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 16, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: fg,
                  fontSize: 12,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AssetImg extends StatelessWidget {
  final String path;
  final BoxFit fit;
  final int cacheWidth; // images ko chhota decode karta hai (RAM bachata hai)

  const AssetImg(this.path,
      {super.key, this.fit = BoxFit.cover, this.cacheWidth = 600});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      path,
      fit: fit,
      cacheWidth: cacheWidth,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (c, e, s) {
        return Container(
          color: const Color(0xFFEDE6DA),
          alignment: Alignment.center,
          child: const Icon(Icons.image_outlined, color: kBronze, size: 32),
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String label;
  final String heading;
  final bool center;

  const SectionTitle({
    super.key,
    required this.label,
    required this.heading,
    this.center = false,
  });

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return Column(
      crossAxisAlignment:
          center ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            letterSpacing: 3,
            color: kBronze,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          heading,
          textAlign: center ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: mobile ? 24 : 30,
            letterSpacing: 2,
            color: kDark,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class QtyStepper extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;

  const QtyStepper({super.key, required this.qty, required this.onChanged});

  Widget _btn(IconData icon, VoidCallback onTap) {
    return Clickable(
      onTap: onTap,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Icon(icon, size: 16, color: kDark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kLine),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _btn(Icons.remove, () => onChanged(qty - 1)),
          SizedBox(
            width: 32,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),
          ),
          _btn(Icons.add, () => onChanged(qty + 1)),
        ],
      ),
    );
  }
}

// ============================================================================
// PAGE SHELL (har page mein: top bar + content + footer)
// ============================================================================
class PageShell extends StatelessWidget {
  final Widget child;

  const PageShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MeerTopBar(),
              child,
              const MeerFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

class PageBanner extends StatelessWidget {
  final String eyebrow;
  final String title;

  const PageBanner({super.key, required this.eyebrow, required this.title});

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    return Container(
      width: double.infinity,
      color: kDark,
      padding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: mobile ? 36 : 56,
      ),
      child: Column(
        children: [
          Text(
            eyebrow,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: kGoldSoft,
              fontSize: 12,
              letterSpacing: 4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: mobile ? 22 : 38,
              letterSpacing: mobile ? 2.5 : 4,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              HoverText(
                'HOME',
                fontSize: 11,
                color: Colors.white70,
                onTap: () => siteNav(context, 'home'),
              ),
              const Text(
                '   /   ',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
              Flexible(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: kGoldSoft,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TOP BAR: announcement + header + navigation
// ============================================================================
class AuthStrip extends StatelessWidget {
  const AuthStrip({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    return AnimatedBuilder(
      animation: authState,
      builder: (context, _) {
        final List<Widget> items;
        if (authState.loggedIn) {
          items = [
            Flexible(
              child: Text(
                'Hi, ${authState.name ?? ''}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  letterSpacing: 1,
                  color: kGoldDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Text('   |   ',
                style: TextStyle(color: Colors.black26, fontSize: 11)),
            HoverText(
              'LOGOUT',
              color: kDark,
              hoverColor: kGoldDark,
              fontSize: 11,
              onTap: () {
                authState.signOut();
                showMsg(context, 'You have been logged out');
              },
            ),
          ];
        } else {
          items = [
            HoverText(
              'LOGIN',
              color: kDark,
              hoverColor: kGoldDark,
              fontSize: 11,
              onTap: () => pushPage(context, const AuthPage()),
            ),
            const Text('   |   ',
                style: TextStyle(color: Colors.black26, fontSize: 11)),
            HoverText(
              'REGISTRATION',
              color: kDark,
              hoverColor: kGoldDark,
              fontSize: 11,
              onTap: () =>
                  pushPage(context, const AuthPage(startOnRegister: true)),
            ),
          ];
        }

        return Container(
          color: kCream,
          padding: EdgeInsets.fromLTRB(
              mobile ? 14 : 35, 8, mobile ? 14 : 35, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: items,
          ),
        );
      },
    );
  }
}

class MeerTopBar extends StatelessWidget {
  const MeerTopBar({super.key});

  static const List<List<String>> navItems = [
    ['HOME', 'home'],
    ['CATEGORIES', 'categories'],
    ['NEW ARRIVALS', 'new'],
    ['INDIA COLLECTION', 'india'],
    ['UK COLLECTION', 'uk'],
    ['BEST SELLERS', 'best'],
  ];

  Widget _badgeIcon(
      IconData icon, int count, String tip, VoidCallback onTap) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          onPressed: onTap,
          tooltip: tip,
          icon: Icon(icon, color: kDark),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: IgnorePointer(
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: kGold,
                  borderRadius: BorderRadius.all(Radius.circular(9)),
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: kDark,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ANNOUNCEMENT
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          color: kDark,
          child: const Center(
            child: Text(
              'FREE WORLDWIDE SHIPPING OVER \$100',
              style: TextStyle(
                color: kGold,
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        const AuthStrip(),

        // HEADER
        AnimatedBuilder(
          animation: appState,
          builder: (context, _) {
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 14 : 35,
                vertical: mobile ? 12 : 18,
              ),
              decoration: const BoxDecoration(
                color: kCream,
                border: Border(
                  bottom: BorderSide(color: kGold, width: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Clickable(
                    onTap: () => siteNav(context, 'home'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MEER',
                          style: TextStyle(
                            fontSize: mobile ? 24 : 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 5,
                            color: kDark,
                          ),
                        ),
                        const Text(
                          'LUXURY COLLECTION',
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 3,
                            color: kGoldDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _badgeIcon(Icons.search, 0, 'Search',
                      () => siteNav(context, 'search')),
                  _badgeIcon(
                    appState.wishCount > 0
                        ? Icons.favorite
                        : Icons.favorite_border,
                    appState.wishCount,
                    'Wishlist',
                    () => siteNav(context, 'wishlist'),
                  ),
                  _badgeIcon(
                    Icons.shopping_bag_outlined,
                    appState.cartCount,
                    'Shopping bag',
                    () => siteNav(context, 'cart'),
                  ),
                ],
              ),
            );
          },
        ),

        // NAVIGATION
        Container(
          color: kDark,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: MediaQuery.of(context).size.width,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final item in navItems)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: mobile ? 14 : 24,
                        vertical: 14,
                      ),
                      child: HoverText(
                        item[0],
                        underline: true,
                        onTap: () => siteNav(context, item[1]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// FOOTER
// ============================================================================
class MeerFooter extends StatelessWidget {
  const MeerFooter({super.key});

  Widget _feature(IconData icon, String title, String sub) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: kBronze, size: 30),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: kDark,
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              sub,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }

  Widget _linkColumn(
      BuildContext context, String title, List<List<String>> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: kGoldSoft,
            fontSize: 13,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(width: 30, height: 1, color: kGold),
        const SizedBox(height: 18),
        for (final l in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: HoverText(
              l[0],
              color: Colors.white70,
              hoverColor: kGoldSoft,
              fontSize: 13,
              letterSpacing: 0.5,
              onTap: () => siteNav(context, l[1]),
            ),
          ),
      ],
    );
  }

  Widget _contactRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kGoldSoft, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _social(BuildContext context, IconData icon, String name) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Clickable(
        onTap: () => showMsg(context, '$name page link yahan add karein'),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            border: Border.all(color: kGoldSoft),
          ),
          child: Icon(icon, color: kGoldSoft, size: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final hPad = mobile ? 20.0 : 35.0;

    final brand = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MEER',
          style: TextStyle(
            color: kGoldSoft,
            fontSize: 30,
            fontWeight: FontWeight.w700,
            letterSpacing: 5,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'LUXURY COLLECTION',
          style: TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 3),
        ),
        const SizedBox(height: 20),
        const Text(
          'Discover timeless fashion, jewellery and luxury collections '
          'from around the world.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.7),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            _social(context, Icons.facebook, 'Facebook'),
            _social(context, Icons.camera_alt_outlined, 'Instagram'),
            _social(context, Icons.play_circle_outline, 'YouTube'),
            _social(context, Icons.chat_bubble_outline, 'WhatsApp'),
          ],
        ),
      ],
    );

    final quick = _linkColumn(context, 'QUICK LINKS', [
      ['Home', 'home'],
      ['New Arrivals', 'new'],
      ['Best Sellers', 'best'],
      ['Blogs', 'blogs'],
    ]);

    final collections = _linkColumn(context, 'COLLECTIONS', [
      ['Fashion', 'cat_fashion'],
      ['Jewellery', 'cat_jewellery'],
      ['Bags', 'cat_bags'],
      ['India Collection', 'india'],
      ['UK Collection', 'uk'],
    ]);

    final service = _linkColumn(context, 'CUSTOMER SERVICE', [
      ['Contact Us', 'contact'],
      ['Shipping & Delivery', 'shipping'],
      ['Returns', 'returns'],
      ['Privacy Policy', 'privacy'],
    ]);

    final contact = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VISIT & CONTACT',
          style: TextStyle(
            color: kGoldSoft,
            fontSize: 13,
            letterSpacing: 2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(width: 30, height: 1, color: kGold),
        const SizedBox(height: 18),
        _contactRow(Icons.location_on_outlined, kContactAddress),
        _contactRow(Icons.phone_outlined, kContactPhone),
        _contactRow(Icons.mail_outline, kContactEmail),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // FEATURE STRIP
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 34),
          child: wrapMax(
            Wrap(
              alignment: WrapAlignment.spaceEvenly,
              runSpacing: 22,
              spacing: 40,
              children: [
                _feature(Icons.local_shipping_outlined, 'FREE SHIPPING',
                    'On orders over \$100'),
                _feature(Icons.verified_user_outlined, 'SECURE PAYMENT',
                    'Safe & protected'),
                _feature(
                    Icons.autorenew, 'EASY RETURNS', 'Hassle-free process'),
                _feature(Icons.support_agent, 'CUSTOMER CARE',
                    'Always here to help'),
              ],
            ),
          ),
        ),

        // NEWSLETTER
        const NewsletterBand(),

        // MAIN FOOTER
        Container(
          color: kDark,
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 55),
          child: wrapMax(
            mobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      brand,
                      const SizedBox(height: 36),
                      quick,
                      const SizedBox(height: 24),
                      collections,
                      const SizedBox(height: 24),
                      service,
                      const SizedBox(height: 24),
                      contact,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: brand),
                      const SizedBox(width: 30),
                      Expanded(flex: 2, child: quick),
                      Expanded(flex: 2, child: collections),
                      Expanded(flex: 2, child: service),
                      Expanded(flex: 3, child: contact),
                    ],
                  ),
          ),
        ),

        // BOTTOM BAR
        Container(
          color: const Color(0xFF0F0C0A),
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
          child: wrapMax(
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 14,
              spacing: 20,
              children: [
                const Text(
                  '\u00A9 2026 MEER LUXURY COLLECTION  \u2022  ALL RIGHTS RESERVED',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1,
                  ),
                ),
                const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.credit_card, color: Colors.white38, size: 22),
                    SizedBox(width: 12),
                    Icon(Icons.account_balance_wallet_outlined,
                        color: Colors.white38, size: 22),
                    SizedBox(width: 12),
                    Icon(Icons.payments_outlined,
                        color: Colors.white38, size: 22),
                  ],
                ),
                HoverText(
                  'BACK TO TOP  \u2191',
                  fontSize: 11,
                  onTap: () => siteNav(context, 'home'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class NewsletterBand extends StatefulWidget {
  const NewsletterBand({super.key});

  @override
  State<NewsletterBand> createState() => _NewsletterBandState();
}

class _NewsletterBandState extends State<NewsletterBand> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (!v.contains('@') || !v.contains('.')) {
      showMsg(context, 'Please enter a valid email address');
      return;
    }
    showMsg(context, 'Thank you for subscribing!');
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'JOIN THE MEER CIRCLE',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            letterSpacing: 3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Be the first to know about new arrivals and exclusive offers.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
      ],
    );

    final form = Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: TextField(
              controller: _c,
              onSubmitted: (_) => _submit(),
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'Your email address',
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ),
        LuxButton(
          label: 'SUBSCRIBE',
          onDark: true,
          height: 48,
          onTap: _submit,
        ),
      ],
    );

    return Container(
      color: const Color(0xFF241E18),
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 20 : 35,
        vertical: 44,
      ),
      child: wrapMax(
        mobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text, const SizedBox(height: 22), form],
              )
            : Row(
                children: [
                  Expanded(flex: 5, child: text),
                  const SizedBox(width: 40),
                  Expanded(flex: 5, child: form),
                ],
              ),
      ),
    );
  }
}

// ============================================================================
// PRODUCT CARD + GRID
// ============================================================================
class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final wished = appState.isWished(product);

        return Clickable(
          onTap: () => pushPage(context, ProductDetailPage(product: product)),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 15,
                  spreadRadius: 1,
                  color: Color.fromRGBO(0, 0, 0, 0.08),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                          child: AssetImg(product.image),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Clickable(
                          onTap: () {
                            appState.toggleWish(product);
                            showMsg(
                              context,
                              appState.isWished(product)
                                  ? 'Added to wishlist'
                                  : 'Removed from wishlist',
                            );
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              wished ? Icons.favorite : Icons.favorite_border,
                              size: 18,
                              color: wished ? Colors.redAccent : kDark,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(mobile ? 10 : 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: mobile ? 12.5 : 14,
                                fontWeight: FontWeight.w600,
                                color: kDark,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              product.priceText,
                              style: TextStyle(
                                fontSize: mobile ? 15 : 16,
                                fontWeight: FontWeight.w700,
                                color: kBronze,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Clickable(
                        onTap: () {
                          appState.addToCart(product);
                          showMsg(
                            context,
                            'Added to your bag',
                            actionLabel: 'VIEW BAG',
                            onAction: () => siteNav(context, 'cart'),
                          );
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          color: kDark,
                          child: const Icon(
                            Icons.add_shopping_cart,
                            color: kGoldSoft,
                            size: 17,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ProductGrid extends StatelessWidget {
  final List<Product> products;

  const ProductGrid({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cols = w < 520 ? 2 : (w < 900 ? 3 : 4);
        final gap = w < 520 ? 12.0 : 22.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: products.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: gap,
            mainAxisSpacing: gap + 6,
            childAspectRatio: w < 520 ? 0.56 : 0.68,
          ),
          itemBuilder: (context, i) => ProductCard(product: products[i]),
        );
      },
    );
  }
}

// ============================================================================
// HOME PAGE
// ============================================================================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ScrollController _scroll = ScrollController();

  final Map<String, GlobalKey> _sections = {
    'categories': GlobalKey(),
    'fashion': GlobalKey(),
    'jewellery': GlobalKey(),
    'bags': GlobalKey(),
    'global': GlobalKey(),
  };

  final List<List<String>> categories = [
    ['FASHION', 'assets/images/banners/fashion.jpeg', 'cat_fashion'],
    ['JEWELLERY', 'assets/images/banners/jewellary.jpeg', 'cat_jewellery'],
    ['BAGS', 'assets/images/banners/bags.jpeg', 'cat_bags'],
    ['INDIA COLLECTION', 'assets/images/banners/banner5.jpeg', 'india'],
    ['UK COLLECTION', 'assets/images/banners/banner6.jpeg', 'uk'],
  ];

  @override
  void initState() {
    super.initState();
    homeScroll.addListener(_onScrollRequest);
  }

  @override
  void dispose() {
    homeScroll.removeListener(_onScrollRequest);
    _scroll.dispose();
    super.dispose();
  }

  void _onScrollRequest() {
    final req = homeScroll.value;
    if (req == null || !mounted) return;

    if (req.key == 'home') {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      }
      return;
    }

    final ctx = _sections[req.key]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    }
  }

  // ---------------- CATEGORIES ----------------
  Widget _categoryCard(List<String> c, {double? width}) {
    return Clickable(
      onTap: () => siteNav(context, c[2]),
      child: SizedBox(
        width: width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AssetImg(c[1]),
            Container(color: const Color.fromRGBO(0, 0, 0, 0.38)),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(
                      c[0],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(width: 30, height: 1, color: kGoldSoft),
                  const SizedBox(height: 10),
                  const Text(
                    'SHOP NOW',
                    style: TextStyle(
                      color: kGoldSoft,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoriesSection() {
    final mobile = isMobile(context);

    return Container(
      key: _sections['categories'],
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 16 : 35,
        vertical: 55,
      ),
      color: kCream,
      child: wrapMax(
        Column(
          children: [
            const SectionTitle(
              label: 'EXPLORE COLLECTIONS',
              heading: 'SHOP BY CATEGORY',
              center: true,
            ),
            const SizedBox(height: 35),
            if (mobile)
              SizedBox(
                height: 260,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  itemBuilder: (context, i) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 14),
                      child: _categoryCard(categories[i], width: 190),
                    );
                  },
                ),
              )
            else
              SizedBox(
                height: 320,
                child: Row(
                  children: [
                    for (int i = 0; i < categories.length; i++) ...[
                      if (i > 0) const SizedBox(width: 18),
                      Expanded(child: _categoryCard(categories[i])),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------- PRODUCT SECTIONS ----------------
  Widget _productSection({
    required String sectionKey,
    required String label,
    required String heading,
    required List<Product> products,
    required Color bgColor,
    required String viewAllKey,
    required String viewAllLabel,
  }) {
    final mobile = isMobile(context);
    final shown = products.take(8).toList();

    return Container(
      key: _sections[sectionKey],
      color: bgColor,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 16 : 30,
        vertical: 50,
      ),
      child: wrapMax(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(label: label, heading: heading),
            const SizedBox(height: 25),
            ProductGrid(products: shown),
            const SizedBox(height: 35),
            Center(
              child: LuxButton(
                label: 'VIEW ALL $viewAllLabel (${products.length})',
                filled: false,
                onTap: () => siteNav(context, viewAllKey),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- INDIA & UK ----------------
  Widget _collectionBanner({
    required String image,
    required String title,
    required String subtitle,
    required String navKey,
  }) {
    return Clickable(
      onTap: () => siteNav(context, navKey),
      child: SizedBox(
        height: 360,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: AssetImg(image),
              ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Color.fromRGBO(0, 0, 0, 0.75),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 25,
              right: 25,
              bottom: 25,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: kGoldSoft,
                      fontSize: 12,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: kGoldSoft),
                    ),
                    child: const Text(
                      'EXPLORE COLLECTION',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _globalCollections() {
    final mobile = isMobile(context);

    final india = _collectionBanner(
      image: 'assets/images/banners/banner5.jpeg',
      title: 'INDIA COLLECTION',
      subtitle: 'TRADITIONAL ELEGANCE',
      navKey: 'india',
    );
    final uk = _collectionBanner(
      image: 'assets/images/banners/banner6.jpeg',
      title: 'UK COLLECTION',
      subtitle: 'MODERN LUXURY',
      navKey: 'uk',
    );

    return Container(
      key: _sections['global'],
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: mobile ? 16 : 30,
        vertical: 55,
      ),
      child: wrapMax(
        Column(
          children: [
            const SectionTitle(
              label: 'GLOBAL COLLECTIONS',
              heading: 'INDIA & UK',
              center: true,
            ),
            const SizedBox(height: 30),
            if (mobile)
              Column(children: [india, const SizedBox(height: 20), uk])
            else
              Row(
                children: [
                  Expanded(child: india),
                  const SizedBox(width: 25),
                  Expanded(child: uk),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kCream,
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scroll,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MeerTopBar(),
              const HeroSlider(),
              _categoriesSection(),
              _productSection(
                sectionKey: 'fashion',
                label: 'FASHION COLLECTION',
                heading: 'LATEST FASHION',
                products: fashionProducts,
                bgColor: kCream,
                viewAllKey: 'cat_fashion',
                viewAllLabel: 'FASHION',
              ),
              _productSection(
                sectionKey: 'jewellery',
                label: 'JEWELLERY COLLECTION',
                heading: 'TIMELESS JEWELLERY',
                products: jewelleryProducts,
                bgColor: Colors.white,
                viewAllKey: 'cat_jewellery',
                viewAllLabel: 'JEWELLERY',
              ),
              _productSection(
                sectionKey: 'bags',
                label: 'BAGS COLLECTION',
                heading: 'LUXURY BAGS',
                products: bagsProducts,
                bgColor: kCream,
                viewAllKey: 'cat_bags',
                viewAllLabel: 'BAGS',
              ),
              _globalCollections(),
              const MeerFooter(),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// HERO SLIDER - banner ki POORI image dikhati hai (crop nahi karta)
// Tap karne par SHOP NOW wale page par jata hai, khud bhi badalta hai
// ============================================================================
class HeroSlider extends StatefulWidget {
  const HeroSlider({super.key});

  @override
  State<HeroSlider> createState() => _HeroSliderState();
}

class _HeroSliderState extends State<HeroSlider> {
  int current = 0;
  Timer? _timer;

  static const List<String> banners = [
    'assets/images/banners/banner1.jpeg',
    'assets/images/banners/banner2.jpeg',
    'assets/images/banners/banner3.jpeg',
    'assets/images/banners/banner4.jpeg',
  ];

  // banner par click karne se kis page par jaye
  static const List<String> targets = [
    'cat_fashion',
    'cat_jewellery',
    'best',
    'new',
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (mounted) {
        setState(() => current = (current + 1) % banners.length);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _go(int i) {
    setState(() => current = (i + banners.length) % banners.length);
    _startTimer();
  }

  Widget _arrow(IconData icon, VoidCallback onTap) {
    return Clickable(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: Color.fromRGBO(0, 0, 0, 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kDark,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 300),
            alignment: Alignment.topCenter,
            child: Stack(
              children: [
                Clickable(
                  onTap: () => siteNav(context, targets[current]),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 600),
                    child: Image.asset(
                      banners[current],
                      key: ValueKey<int>(current),
                      width: double.infinity,
                      fit: BoxFit.fitWidth, // poori image, width ke hisaab se
                      cacheWidth: 1600,
                      errorBuilder: (c, e, st) {
                        return Container(
                          height: 220,
                          color: const Color(0xFFEDE6DA),
                          alignment: Alignment.center,
                          child: const Icon(Icons.image_outlined,
                              color: kBronze, size: 40),
                        );
                      },
                    ),
                  ),
                ),

                // LEFT ARROW
                Positioned(
                  left: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _arrow(
                        Icons.arrow_back_ios_new, () => _go(current - 1)),
                  ),
                ),

                // RIGHT ARROW
                Positioned(
                  right: 8,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: _arrow(
                        Icons.arrow_forward_ios, () => _go(current + 1)),
                  ),
                ),

                // DOTS
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(0, 0, 0, 0.3),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(banners.length, (i) {
                          return Clickable(
                            onTap: () => _go(i),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              width: current == i ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: current == i ? kGoldSoft : Colors.white,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CATEGORY PAGE (Fashion / Jewellery / Bags / India / UK / New / Best)
// ============================================================================
class CategoryPage extends StatefulWidget {
  final String eyebrow;
  final String title;
  final List<Product> products;

  const CategoryPage({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.products,
  });

  @override
  State<CategoryPage> createState() => _CategoryPageState();
}

class _CategoryPageState extends State<CategoryPage> {
  String group = 'ALL';
  String sort = 'Featured';

  List<Product> get _visible {
    final list = widget.products
        .where((p) => group == 'ALL' || p.group == group)
        .toList();
    if (sort == 'Price: Low to High') {
      list.sort((a, b) => a.price.compareTo(b.price));
    } else if (sort == 'Price: High to Low') {
      list.sort((a, b) => b.price.compareTo(a.price));
    }
    return list;
  }

  Widget _chip(String label) {
    final sel = group == label;
    return Clickable(
      onTap: () => setState(() => group = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? kDark : Colors.white,
          border: Border.all(color: sel ? kDark : kLine),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.white : kDark,
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final visible = _visible;

    final groups = <String>[];
    for (final p in widget.products) {
      if (p.group.isNotEmpty && !groups.contains(p.group)) {
        groups.add(p.group);
      }
    }

    const sortOptions = [
      'Featured',
      'Price: Low to High',
      'Price: High to Low',
    ];

    return PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageBanner(eyebrow: widget.eyebrow, title: widget.title),
          wrapMax(
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 16 : 30,
                vertical: 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (groups.length > 1) ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _chip('ALL'),
                        for (final g in groups) _chip(g),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 8,
                    children: [
                      Text(
                        '${visible.length} PRODUCTS',
                        style: const TextStyle(
                          color: kGoldDark,
                          fontSize: 12,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      DropdownButton<String>(
                        value: sort,
                        underline: const SizedBox(),
                        iconEnabledColor: kDark,
                        style: const TextStyle(color: kDark, fontSize: 13),
                        items: sortOptions
                            .map((s) => DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => sort = v);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (visible.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(child: Text('No products found')),
                    )
                  else
                    ProductGrid(products: visible),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PRODUCT DETAIL PAGE
// ============================================================================
class ProductDetailPage extends StatefulWidget {
  final Product product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  int qty = 1;

  Widget _point(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: kBronze),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.product;
    final mobile = isMobile(context);

    final related = allProducts
        .where((x) => x.category == p.category && x.id != p.id)
        .take(4)
        .toList();

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: AspectRatio(
        aspectRatio: 0.85,
        child: AssetImg(p.image),
      ),
    );

    final info = AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final wished = appState.isWished(p);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.group.isNotEmpty ? p.group.toUpperCase() : p.categoryLabel,
              style: const TextStyle(
                color: kBronze,
                fontSize: 12,
                letterSpacing: 3,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              p.name,
              style: TextStyle(
                color: kDark,
                fontSize: mobile ? 24 : 32,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              p.priceText,
              style: const TextStyle(
                color: kBronze,
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            Container(height: 1, color: kLine),
            const SizedBox(height: 20),
            Text(
              describeProduct(p),
              style: const TextStyle(
                fontSize: 14,
                height: 1.7,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                const Text(
                  'QUANTITY',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 2,
                    color: kDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 18),
                QtyStepper(
                  qty: qty,
                  onChanged: (v) {
                    if (v >= 1) setState(() => qty = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: 26),
            Row(
              children: [
                Expanded(
                  child: LuxButton(
                    label: 'ADD TO BAG',
                    expand: true,
                    icon: Icons.shopping_bag_outlined,
                    onTap: () {
                      appState.addToCart(p, qty: qty);
                      showMsg(
                        context,
                        'Added to your bag',
                        actionLabel: 'VIEW BAG',
                        onAction: () => siteNav(context, 'cart'),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Clickable(
                  onTap: () {
                    appState.toggleWish(p);
                    showMsg(
                      context,
                      appState.isWished(p)
                          ? 'Added to wishlist'
                          : 'Removed from wishlist',
                    );
                  },
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: kDark),
                    ),
                    child: Icon(
                      wished ? Icons.favorite : Icons.favorite_border,
                      color: wished ? Colors.redAccent : kDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LuxButton(
              label: 'BUY NOW',
              expand: true,
              filled: false,
              onTap: () {
                appState.addToCart(p, qty: qty);
                pushPage(context, const CartPage());
              },
            ),
            const SizedBox(height: 28),
            _point(Icons.local_shipping_outlined,
                'Free worldwide shipping on orders over \$100'),
            _point(Icons.verified_user_outlined, 'Secure checkout'),
            _point(Icons.support_agent, 'Our team is always happy to help'),
          ],
        );
      },
    );

    return PageShell(
      child: wrapMax(
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: mobile ? 16 : 30,
            vertical: 36,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // breadcrumb
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  HoverText('HOME',
                      color: kGoldDark,
                      hoverColor: kDark,
                      fontSize: 11,
                      onTap: () => siteNav(context, 'home')),
                  const Text('  /  ',
                      style: TextStyle(color: Colors.black38, fontSize: 11)),
                  HoverText(p.categoryLabel,
                      color: kGoldDark,
                      hoverColor: kDark,
                      fontSize: 11,
                      onTap: () => siteNav(context, p.navKey)),
                  const Text('  /  ',
                      style: TextStyle(color: Colors.black38, fontSize: 11)),
                  Text(
                    p.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              if (mobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [image, const SizedBox(height: 26), info],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: image),
                    const SizedBox(width: 55),
                    Expanded(flex: 5, child: info),
                  ],
                ),
              if (related.isNotEmpty) ...[
                const SizedBox(height: 70),
                const SectionTitle(
                  label: 'DISCOVER MORE',
                  heading: 'YOU MAY ALSO LIKE',
                ),
                const SizedBox(height: 25),
                ProductGrid(products: related),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// CART PAGE
// ============================================================================
class OrderSummary extends StatelessWidget {
  final bool showButtons;

  const OrderSummary({super.key, this.showButtons = true});

  Widget _line(String a, String b, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            a,
            style: TextStyle(
              fontSize: bold ? 15 : 13,
              letterSpacing: 1,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
              color: kDark,
            ),
          ),
          Text(
            b,
            style: TextStyle(
              fontSize: bold ? 18 : 14,
              fontWeight: FontWeight.w700,
              color: bold ? kBronze : kDark,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) {
        final remaining = kFreeShippingLimit - appState.subtotal;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ORDER SUMMARY',
                style: TextStyle(
                  fontSize: 14,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 14),
              Container(height: 1, color: kLine),
              const SizedBox(height: 8),
              _line('SUBTOTAL', money(appState.subtotal)),
              _line(
                'SHIPPING',
                appState.shipping == 0 ? 'FREE' : money(appState.shipping),
              ),
              const SizedBox(height: 6),
              Container(height: 1, color: kLine),
              const SizedBox(height: 6),
              _line('TOTAL', money(appState.total), bold: true),
              if (appState.cartCount > 0 && remaining > 0) ...[
                const SizedBox(height: 10),
                Text(
                  'Add ${money(remaining)} more to get FREE shipping',
                  style: const TextStyle(
                    fontSize: 12,
                    color: kGoldDark,
                    height: 1.4,
                  ),
                ),
              ],
              if (showButtons) ...[
                const SizedBox(height: 22),
                LuxButton(
                  label: 'PROCEED TO CHECKOUT',
                  expand: true,
                  onTap: () {
                    if (appState.cartCount == 0) {
                      showMsg(context, 'Your bag is empty');
                    } else {
                      pushPage(context, const CheckoutPage());
                    }
                  },
                ),
                const SizedBox(height: 12),
                LuxButton(
                  label: 'CONTINUE SHOPPING',
                  expand: true,
                  filled: false,
                  onTap: () => siteNav(context, 'home'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  Widget _row(BuildContext context, Product p, int qty) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kLine),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Clickable(
            onTap: () => pushPage(context, ProductDetailPage(product: p)),
            child: SizedBox(
              width: 90,
              height: 112,
              child: AssetImg(p.image),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  p.categoryLabel,
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: kGoldDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  p.priceText,
                  style: const TextStyle(
                    fontSize: 14,
                    color: kBronze,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    QtyStepper(
                      qty: qty,
                      onChanged: (v) => appState.setQty(p, v),
                    ),
                    Text(
                      money(p.price * qty),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kDark,
                      ),
                    ),
                    Clickable(
                      onTap: () {
                        appState.removeFromCart(p);
                        showMsg(context, 'Removed from your bag');
                      },
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    return PageShell(
      child: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final items = appState.cartItems;

          final list = Column(
            children: [
              for (final e in items) _row(context, e.key, e.value),
            ],
          );

          Widget content;
          if (items.isEmpty) {
            content = Padding(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Column(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      size: 64, color: kBronze),
                  const SizedBox(height: 18),
                  const Text(
                    'YOUR BAG IS EMPTY',
                    style: TextStyle(
                      fontSize: 18,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Discover our collections and add your favourites.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 26),
                  LuxButton(
                    label: 'START SHOPPING',
                    onTap: () => siteNav(context, 'home'),
                  ),
                ],
              ),
            );
          } else if (mobile) {
            content = Column(
              children: [list, const SizedBox(height: 10), const OrderSummary()],
            );
          } else {
            content = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: list),
                const SizedBox(width: 30),
                const Expanded(flex: 2, child: OrderSummary()),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageBanner(eyebrow: 'YOUR SELECTION', title: 'SHOPPING BAG'),
              wrapMax(
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile ? 16 : 30,
                    vertical: 40,
                  ),
                  child: content,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// CHECKOUT PAGE
// ============================================================================
class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();

  // Country ka naam unique hai (US/Canada dono ka code +1 hai),
  // isliye dropdown ki value naam rakhi hai, code nahi.
  String _selectedCountry = 'Pakistan';

  static const List<Map<String, String>> _countryCodes = [
    {'name': 'Pakistan', 'flag': '🇵🇰', 'code': '+92'},
    {'name': 'United Kingdom', 'flag': '🇬🇧', 'code': '+44'},
    {'name': 'United States', 'flag': '🇺🇸', 'code': '+1'},
    {'name': 'Canada', 'flag': '🇨🇦', 'code': '+1'},
    {'name': 'United Arab Emirates', 'flag': '🇦🇪', 'code': '+971'},
    {'name': 'Saudi Arabia', 'flag': '🇸🇦', 'code': '+966'},
    {'name': 'Qatar', 'flag': '🇶🇦', 'code': '+974'},
    {'name': 'Australia', 'flag': '🇦🇺', 'code': '+61'},
    {'name': 'Germany', 'flag': '🇩🇪', 'code': '+49'},
    {'name': 'France', 'flag': '🇫🇷', 'code': '+33'},
    {'name': 'India', 'flag': '🇮🇳', 'code': '+91'},
    {'name': 'Turkey', 'flag': '🇹🇷', 'code': '+90'},
    {'name': 'China', 'flag': '🇨🇳', 'code': '+86'},
    {'name': 'Bangladesh', 'flag': '🇧🇩', 'code': '+880'},
    {'name': 'Afghanistan', 'flag': '🇦🇫', 'code': '+93'},
    {'name': 'South Africa', 'flag': '🇿🇦', 'code': '+27'},
    {'name': 'Malaysia', 'flag': '🇲🇾', 'code': '+60'},
    {'name': 'Singapore', 'flag': '🇸🇬', 'code': '+65'},
    {'name': 'Japan', 'flag': '🇯🇵', 'code': '+81'},
    {'name': 'Italy', 'flag': '🇮🇹', 'code': '+39'},
    {'name': 'Spain', 'flag': '🇪🇸', 'code': '+34'},
    {'name': 'Netherlands', 'flag': '🇳🇱', 'code': '+31'},
    {'name': 'New Zealand', 'flag': '🇳🇿', 'code': '+64'},
    {'name': 'Ireland', 'flag': '🇮🇪', 'code': '+353'},
    {'name': 'Oman', 'flag': '🇴🇲', 'code': '+968'},
    {'name': 'Kuwait', 'flag': '🇰🇼', 'code': '+965'},
    {'name': 'Bahrain', 'flag': '🇧🇭', 'code': '+973'},
    {'name': 'Nigeria', 'flag': '🇳🇬', 'code': '+234'},
    {'name': 'Kenya', 'flag': '🇰🇪', 'code': '+254'},
  ];

  String get _selectedCountryCode {
    for (final c in _countryCodes) {
      if (c['name'] == _selectedCountry) return c['code'] ?? '+92';
    }
    return '+92';
  }

  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    _city.dispose();
    super.dispose();
  }

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) return 'This field is required';
    return null;
  }

  Future<void> _placeOrder() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (appState.cartCount == 0) {
      showMsg(context, 'Your bag is empty');
      return;
    }

    setState(() => _submitting = true);

    final products = appState.cartItems
        .map((e) => <String, dynamic>{
              'productKey': e.key.id,
              'name': e.key.name,
              'image': e.key.image,
              'category': e.key.category,
              'price': e.key.price,
              'quantity': e.value,
            })
        .toList();

    dynamic result;
    try {
      result = await FakeApiService.createOrder(
        customerName: _name.text.trim(),
        customerEmail: _email.text.trim(),
        customerPhone: '$_selectedCountryCode ${_phone.text.trim()}',
        customerAddress: _address.text.trim(),
        customerCity: _city.text.trim(),
        products: products,
        totalAmount: appState.total.toDouble(),
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      showMsg(context, 'Order failed: ${friendlyError(e)}');
      return;
    }

    if (!mounted) return;
    setState(() => _submitting = false);

    String orderNo = '';
    if (result is Map) {
      final dynamic src = (result['order'] is Map) ? result['order'] : result;
      final dynamic v =
          src['orderNumber'] ?? src['orderId'] ?? src['_id'] ?? src['id'];
      if (v != null) orderNo = v.toString();
    }

    final customerName = _name.text.trim();
    final pageContext = context;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: kCream,
          shape: const RoundedRectangleBorder(),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.check_circle_outline, color: kGold, size: 60),
              const SizedBox(height: 16),
              const Text(
                'ORDER PLACED',
                style: TextStyle(
                  fontSize: 18,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                orderNo.isEmpty
                    ? 'Thank you, $customerName!\nYour order has been received.'
                    : 'Thank you, $customerName!\nYour order number is $orderNo.',
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.6, color: Colors.black87),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.only(bottom: 20),
          actions: [
            LuxButton(
              label: 'CONTINUE SHOPPING',
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(pageContext).popUntil((r) => r.isFirst);
                appState.clearCart();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    final form = Form(
      key: _formKey,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kCream,
          border: Border.all(color: kLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'DELIVERY DETAILS',
              style: TextStyle(
                fontSize: 14,
                letterSpacing: 3,
                fontWeight: FontWeight.w700,
                color: kDark,
              ),
            ),
            const SizedBox(height: 14),

            // ---- FULL NAME ----
            TextFormField(
              controller: _name,
              decoration: fieldDeco('Full name'),
              validator: _required,
            ),
            const SizedBox(height: 14),

            // ---- PHONE (country code + number) ----
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 125,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: kLine),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedCountry,
                      isExpanded: true,
                      items: _countryCodes.map((country) {
                        return DropdownMenuItem<String>(
                          value: country['name'],
                          child: Text(
                            '${country['flag']} ${country['code']}',
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCountry = value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                    decoration: fieldDeco('Phone number'),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Required';
                      }

                      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

                      if (digits.length < 6 || digits.length > 15) {
                        return 'Enter a valid phone number';
                      }

                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ---- EMAIL ----
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: fieldDeco('Email address'),
              validator: (v) {
                if (v == null || !v.contains('@') || !v.contains('.')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),

            // ---- ADDRESS ----
            TextFormField(
              controller: _address,
              maxLines: 2,
              decoration: fieldDeco('Full address'),
              validator: _required,
            ),
            const SizedBox(height: 14),

            // ---- CITY ----
            TextFormField(
              controller: _city,
              decoration: fieldDeco('City'),
              validator: _required,
            ),
            const SizedBox(height: 22),

            Container(
              padding: const EdgeInsets.all(14),
              color: Colors.white,
              child: const Row(
                children: [
                  Icon(Icons.payments_outlined, color: kBronze),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Payment: Cash on delivery',
                      style: TextStyle(fontSize: 13, color: kDark),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            LuxButton(
              label: _submitting ? 'PLACING ORDER...' : 'PLACE ORDER',
              expand: true,
              onTap: _placeOrder,
            ),
          ],
        ),
      ),
    );

    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OrderSummary(showButtons: false),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ITEMS',
                style: TextStyle(
                  fontSize: 12,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                  color: kDark,
                ),
              ),
              const SizedBox(height: 12),
              for (final e in appState.cartItems)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 44,
                        height: 54,
                        child: AssetImg(e.key.image),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${e.key.name}  x${e.value}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                      ),
                      Text(
                        money(e.key.price * e.value),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );

    return PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageBanner(eyebrow: 'ALMOST THERE', title: 'CHECKOUT'),
          wrapMax(
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 16 : 30,
                vertical: 40,
              ),
              child: mobile
                  ? Column(
                      children: [summary, const SizedBox(height: 20), form],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: form),
                        const SizedBox(width: 30),
                        Expanded(flex: 2, child: summary),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WISHLIST PAGE
// ============================================================================
class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    return PageShell(
      child: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          final items = appState.wishlist;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const PageBanner(eyebrow: 'YOUR FAVOURITES', title: 'WISHLIST'),
              wrapMax(
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: mobile ? 16 : 30,
                    vertical: 40,
                  ),
                  child: items.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 50),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.favorite_border,
                                size: 64,
                                color: kBronze,
                              ),
                              const SizedBox(height: 18),
                              const Text(
                                'YOUR WISHLIST IS EMPTY',
                                style: TextStyle(
                                  fontSize: 18,
                                  letterSpacing: 3,
                                  fontWeight: FontWeight.w700,
                                  color: kDark,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Tap the heart on any product to save it here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 26),
                              LuxButton(
                                label: 'START SHOPPING',
                                onTap: () => siteNav(context, 'home'),
                              ),
                            ],
                          ),
                        )
                      : ProductGrid(products: items),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================================
// SEARCH PAGE
// ============================================================================
class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final q = _c.text.trim().toLowerCase();

    final List<Product> results = q.isEmpty
        ? <Product>[]
        : allProducts
            .where((p) =>
                p.name.toLowerCase().contains(q) ||
                p.category.toLowerCase().contains(q) ||
                p.group.toLowerCase().contains(q))
            .toList();

    const suggestions = [
      'Fashion',
      'Jewellery',
      'Bags',
      'Kids',
      'Sports',
      'Computer',
      'India',
      'UK',
    ];

    return PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageBanner(eyebrow: 'FIND YOUR STYLE', title: 'SEARCH'),
          wrapMax(
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 16 : 30,
                vertical: 40,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 360),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _c,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      style: const TextStyle(fontSize: 16),
                      decoration: fieldDeco('Search products...').copyWith(
                        prefixIcon: const Icon(Icons.search, color: kBronze),
                        suffixIcon: _c.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () {
                                  _c.clear();
                                  setState(() {});
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (q.isEmpty) ...[
                      const Text(
                        'POPULAR SEARCHES',
                        style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 3,
                          color: kGoldDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final s in suggestions)
                            Clickable(
                              onTap: () {
                                _c.text = s;
                                setState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border.all(color: kLine),
                                ),
                                child: Text(
                                  s.toUpperCase(),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                    color: kDark,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ] else if (results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Text(
                            'No products found. Try another search.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      )
                    else ...[
                      Text(
                        '${results.length} RESULTS',
                        style: const TextStyle(
                          fontSize: 12,
                          letterSpacing: 2,
                          color: kGoldDark,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      ProductGrid(products: results),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// INFO PAGES (Contact, Shipping, Returns, Privacy, Blogs)
// ============================================================================
class InfoData {
  final String eyebrow;
  final String title;
  final List<String> paragraphs;

  const InfoData(this.eyebrow, this.title, this.paragraphs);
}

InfoData infoFor(String key) {
  switch (key) {
    case 'contact':
      return const InfoData('GET IN TOUCH', 'CONTACT US', [
        'We would love to hear from you. Whether you have a question about '
            'an order, a product or a collection, our team is here to help.',
      ]);
    case 'shipping':
      return const InfoData('DELIVERY', 'SHIPPING & DELIVERY', [
        'We offer free worldwide shipping on all orders over \$100.',
        'For orders below \$100, a standard shipping fee is added at checkout.',
        'Delivery time depends on your location. Once your order is '
            'dispatched, our team will keep you updated.',
        'For any questions about your delivery, please contact us.',
      ]);
    case 'returns':
      return const InfoData('CUSTOMER CARE', 'RETURNS', [
        'Your satisfaction matters to us. If something is not right with '
            'your order, please contact us and we will do our best to help.',
        'Items should be unused and in their original packaging.',
        'Please contact our support team to start a return request.',
      ]);
    case 'privacy':
      return const InfoData('YOUR DATA', 'PRIVACY POLICY', [
        'At Meer Luxury Collection we respect your privacy and are '
            'committed to protecting your personal information.',
        'We only collect the details needed to process your orders and '
            'improve your shopping experience, such as your name, contact '
            'details and delivery address.',
        'We do not sell your personal information to third parties.',
        'If you have any questions about how your data is used, please '
            'contact us.',
      ]);
    case 'blogs':
      return const InfoData('STORIES & STYLE', 'BLOGS', [
        'Style notes, trends and inspiration from the world of Meer '
            'Luxury Collection.',
      ]);
    default:
      return const InfoData('MEER', 'INFORMATION', ['']);
  }
}

class InfoPage extends StatefulWidget {
  final String pageKey;

  const InfoPage({super.key, required this.pageKey});

  @override
  State<InfoPage> createState() => _InfoPageState();
}

class _InfoPageState extends State<InfoPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _message = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Widget _contactCard(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kLine),
      ),
      child: Row(
        children: [
          Icon(icon, color: kBronze, size: 26),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: kGoldDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactSection(bool mobile) {
    final details = Column(
      children: [
        _contactCard(Icons.location_on_outlined, 'ADDRESS', kContactAddress),
        _contactCard(Icons.phone_outlined, 'PHONE', kContactPhone),
        _contactCard(Icons.mail_outline, 'EMAIL', kContactEmail),
      ],
    );

    final form = Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _name,
            decoration: fieldDeco('Your name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            decoration: fieldDeco('Your email'),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _message,
            maxLines: 5,
            decoration: fieldDeco('Your message'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 18),
          LuxButton(
            label: 'SEND MESSAGE',
            expand: true,
            onTap: () {
              if (_formKey.currentState?.validate() ?? false) {
                showMsg(context, 'Thank you! We will get back to you soon.');
                _name.clear();
                _email.clear();
                _message.clear();
              }
            },
          ),
        ],
      ),
    );

    if (mobile) {
      return Column(children: [details, const SizedBox(height: 20), form]);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: details),
        const SizedBox(width: 40),
        Expanded(child: form),
      ],
    );
  }

  Widget _blogSection(bool mobile) {
    final List<List<String>> posts = [
      [
        'Styling Timeless Pieces',
        'Simple ways to mix classic fashion with modern details.',
        'assets/images/banners/banner1.jpeg',
      ],
      [
        'Caring for Your Jewellery',
        'Easy habits that keep your jewellery shining for years.',
        'assets/images/banners/banner2.jpeg',
      ],
      [
        'Choosing the Perfect Bag',
        'What to look for when picking a bag for every occasion.',
        'assets/images/banners/banner3.jpeg',
      ],
    ];

    Widget card(List<String> p) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: kLine),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 200, child: AssetImg(p[2])),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p[0],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p[1],
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (mobile) {
      return Column(
        children: [
          for (final p in posts) ...[card(p), const SizedBox(height: 18)],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < posts.length; i++) ...[
          if (i > 0) const SizedBox(width: 22),
          Expanded(child: card(posts[i])),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);
    final data = infoFor(widget.pageKey);

    return PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageBanner(eyebrow: data.eyebrow, title: data.title),
          wrapMax(
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 16 : 30,
                vertical: 45,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final para in data.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Text(
                          para,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.8,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  if (widget.pageKey == 'contact') _contactSection(mobile),
                  if (widget.pageKey == 'blogs') _blogSection(mobile),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// LOGIN / REGISTRATION PAGE
// ============================================================================
class AuthPage extends StatefulWidget {
  final bool startOnRegister;

  const AuthPage({super.key, this.startOnRegister = false});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  late bool _register = widget.startOnRegister;
  bool _loading = false;
  bool _hide = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);
    final email = _email.text.trim();

    try {
      if (_register) {
        await FakeApiService.registerCustomer(
          name: _name.text.trim(),
          email: email,
          password: _password.text,
        ).timeout(const Duration(seconds: 20));

        if (!mounted) return;
        showMsg(context, 'Account created! Please login.');
        setState(() {
          _register = false;
          _password.clear();
          _confirm.clear();
        });
      } else {
        final data = await FakeApiService.loginCustomer(
          email: email,
          password: _password.text,
        ).timeout(const Duration(seconds: 20));

        if (!mounted) return;
        authState.signIn(data, email);
        showMsg(context, 'Welcome back!');
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      showMsg(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: Clickable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? kGold : kLine,
                width: selected ? 2 : 1,
              ),
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
              color: selected ? kDark : Colors.black45,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mobile = isMobile(context);

    return PageShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PageBanner(
            eyebrow: 'WELCOME',
            title: _register ? 'REGISTRATION' : 'LOGIN',
          ),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: mobile ? 16 : 0,
                  vertical: 40,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          _tab('LOGIN', !_register,
                              () => setState(() => _register = false)),
                          _tab('REGISTRATION', _register,
                              () => setState(() => _register = true)),
                        ],
                      ),
                      const SizedBox(height: 26),
                      if (_register) ...[
                        TextFormField(
                          controller: _name,
                          decoration: fieldDeco('Full name'),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Name is required'
                              : null,
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: fieldDeco('Email address'),
                        validator: (v) {
                          if (v == null ||
                              !v.contains('@') ||
                              !v.contains('.')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _hide,
                        decoration: fieldDeco('Password').copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _hide
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: kBronze,
                            ),
                            onPressed: () => setState(() => _hide = !_hide),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 6) {
                            return 'At least 6 characters';
                          }
                          return null;
                        },
                      ),
                      if (_register) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirm,
                          obscureText: _hide,
                          decoration: fieldDeco('Confirm password'),
                          validator: (v) => v != _password.text
                              ? 'Passwords do not match'
                              : null,
                        ),
                      ],
                      const SizedBox(height: 24),
                      LuxButton(
                        label: _loading
                            ? 'PLEASE WAIT...'
                            : (_register ? 'CREATE ACCOUNT' : 'LOGIN'),
                        expand: true,
                        onTap: _submit,
                      ),
                      const SizedBox(height: 18),
                      Center(
                        child: HoverText(
                          _register
                              ? 'Already have an account? LOGIN'
                              : 'New here? CREATE AN ACCOUNT',
                          color: kGoldDark,
                          hoverColor: kDark,
                          fontSize: 12,
                          letterSpacing: 1,
                          onTap: () => setState(() => _register = !_register),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}