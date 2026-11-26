import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

// ==========================================
// MODELS
// ==========================================

class OrderLog {
  final String orderId;
  final String storeId;
  final String productId;
  final String customerName;
  final int quantity;
  final String eta;
  final String timestamp;

  OrderLog({required this.orderId, required this.storeId, required this.productId, required this.customerName, required this.quantity, required this.eta, required this.timestamp});

  factory OrderLog.fromJson(Map<String, dynamic> json) {
    return OrderLog(
      orderId: (json['order_id'] ?? '').toString().trim(),
      storeId: (json['store_id'] ?? '').toString().trim(),
      productId: (json['product_id'] ?? '').toString().trim(),
      customerName: (json['customer_name'] ?? 'Unknown').toString().trim(),
      quantity: int.tryParse((json['quantity'] ?? '1').toString().trim()) ?? 1,
      eta: (json['eta'] ?? '0').toString().trim(),
      timestamp: (json['timestamp'] ?? '').toString().trim(),
    );
  }
}

class Store {
  final String storeId;
  final String ownerId;
  final String storeName;
  final String address;
  final String latitude;
  final String longitude;
  final String helpline;

  Store({
    required this.storeId,
    required this.ownerId,
    required this.storeName,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.helpline,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    return Store(
      storeId: (json['store_id'] ?? '').toString().trim(),
      ownerId: (json['owner_id'] ?? '').toString().trim(),
      storeName: (json['store_name'] ?? 'Store').toString().trim(),
      address: (json['address'] ?? '').toString().trim(),
      latitude: (json['latitude'] ?? '0.0').toString().trim(),
      longitude: (json['longitude'] ?? '0.0').toString().trim(),
      helpline: (json['helpline'] ?? 'N/A').toString().trim(),
    );
  }
}

class Inventory {
  final String invId;
  final String storeId;
  final String productId;
  final int quantity;

  Inventory({required this.invId, required this.storeId, required this.productId, required this.quantity});

  factory Inventory.fromJson(Map<String, dynamic> json) {
    int parseQty(dynamic val) {
      if (val == null) return 0;
      if (val is int) return val;
      if (val is double) return val.toInt();
      return int.tryParse(val.toString().trim()) ?? 0;
    }

    return Inventory(
      invId: (json['inv_id'] ?? '').toString().trim(),
      storeId: (json['store_id'] ?? '').toString().trim(),
      productId: (json['product_id'] ?? '').toString().trim(),
      quantity: parseQty(json['quantity']),
    );
  }
}

class Product {
  final String productId;
  final String sku;
  final String name;
  final double price;
  final int stockCount;
  final String owner;
  final String storeName;

  Product({
    required this.productId,
    required this.sku,
    required this.name,
    required this.price,
    required this.stockCount,
    this.owner = "",
    this.storeName = "Main Store",
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      productId: (json['product_id'] ?? '').toString().trim(),
      sku: (json['sku'] ?? '').toString().trim(),
      name: (json['name'] ?? 'Item').toString().trim(),
      price: double.tryParse((json['price'] ?? '0').toString().trim()) ?? 0.0,
      stockCount: int.tryParse((json['stock'] ?? json['quantity'] ?? '0').toString().trim()) ?? 0,
      owner: (json['owner'] ?? json['owner_id'] ?? '').toString().trim(),
      storeName: (json['storeName'] ?? 'Main Store').toString().trim(),
    );
  }
}

// ==========================================
// PROVIDER
// ==========================================

class SyncProvider extends ChangeNotifier {
  static const String endpoint = "https://script.google.com/macros/s/AKfycbzpdo_ThhUOAvbZbDFTcvPhghrNnqyIaHGjJXgFoUjoslVqfGr287qAMOFU8HA_L6x0yA/exec";

  List<Store> stores = [];
  List<Product> products = [];
  List<Inventory> inventory = [];
  List<OrderLog> orders = [];

  String? currentUser;
  String? currentUserId;
  String? currentOwnerId;
  String? currentUserRole;

  bool isLoading = false;
  String? error;

