import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'dart:typed_data';

import '../models/cash_payment.dart';
import '../models/product.dart';

class InventoryService {
  InventoryService({
    required this.user,
    required this.displayName,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final User user;
  final String displayName;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _products =>
      _firestore.collection('products');

  CollectionReference<Map<String, dynamic>> get _productCosts =>
      _firestore.collection('productCosts');

  Stream<Map<String, double>> watchProductCosts() {
    return _productCosts.snapshots().map(
      (snapshot) => {
        for (final doc in snapshot.docs)
          doc.id: (doc.data()['cost'] as num?)?.toDouble() ?? 0,
      },
    );
  }

  Future<double> getProductCost(String productId) async {
    final snapshot = await _productCosts.doc(productId).get();
    return (snapshot.data()?['cost'] as num?)?.toDouble() ?? 0;
  }

  Stream<List<Product>> watchProducts() {
    return _products.snapshots().map(
      (snapshot) => snapshot.docs.map(Product.fromSnapshot).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())),
    );
  }

  Future<List<String>> getProductCategories() async {
    final snapshot = await _products.get();
    final categories =
        snapshot.docs
            .map((document) => document.data()['category'])
            .whereType<String>()
            .map((category) => category.trim())
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    return categories;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchSales() {
    return _firestore
        .collection('sales')
        .orderBy('occurredAt', descending: true)
        .limit(500)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchMySales({
    String? shiftId,
    int? limit = 100,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('sales')
        .where('createdBy', isEqualTo: user.uid);
    if (shiftId != null) {
      query = query.where('shiftId', isEqualTo: shiftId);
    }
    query = query.orderBy('occurredAt', descending: true);
    if (limit != null) query = query.limit(limit);
    return query.snapshots().map((snapshot) => snapshot.docs);
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> getMyShiftSales(
    String shiftId,
  ) async {
    final snapshot = await _firestore
        .collection('sales')
        .where('createdBy', isEqualTo: user.uid)
        .where('shiftId', isEqualTo: shiftId)
        .orderBy('occurredAt', descending: true)
        .get();
    return snapshot.docs;
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchPurchases() {
    return _firestore
        .collection('purchases')
        .limit(300)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> watchMyMovements() {
    return _firestore
        .collection('stockMovements')
        .where('actorUid', isEqualTo: user.uid)
        .orderBy('occurredAt', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  watchRecentMovements({required bool includeTeam}) {
    final movements = _firestore.collection('stockMovements');
    final query = includeTeam
        ? movements.orderBy('occurredAt', descending: true)
        : movements
              .where('actorUid', isEqualTo: user.uid)
              .orderBy('occurredAt', descending: true);
    return query.limit(5).snapshots().map((snapshot) => snapshot.docs);
  }

  Future<void> saveProduct({
    String? id,
    required String sku,
    required String name,
    required String description,
    required String category,
    required double cost,
    required double price,
    required int minStock,
    required int initialStock,
    String? imageUrl,
    Uint8List? imageBytes,
    String imageFileName = 'producto.jpg',
    bool removeImage = false,
  }) async {
    final productRef = id == null ? _products.doc() : _products.doc(id);
    var resolvedImageUrl = imageUrl;
    if (imageBytes != null) {
      final extension = imageFileName.contains('.')
          ? imageFileName.split('.').last.toLowerCase()
          : 'jpg';
      final safeExtension = extension.length <= 5 ? extension : 'jpg';
      final imageRef = FirebaseStorage.instance.ref(
        'product_images/${productRef.id}.$safeExtension',
      );
      await imageRef.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/$safeExtension'),
      );
      resolvedImageUrl = await imageRef.getDownloadURL();
    }
    final data = {
      'sku': sku.trim(),
      'name': name.trim(),
      'description': description.trim(),
      'category': category.trim(),
      'price': price,
      'minStock': minStock,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
      if (resolvedImageUrl != null)
        'imageUrl': resolvedImageUrl
      else if (removeImage)
        'imageUrl': FieldValue.delete(),
    };

    if (id != null) {
      final costRef = _productCosts.doc(id);
      final existingCost = await costRef.get();
      final batch = _firestore.batch();
      batch.update(productRef, data);
      if (existingCost.exists) {
        batch.update(costRef, {
          'cost': cost,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
        });
      } else {
        batch.set(costRef, {
          'productId': id,
          'cost': cost,
          'createdAt': FieldValue.serverTimestamp(),
          'createdBy': user.uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
        });
      }
      await batch.commit();
      return;
    }

    final movementRef = initialStock > 0
        ? _firestore.collection('stockMovements').doc()
        : null;
    final batch = _firestore.batch();
    batch.set(productRef, {
      ...data,
      'active': true,
      'stock': initialStock,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      if (movementRef != null) 'lastMovementId': movementRef.id,
    });
    batch.set(_productCosts.doc(productRef.id), {
      'productId': productRef.id,
      'cost': cost,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': user.uid,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
    if (movementRef != null) {
      batch.set(movementRef, {
        'productId': productRef.id,
        'sku': sku.trim(),
        'productName': name.trim(),
        'type': 'entry',
        'quantity': initialStock,
        'beforeStock': 0,
        'afterStock': initialStock,
        'reason': 'Stock inicial',
        'actorUid': user.uid,
        'actorName': displayName,
        'occurredAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> setProductActive(Product product, bool active) {
    return _products.doc(product.id).update({
      'active': active,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': user.uid,
    });
  }

  Future<void> adjustStock({
    required Product product,
    required String operation,
    required int quantity,
    required String reason,
  }) async {
    if (quantity < 0 || (operation != 'adjustment' && quantity == 0)) {
      throw ArgumentError.value(quantity, 'quantity');
    }
    final productRef = _products.doc(product.id);
    final movementRef = _firestore.collection('stockMovements').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(productRef);
      if (!snapshot.exists) {
        throw StateError('El producto ya no existe.');
      }
      final current = snapshot.data()!;
      final before = (current['stock'] as num?)?.toInt() ?? 0;
      final after = switch (operation) {
        'entry' => before + quantity,
        'exit' => before - quantity,
        'adjustment' => quantity,
        _ => throw ArgumentError.value(operation, 'operation'),
      };
      if (after < 0) throw StateError('No hay existencias suficientes.');

      transaction.update(productRef, {
        'stock': after,
        'lastMovementId': movementRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
      transaction.set(movementRef, {
        'productId': product.id,
        'sku': current['sku'],
        'productName': current['name'],
        'type': operation,
        'quantity': operation == 'adjustment'
            ? (after - before).abs()
            : quantity,
        'beforeStock': before,
        'afterStock': after,
        'reason': reason.trim(),
        'actorUid': user.uid,
        'actorName': displayName,
        'occurredAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<RegisteredSale> registerSale({
    required List<SaleLine> lines,
    required String paymentMethod,
    required double amountReceived,
    String? cashShiftId,
  }) async {
    if (lines.isEmpty) throw StateError('Agrega productos antes de cobrar.');
    if (!const {
      'Efectivo',
      'Tarjeta',
      'Transferencia',
    }.contains(paymentMethod)) {
      throw ArgumentError.value(paymentMethod, 'paymentMethod');
    }
    if (!amountReceived.isFinite || amountReceived < 0) {
      throw ArgumentError.value(amountReceived, 'amountReceived');
    }
    final saleRef = _firestore.collection('sales').doc();
    final productRefs = {
      for (final line in lines) line.product.id: _products.doc(line.product.id),
    };

    return _firestore.runTransaction<RegisteredSale>((transaction) async {
      final snapshots = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final entry in productRefs.entries) {
        snapshots[entry.key] = await transaction.get(entry.value);
      }

      final quantities = <String, int>{};
      for (final line in lines) {
        quantities.update(
          line.product.id,
          (value) => value + line.quantity,
          ifAbsent: () => line.quantity,
        );
      }
      for (final entry in quantities.entries) {
        final snapshot = snapshots[entry.key]!;
        if (!snapshot.exists || snapshot.data()!['active'] != true) {
          throw StateError('Uno de los productos ya no está disponible.');
        }
        if (entry.value <= 0) {
          throw StateError('La cantidad debe ser mayor que cero.');
        }
        final stock = (snapshot.data()!['stock'] as num?)?.toInt() ?? 0;
        if (stock < entry.value) {
          throw StateError(
            'Stock insuficiente para ${snapshot.data()!['name']}.',
          );
        }
      }

      final items = quantities.entries.map((entry) {
        final current = snapshots[entry.key]!.data()!;
        final unitPriceCents = moneyToCents(
          (current['price'] as num?)?.toDouble() ?? 0,
        );
        final quantity = entry.value;
        return {
          'productId': entry.key,
          'sku': current['sku'],
          'name': current['name'],
          'quantity': quantity,
          'unitPrice': unitPriceCents / 100,
          'subtotal': unitPriceCents * quantity / 100,
          '_subtotalCents': unitPriceCents * quantity,
        };
      }).toList();
      final totalCents = items.fold<int>(
        0,
        (subtotal, item) => subtotal + (item['_subtotalCents']! as int),
      );
      final total = totalCents / 100;
      final payment = CashPayment.calculate(
        total: total,
        amountReceived: paymentMethod == 'Efectivo' ? amountReceived : total,
      );

      for (final item in items) {
        item.remove('_subtotalCents');
      }

      transaction.set(saleRef, {
        'items': items,
        'total': total,
        'paymentMethod': paymentMethod,
        if (cashShiftId != null) ...{
          'shiftId': cashShiftId,
          'amountReceived': payment.amountReceived,
          'changeDue': payment.changeDue,
        },
        'status': 'completed',
        'createdBy': user.uid,
        'createdByName': displayName,
        'occurredAt': FieldValue.serverTimestamp(),
      });

      for (final entry in quantities.entries) {
        final productRef = productRefs[entry.key]!;
        final current = snapshots[entry.key]!.data()!;
        final before = (current['stock'] as num?)?.toInt() ?? 0;
        final movementRef = _firestore.collection('stockMovements').doc();
        transaction.update(productRef, {
          'stock': before - entry.value,
          'lastMovementId': movementRef.id,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': user.uid,
        });
        transaction.set(movementRef, {
          'productId': entry.key,
          'sku': current['sku'],
          'productName': current['name'],
          'type': 'sale',
          'quantity': entry.value,
          'beforeStock': before,
          'afterStock': before - entry.value,
          'reason': 'Venta ${saleRef.id}',
          'saleId': saleRef.id,
          'actorUid': user.uid,
          'actorName': displayName,
          'occurredAt': FieldValue.serverTimestamp(),
        });
      }
      return RegisteredSale(
        id: saleRef.id,
        total: payment.total,
        amountReceived: payment.amountReceived,
        changeDue: payment.changeDue,
      );
    });
  }

  Future<void> recordPurchase({
    required Product product,
    required int quantity,
    required double unitCost,
    required String supplier,
    required String reference,
  }) async {
    if (quantity <= 0 || unitCost < 0) {
      throw ArgumentError('La cantidad debe ser positiva y el costo válido.');
    }
    final productRef = _products.doc(product.id);
    final purchaseRef = _firestore.collection('purchases').doc();
    final movementRef = _firestore.collection('stockMovements').doc();

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(productRef);
      if (!snapshot.exists) throw StateError('El producto ya no existe.');
      final current = snapshot.data()!;
      final before = (current['stock'] as num?)?.toInt() ?? 0;
      final after = before + quantity;

      transaction.update(productRef, {
        'stock': after,
        'lastMovementId': movementRef.id,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': user.uid,
      });
      transaction.set(purchaseRef, {
        'productId': product.id,
        'productName': current['name'],
        'sku': current['sku'],
        'quantity': quantity,
        'unitCost': unitCost,
        'total': quantity * unitCost,
        'supplier': supplier.trim(),
        'reference': reference.trim(),
        'status': 'received',
        'createdBy': user.uid,
        'createdByName': displayName,
        'occurredAt': FieldValue.serverTimestamp(),
      });
      transaction.set(movementRef, {
        'productId': product.id,
        'sku': current['sku'],
        'productName': current['name'],
        'type': 'purchase',
        'quantity': quantity,
        'beforeStock': before,
        'afterStock': after,
        'reason': supplier.trim().isEmpty
            ? 'Compra recibida'
            : 'Compra · ${supplier.trim()}',
        'purchaseId': purchaseRef.id,
        'actorUid': user.uid,
        'actorName': displayName,
        'occurredAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

class SaleLine {
  const SaleLine({required this.product, required this.quantity});

  final Product product;
  final int quantity;
}

class RegisteredSale {
  const RegisteredSale({
    required this.id,
    required this.total,
    required this.amountReceived,
    required this.changeDue,
  });

  final String id;
  final double total;
  final double amountReceived;
  final double changeDue;
}
