import 'package:cloud_firestore/cloud_firestore.dart';

class CashShift {
  const CashShift({
    required this.id,
    required this.cashierUid,
    required this.cashierName,
    required this.status,
    required this.openingCash,
    required this.openedAt,
    required this.openedBy,
    this.closedAt,
    this.closedBy,
    this.countedCash,
  });

  final String id;
  final String cashierUid;
  final String cashierName;
  final String status;
  final double openingCash;
  final DateTime? openedAt;
  final String openedBy;
  final DateTime? closedAt;
  final String? closedBy;
  final double? countedCash;

  bool get isOpen => status == 'open';

  factory CashShift.fromMap(Map<String, dynamic> data) {
    final id = data['shiftId'];
    final cashierUid = data['cashierUid'];
    final cashierName = data['cashierName'];
    final status = data['status'];
    final openingCash = data['openingCash'];
    final openedBy = data['openedBy'];
    final openedAt = data['openedAt'];
    final closedAt = data['closedAt'];
    final closedBy = data['closedBy'];
    final countedCash = data['countedCash'];

    if (id is! String ||
        cashierUid is! String ||
        cashierName is! String ||
        status is! String ||
        !const {'open', 'closed'}.contains(status) ||
        openingCash is! num ||
        openedBy is! String ||
        (openedAt != null && openedAt is! Timestamp) ||
        (closedAt != null && closedAt is! Timestamp) ||
        (closedBy != null && closedBy is! String) ||
        (countedCash != null && countedCash is! num)) {
      throw const FormatException('El registro de turno de caja no es válido.');
    }

    return CashShift(
      id: id,
      cashierUid: cashierUid,
      cashierName: cashierName,
      status: status,
      openingCash: openingCash.toDouble(),
      openedAt: (openedAt as Timestamp?)?.toDate(),
      openedBy: openedBy,
      closedAt: (closedAt as Timestamp?)?.toDate(),
      closedBy: closedBy as String?,
      countedCash: (countedCash as num?)?.toDouble(),
    );
  }
}