  Future<void> fetchData() async {
    isLoading = true;
    notifyListeners();

    try {
      final cb = DateTime.now().millisecondsSinceEpoch;
      final response = await http.get(Uri.parse('$endpoint?action=getRetailData&cb=$cb'));

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = json.decode(response.body);

        if (data['result'] == 'success') {
          stores = (data['stores'] as List?)?.map((e) => Store.fromJson(e)).toList() ?? [];
          products = (data['products'] as List?)?.map((e) => Product.fromJson(e)).toList() ?? [];
          inventory = (data['inventory'] as List?)?.map((e) => Inventory.fromJson(e)).toList() ?? [];
          orders = (data['orders'] as List?)?.map((e) => OrderLog.fromJson(e)).toList() ?? [];
          error = null;
        }
      } else {
        error = "Failed to fetch data: ${response.statusCode}";
      }
    } catch (e) {
      error = "Sync error: $e";
      if (kDebugMode) print(error);
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<String> authenticate(String username, String password, String role, bool isSignUp) async {
    try {
      final action = isSignUp ? "signup" : "login";
      final cb = DateTime.now().millisecondsSinceEpoch.toString();
      final Uri baseUri = Uri.parse(endpoint);
      final Map<String, String> params = {
        ...baseUri.queryParameters,
        "action": action,
        "username": username,
        "password": password,
        "role": role,
        "cb": cb,
      };

      final uri = baseUri.replace(queryParameters: params);
      final response = await http.get(uri);

      if (response.statusCode == 200 || response.statusCode == 302) {
        final data = json.decode(response.body);
        if (data["result"] == "success") {
          currentUser = username;
          if (!isSignUp) {
            currentUserId = data["user_id"];
            currentUserRole = data["role"];
            currentOwnerId = data["owner_id"];
            await fetchData();
          }
        }
        return data["result"] ?? "error";
      }
      return "error";
    } catch (e) {
      return "error";
    }
  }

  Future<bool> addProduct(String sku, String name, String description, String category, double price) async {
    if (currentOwnerId == null) return false;
    try {
      final cb = DateTime.now().millisecondsSinceEpoch.toString();
      final uri = Uri.parse(endpoint).replace(queryParameters: {
        "action": "addProduct",
        "owner_id": currentOwnerId!,
        "sku": sku,
        "name": name,
        "description": description,
        "category": category,
        "price": price.toString(),
        "cb": cb,
      });
      final response = await http.get(uri);
      if (response.statusCode == 200 || response.statusCode == 302) {
        await fetchData();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<bool> updateInventory(String storeId, String productId, int newQuantity) async {
    final sId = storeId.trim();
    final pId = productId.trim();

    final invIndex = inventory.indexWhere((i) => i.storeId.trim() == sId && i.productId.trim() == pId);
    if (invIndex != -1) {
      inventory[invIndex] = Inventory(
          invId: inventory[invIndex].invId,
          storeId: sId,
          productId: pId,
          quantity: newQuantity);
    } else {
      inventory.add(Inventory(invId: 'temp', storeId: sId, productId: pId, quantity: newQuantity));
    }
    notifyListeners();

    try {
      final cb = DateTime.now().millisecondsSinceEpoch.toString();
      final uri = Uri.parse(endpoint).replace(queryParameters: {
        "action": "updateInventory",
        "store_id": sId,
        "product_id": pId,
        "quantity": newQuantity.toString(),
        "cb": cb,
      });
      final response = await http.get(uri);
      if (response.statusCode == 200 || response.statusCode == 302) {
        await fetchData();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<void> logReservation(String storeId, String productId, int quantity, String eta) async {
    try {
      final cb = DateTime.now().millisecondsSinceEpoch.toString();
      final uri = Uri.parse(endpoint).replace(queryParameters: {
        "action": "logOrder",
        "store_id": storeId,
        "product_id": productId,
        "customer_name": currentUser ?? "Customer",
        "quantity": quantity.toString(),
        "eta": eta,
        "cb": cb,
      });
      await http.get(uri);
    } catch (e) {
      if (kDebugMode) print("Order log error: $e");
    }
  }

  Future<bool> addStore(String storeName, String address, double lat, double lng, String helpline) async {
    if (currentOwnerId == null) return false;
    try {
      final cb = DateTime.now().millisecondsSinceEpoch.toString();
      final uri = Uri.parse(endpoint).replace(queryParameters: {
        "action": "addStore",
        "owner_id": currentOwnerId!,
        "store_name": storeName,
        "address": address,
        "latitude": lat.toString(),
        "longitude": lng.toString(),
        "helpline": helpline,
        "cb": cb,
      });
      final response = await http.get(uri);
      if (response.statusCode == 200 || response.statusCode == 302) {
        await fetchData();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // NEW: Delete Store Method
  Future<bool> deleteStore(String storeId) async {
    final sId = storeId.trim();
    stores.removeWhere((s) => s.storeId == sId); // Optimistic UI
    notifyListeners();
    try {
      final cb = DateTime.now().millisecondsSinceEpoch.toString();
      final uri = Uri.parse(endpoint).replace(queryParameters: {
        "action": "deleteStore",
        "store_id": sId,
        "cb": cb,
      });
      final response = await http.get(uri);
      if (response.statusCode == 200 || response.statusCode == 302) {
        await fetchData();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // NEW: Delete Product Method
  Future<bool> deleteProduct(String productId) async {
    final pId = productId.trim();
    products.removeWhere((p) => p.productId == pId || p.sku == pId); // Optimistic UI
    notifyListeners();
    try {
      final cb = DateTime.now().millisecondsSinceEpoch.toString();
      final uri = Uri.parse(endpoint).replace(queryParameters: {
        "action": "deleteProduct",
        "product_id": pId,
        "cb": cb,
      });
      final response = await http.get(uri);
      if (response.statusCode == 200 || response.statusCode == 302) {
        await fetchData();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}