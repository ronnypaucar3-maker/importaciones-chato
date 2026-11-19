import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/cash_shift.dart';

class CashShiftService {
  CashShiftService({
    required this.user,
    required this.displayName,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final User user;
  final String displayName;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _currentShift =>
      _firestore.collection('cashShifts').doc(user.uid);

  CollectionReference<Map<String, dynamic>> get _history =>
      _firestore.collection('cashShiftHistory');

  Stream<CashShift?> watchCurrentShift() {
    return _currentShift.snapshots().map((snapshot) {
      final data = snapshot.data();
      return snapshot.exists && data != null ? CashShift.fromMap(data) : null;
    });
  }

  Stream<List<CashShift>> watchMyHistory() {
    return _history
        .where('cashierUid', isEqualTo: user.uid)
        .orderBy('closedAt', descending: true)
        .limit(50)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((document) => CashShift.fromMap(document.data()))
              .toList(),
        );
  }

  Future<void> openShift({required double openingCash}) async {
    if (!openingCash.isFinite || openingCash < 0) {
      throw ArgumentError.value(openingCash, 'openingCash', 'Monto no válido.');
    }

    final historyRef = _history.doc();
    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(_currentShift);
      if (current.exists && current.data()?['status'] == 'open') {
        throw StateError('Ya tienes un turno de caja abierto.');
      }
      if (current.exists && current.data()?['status'] != 'closed') {
        throw StateError('No se pudo validar el estado del turno anterior.');
      }

      transaction.set(_currentShift, {
        'shiftId': historyRef.id,
        'cashierUid': user.uid,
        'cashierName': displayName,
        'status': 'open',
        'openingCash': _moneyAmount(openingCash),
        'openedAt': FieldValue.serverTimestamp(),
        'openedBy': user.uid,
        'closedAt': null,
        'closedBy': null,
        'countedCash': null,
      });
    });
  }

  Future<void> closeShift({
    required CashShift shift,
    required double countedCash,
  }) async {
    if (!countedCash.isFinite || countedCash < 0) {
      throw ArgumentError.value(countedCash, 'countedCash', 'Monto no válido.');
    }

    final historyRef = _history.doc(shift.id);
    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(_currentShift);
      final data = current.data();
      if (!current.exists ||
          data == null ||
          data['status'] != 'open' ||
          data['shiftId'] != shift.id) {
        throw StateError('El turno ya no está abierto.');
      }

      final closedAt = FieldValue.serverTimestamp();
      final roundedCount = _moneyAmount(countedCash);
      transaction.update(_currentShift, {
        'status': 'closed',
        'closedAt': closedAt,
        'closedBy': user.uid,
        'countedCash': roundedCount,
      });
      transaction.set(historyRef, {
        'shiftId': shift.id,
        'cashierUid': data['cashierUid'],
        'cashierName': data['cashierName'],
        'status': 'closed',
        'openingCash': data['openingCash'],
        'openedAt': data['openedAt'],
        'openedBy': data['openedBy'],
        'closedAt': closedAt,
        'closedBy': user.uid,
        'countedCash': roundedCount,
      });
    });
  }
}

double _moneyAmount(double value) => (value * 100).round() / 100;
