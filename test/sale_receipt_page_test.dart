import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/sale_receipt_page.dart';

void main() {
  testWidgets('shows a simulated receipt with tax and history action', (
    tester,
  ) async {
    SaleReceiptAction? selectedAction;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selectedAction = await showSaleReceipt(
                  context,
                  saleId: 'abc123456789',
                  items: [
                    {
                      'sku': 'ITEM-01',
                      'name': 'Producto de prueba',
                      'quantity': 2,
                      'unitPrice': 59.0,
                      'subtotal': 118.0,
                    },
                  ],
                  total: 118,
                  paymentMethod: 'Efectivo',
                  amountReceived: 120,
                  changeDue: 2,
                  sellerName: 'Cajero de prueba',
                  occurredAt: DateTime(2026, 11, 19, 10),
                );
              },
              child: const Text('Abrir comprobante'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir comprobante'));
    await tester.pumpAndSettle();

    expect(find.text('Boleta simulada'), findsOneWidget);
    expect(find.text('No tiene validez tributaria'), findsOneWidget);
    expect(find.text('Base imponible'), findsOneWidget);
    expect(find.text('S/ 100.00'), findsOneWidget);
    expect(find.text('S/ 18.00'), findsOneWidget);
    expect(find.textContaining('Vuelto: S/ 2.00'), findsOneWidget);

    await tester.tap(find.text('Ver mi historial'));
    await tester.pumpAndSettle();

    expect(selectedAction, SaleReceiptAction.history);
  });
}
