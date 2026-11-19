import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.createdAt,
    this.isLocal = false,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final bool read;
  final DateTime? createdAt;
  final bool isLocal;

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      read: read ?? this.read,
      createdAt: createdAt,
      isLocal: isLocal,
    );
  }

  factory AppNotification.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    final timestamp = data['createdAt'];
    return AppNotification(
      id: snapshot.id,
      title: data['title'] as String? ?? 'Notificación',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? '',
      read: data['read'] as bool? ?? false,
      createdAt: timestamp is Timestamp ? timestamp.toDate() : null,
    );
  }

  factory AppNotification.fromLocalJson(Map<String, dynamic> data) {
    return AppNotification(
      id: data['id'] as String,
      title: data['title'] as String,
      body: data['body'] as String,
      type: data['type'] as String,
      read: data['read'] as bool? ?? false,
      createdAt: DateTime.parse(data['createdAt'] as String),
      isLocal: true,
    );
  }

  Map<String, Object> toLocalJson() => {
    'id': id,
    'title': title,
    'body': body,
    'type': type,
    'read': read,
    'createdAt': createdAt!.toIso8601String(),
  };
}

class NotificationService {
  NotificationService({
    required this._userId,
    FirebaseFirestore? firestore,
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _localPlugin = localNotifications ?? FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'product_updates',
    'Productos y existencias',
    description: 'Avisos sobre productos registrados y niveles de stock.',
    importance: Importance.high,
  );
  static const _historyLimit = 50;

  final String _userId;
  final FirebaseFirestore _firestore;
  final FlutterLocalNotificationsPlugin _localPlugin;
  final StreamController<void> _openedController =
      StreamController<void>.broadcast();
  final StreamController<void> _localChangesController =
      StreamController<void>.broadcast();
  final StreamController<String> _errorsController =
      StreamController<String>.broadcast();
  final List<AppNotification> _localHistory = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _productSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
  _movementSubscription;
  String? _permissionMessage;
  bool _productsLoaded = false;
  bool _movementsLoaded = false;
  bool _initialized = false;
  bool _localHistoryLoaded = false;
  Future<void>? _localHistoryLoad;

  Stream<void> get opened => _openedController.stream;
  Stream<String> get errors => _errorsController.stream;
  String? get permissionMessage => _permissionMessage;

  CollectionReference<Map<String, dynamic>> get _userNotifications =>
      _firestore.collection('users').doc(_userId).collection('notifications');

  String get _localHistoryKey => 'local_inventory_notifications_$_userId';

  Stream<List<AppNotification>> watchNotifications() {
    return Stream<List<AppNotification>>.multi((controller) {
      var remoteNotifications = <AppNotification>[];
      void emit() {
        final all = [...remoteNotifications, ..._localHistory]
          ..sort((a, b) {
            final first = a.createdAt;
            final second = b.createdAt;
            if (first == null) return second == null ? 0 : 1;
            if (second == null) return -1;
            return second.compareTo(first);
          });
        controller.add(all.take(_historyLimit).toList());
      }

      final remoteSubscription = _userNotifications
          .orderBy('createdAt', descending: true)
          .limit(_historyLimit)
          .snapshots()
          .listen((snapshot) {
            remoteNotifications = snapshot.docs
                .map(AppNotification.fromSnapshot)
                .toList();
            emit();
          }, onError: controller.addError);
      final localSubscription = _localChangesController.stream.listen(
        (_) => emit(),
      );
      emit();
      controller.onCancel = () {
        unawaited(remoteSubscription.cancel());
        unawaited(localSubscription.cancel());
      };
    });
  }

  Stream<int> watchUnreadCount() {
    return watchNotifications().map(
      (notifications) => notifications.where((item) => !item.read).length,
    );
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      _permissionMessage =
          'Los avisos locales están disponibles en la aplicación móvil.';
      return;
    }

    await _localPlugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (_) => _openedController.add(null),
    );
    await _localPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    await _loadLocalHistory();

    final androidNotifications = _localPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final iosNotifications = _localPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final permissionGranted = switch (defaultTargetPlatform) {
      TargetPlatform.android =>
        await androidNotifications?.requestNotificationsPermission() ?? true,
      TargetPlatform.iOS =>
        await iosNotifications?.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            true,
      _ => true,
    };
    if (!permissionGranted) {
      _permissionMessage = 'Permite las notificaciones en los ajustes del celular para recibir avisos mientras usas la app.';
      return;
    }

