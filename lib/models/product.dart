import 'package:cloud_firestore/cloud_firestore.dart';

class Product {
  const Product({
    required this.id,
    required this.sku,
    required this.name,
    required this.description,
    required this.category,
    required this.price,
    required this.stock,
    required this.minStock,
    required this.active,
    this.imageUrl,
    this.imageBase64,
  });

  final String id;
  final String sku;
  final String name;
  final String description;
  final String category;
  final double price;
  final int stock;
  final int minStock;
  final bool active;
  final String? imageUrl;
  final String? imageBase64;

  factory Product.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    return Product(
      id: snapshot.id,
      sku: data['sku'] as String? ?? '',
      name: data['name'] as String? ?? '',
      description: data['description'] as String? ?? '',
      category: data['category'] as String? ?? 'Sin categoría',
      price: _asDouble(data['price']),
      stock: _asInt(data['stock']),
      minStock: _asInt(data['minStock']),
      active: data['active'] == true,
      imageUrl: data['imageUrl'] as String?,
      imageBase64: data['imageBase64'] as String?,
    );
  }

  static double _asDouble(Object? value) => value is num ? value.toDouble() : 0;

  static int _asInt(Object? value) => value is num ? value.toInt() : 0;

  bool get isLowStock => stock <= minStock;
}
