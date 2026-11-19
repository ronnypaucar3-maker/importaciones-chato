import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/cash_payment.dart';

void main() {
  group('CashPayment', () {
    test('rounds to cents and calculates change', () {
      final payment = CashPayment.calculate(
        total: 12.345,
        amountReceived: 20,
      );

      expect(payment.total, 12.35);
      expect(payment.amountReceived, 20);
      expect(payment.changeDue, 7.65);
    });

    test('allows exact payment with no change', () {
      final payment = CashPayment.calculate(
        total: 12.35,
        amountReceived: 12.35,
      );

      expect(payment.changeDue, 0);
    });

    test('rejects insufficient received cash', () {
      expect(
        () => CashPayment.calculate(total: 12.35, amountReceived: 12.34),
        throwsStateError,
      );
    });

    test('rejects invalid monetary values', () {
      expect(() => moneyToCents(double.nan), throwsArgumentError);
      expect(() => moneyToCents(-0.01), throwsArgumentError);
    });
  });
}