    _permissionMessage = null;
    _startMonitoring();
  }

  Future<void> markAsRead(AppNotification notification) async {
    if (notification.read) return;
    if (notification.isLocal) {
      final index = _localHistory.indexWhere(
        (item) => item.id == notification.id,
      );
      if (index == -1) return;
      _localHistory[index] = notification.copyWith(read: true);
      await _saveLocalHistory();
      _localChangesController.add(null);
      return;
    }
    await _userNotifications.doc(notification.id).update({'read': true});
  }

  Future<void> markAllAsRead() async {
    await _loadLocalHistory();

    var localHistoryChanged = false;
    for (var index = 0; index < _localHistory.length; index++) {
      final notification = _localHistory[index];
      if (notification.read) continue;
      _localHistory[index] = notification.copyWith(read: true);
      localHistoryChanged = true;
    }
    if (localHistoryChanged) {
      await _saveLocalHistory();
      _localChangesController.add(null);
    }

    final remoteSnapshot = await _userNotifications.get();
    final unreadDocuments = remoteSnapshot.docs
        .where((document) => document.data()['read'] != true)
        .toList(growable: false);
    for (var start = 0; start < unreadDocuments.length; start += 500) {
      final end = start + 500 < unreadDocuments.length
          ? start + 500
          : unreadDocuments.length;
      final batch = _firestore.batch();
      for (var index = start; index < end; index++) {
        batch.update(unreadDocuments[index].reference, {'read': true});
      }
      await batch.commit();
    }
  }

  Future<void> dispose() async {
    await _productSubscription?.cancel();
    await _movementSubscription?.cancel();
    await _openedController.close();
    await _localChangesController.close();
    await _errorsController.close();
  }

  void _startMonitoring() {
    final recentCutoff = Timestamp.fromDate(
      DateTime.now().subtract(const Duration(minutes: 2)),
    );
    _productSubscription = _firestore
        .collection('products')
        .where('createdAt', isGreaterThanOrEqualTo: recentCutoff)
        .limit(100)
        .snapshots()
        .listen(
          _handleProductSnapshot,
          onError: (Object error, StackTrace stackTrace) => _reportError(
            'No se pudieron vigilar los productos',
            error,
            stackTrace,
          ),
        );
    _movementSubscription = _firestore
        .collection('stockMovements')
        .where('occurredAt', isGreaterThanOrEqualTo: recentCutoff)
        .orderBy('occurredAt', descending: true)
        .limit(100)
        .snapshots()
        .listen(
          _handleMovementSnapshot,
          onError: (Object error, StackTrace stackTrace) => _reportError(
            'No se pudieron vigilar las entradas de stock',
            error,
            stackTrace,
          ),
        );
  }

  void _handleProductSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!_productsLoaded) {
      _productsLoaded = true;
      return;
    }
    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      unawaited(
        _notifyProductRegistered(change.doc).catchError(
          (Object error, StackTrace stackTrace) =>
              _reportError('No se pudo mostrar el aviso de producto', error),
        ),
      );
    }
  }

  Future<void> _notifyProductRegistered(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final product = document.data();
    if (product == null) return;
    if (product['active'] != true) return;
    final name = product['name'] as String? ?? 'Producto';
    final sku = product['sku'] as String? ?? 'Sin SKU';
    final stock = _number(product['stock']);
    final minimum = _number(product['minStock']);
    await _addLocalNotification(
      eventId: 'product_${document.id}',
      type: 'product_registered',
      title: 'Producto registrado: $name',
      body:
          'SKU: $sku · ${product['category'] ?? 'Sin categoría'} · '
          'Precio de venta: ${_money(product['price'])} · '
          'Stock inicial: $stock · Mínimo: $minimum',
    );
    if (stock <= minimum) {
      await _addLowStockNotification(
        eventId: 'product_${document.id}_low_stock',
        name: name,
        sku: sku,
        stock: stock,
        minimum: minimum,
      );
    }
  }

  void _handleMovementSnapshot(QuerySnapshot<Map<String, dynamic>> snapshot) {
    if (!_movementsLoaded) {
      _movementsLoaded = true;
      return;
    }
    for (final change in snapshot.docChanges) {
      if (change.type != DocumentChangeType.added) continue;
      unawaited(
        _handleStockMovement(change.doc).catchError(
          (Object error, StackTrace stackTrace) =>
              _reportError('No se pudo mostrar el aviso de existencias', error),
        ),
      );
    }
  }

  Future<void> _handleStockMovement(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) async {
    final movement = document.data();
    if (movement == null) return;
    if (movement['reason'] == 'Stock inicial') return;

    final type = movement['type'];
    final name = movement['productName'] as String? ?? 'Producto';
    final sku = movement['sku'] as String? ?? 'Sin SKU';
    final quantity = _number(movement['quantity']);
    final stock = _number(movement['afterStock']);
    if (type == 'entry' || type == 'purchase') {
      await _addLocalNotification(
        eventId: 'movement_${document.id}',
        type: 'stock_entry',
        title: 'Ingreso de producto: $name',
        body: 'Entraron $quantity unidades · Stock actual: $stock · SKU: $sku',
      );
    }

    final productId = movement['productId'];
    if (productId is! String || productId.isEmpty) return;
    final before = _number(movement['beforeStock']);
    final productSnapshot = await _firestore
        .collection('products')
        .doc(productId)
        .get();
    final product = productSnapshot.data();
    if (product == null || product['active'] != true) return;
    final minimum = _number(product['minStock']);
    if (before > minimum && stock <= minimum) {
      await _addLowStockNotification(
        eventId: 'movement_${document.id}_low_stock',
        name: product['name'] as String? ?? name,
        sku: product['sku'] as String? ?? sku,
        stock: stock,
        minimum: minimum,
      );
    }
  }

  Future<void> _addLowStockNotification({
    required String eventId,
    required String name,
    required String sku,
    required int stock,
    required int minimum,
  }) {
    return _addLocalNotification(
      eventId: eventId,
      type: 'low_stock',
      title: 'Stock bajo: $name',
      body: 'Quedan $stock unidades (mínimo: $minimum) · SKU: $sku',
    );
  }

  Future<void> _addLocalNotification({
    required String eventId,
    required String type,
    required String title,
    required String body,
  }) async {
    final id = 'local_$eventId';
    if (_localHistory.any((item) => item.id == id)) return;
    final notification = AppNotification(
      id: id,
      title: title,
      body: body,
      type: type,
      read: false,
      createdAt: DateTime.now(),
      isLocal: true,
    );
    _localHistory.insert(0, notification);
    if (_localHistory.length > _historyLimit) {
      _localHistory.removeRange(_historyLimit, _localHistory.length);
    }
    await _saveLocalHistory();
    _localChangesController.add(null);
    await _localPlugin.show(
      id: id.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'product_updates',
          'Productos y existencias',
          channelDescription:
              'Avisos sobre productos registrados y niveles de stock.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> _loadLocalHistory() async {
    if (_localHistoryLoaded) return;
    final pendingLoad = _localHistoryLoad;
    if (pendingLoad != null) {
      await pendingLoad;
      return;
    }

    final load = _readLocalHistory();
    _localHistoryLoad = load;
    try {
      await load;
      _localHistoryLoaded = true;
    } finally {
      if (identical(_localHistoryLoad, load)) _localHistoryLoad = null;
    }
  }

  Future<void> _readLocalHistory() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_localHistoryKey);
    if (encoded == null) return;
    final decoded = jsonDecode(encoded);
    if (decoded is! List) {
      throw const FormatException(
        'El historial local no tiene un formato válido.',
      );
    }
    _localHistory
      ..clear()
      ..addAll(
        decoded.whereType<Map<String, dynamic>>().map(
          AppNotification.fromLocalJson,
        ),
      );
  }

  Future<void> _saveLocalHistory() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _localHistoryKey,
      jsonEncode(_localHistory.map((item) => item.toLocalJson()).toList()),
    );
  }

  void _reportError(String context, Object error, [StackTrace? stackTrace]) {
    debugPrint('NotificationService: $context: $error');
    if (stackTrace != null) debugPrintStack(stackTrace: stackTrace);
    _errorsController.add('$context: $error');
  }

  static int _number(Object? value) => value is num ? value.toInt() : 0;

  static String _money(Object? value) {
    final amount = value is num ? value.toDouble() : 0;
    return 'S/ ${amount.toStringAsFixed(2)}';
  }
}
