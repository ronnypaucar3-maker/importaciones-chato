int moneyToCents(double amount) {
  if (!amount.isFinite || amount < 0) {
    throw ArgumentError.value(amount, 'amount', 'Monto no válido.');
  }
  return (amount * 100).round();
}

class CashPayment {
  const CashPayment._({
    required this.total,
    required this.amountReceived,
    required this.changeDue,
  });

  final double total;
  final double amountReceived;
  final double changeDue;

  factory CashPayment.calculate({
    required double total,
    required double amountReceived,
  }) {
    final totalCents = moneyToCents(total);
    final receivedCents = moneyToCents(amountReceived);
    if (receivedCents < totalCents) {
      throw StateError(
        'El monto recibido no cubre el total actualizado de la venta.',
      );
    }

    return CashPayment._(
      total: totalCents / 100,
      amountReceived: receivedCents / 100,
      changeDue: (receivedCents - totalCents) / 100,
    );
  }
}
