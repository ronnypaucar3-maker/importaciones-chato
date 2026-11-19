import 'package:flutter/material.dart';

const _receiptGreen = Color(0xFF07835F);
const _receiptForest = Color(0xFF07382D);
const _receiptInk = Color(0xFF17362D);
const _receiptMuted = Color(0xFF61756C);
const _receiptCanvas = Color(0xFFF1F6F3);

enum SaleReceiptAction { history, newSale }

Future<SaleReceiptAction?> showSaleReceipt(
  BuildContext context, {
  required String saleId,
  required List<Map<String, dynamic>> items,
  required double total,
  required String paymentMethod,
  required double amountReceived,
  required double changeDue,
  required String sellerName,
  DateTime? occurredAt,
}) {
  return showDialog<SaleReceiptAction>(
    context: context,
    barrierDismissible: false,
    builder: (_) => Dialog.fullscreen(
      child: SaleReceiptPage(
        saleId: saleId,
        items: items,
        total: total,
        paymentMethod: paymentMethod,
        amountReceived: amountReceived,
        changeDue: changeDue,
        sellerName: sellerName,
        occurredAt: occurredAt,
      ),
    ),
  );
}

class SaleReceiptPage extends StatelessWidget {
  const SaleReceiptPage({
    required this.saleId,
    required this.items,
    required this.total,
    required this.paymentMethod,
    required this.amountReceived,
    required this.changeDue,
    required this.sellerName,
    this.occurredAt,
    super.key,
  });

  final String saleId;
  final List<Map<String, dynamic>> items;
  final double total;
  final String paymentMethod;
  final double amountReceived;
  final double changeDue;
  final String sellerName;
  final DateTime? occurredAt;

  @override
  Widget build(BuildContext context) {
    final totalCents = (total * 100).round();
    final baseCents = (totalCents / 1.18).round();
    final taxCents = totalCents - baseCents;
    final units = items.fold<int>(
      0,
      (sum, item) => sum + _receiptInt(item['quantity']),
    );

    return Scaffold(
      backgroundColor: _receiptCanvas,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
                    children: [
                      const Text(
                        'COMPROBANTE · RESULTADO ESTÁTICO',
                        style: TextStyle(
                          color: _receiptGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.15,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Boleta simulada',
                        style: TextStyle(
                          color: _receiptInk,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'No tiene validez tributaria',
                        style: TextStyle(color: _receiptMuted, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      _receiptCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'IMPORTACIONES',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _receiptMuted,
                                fontSize: 9,
                                letterSpacing: 1.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 1),
                            const Text(
                              'CHATO',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _receiptForest,
                                fontSize: 24,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text(
                              'Chincha, Perú · Sede principal',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _receiptMuted,
                                fontSize: 10,
                              ),
                            ),
                            const Divider(height: 22),
                            Text(
                              _receiptNumber(saleId),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: _receiptInk,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _ReceiptMeta(
                              label: 'Fecha',
                              value: _receiptDate(occurredAt),
                            ),
                            _ReceiptMeta(
                              label: 'Caja',
                              value: sellerName.isEmpty
                                  ? 'No disponible'
                                  : sellerName,
                            ),
                            const _ReceiptMeta(
                              label: 'Cliente',
                              value: 'Venta al público',
                            ),
                            const Divider(height: 18),
                            for (final item in items) _ReceiptItem(item: item),
                            const Divider(height: 18),
                            _ReceiptAmount(
                              label: 'Base imponible',
                              amount: baseCents / 100,
                            ),
                            const SizedBox(height: 8),
                            _ReceiptAmount(
                              label: 'IGV 18%',
                              amount: taxCents / 100,
                            ),
                            const Divider(height: 22),
                            _ReceiptAmount(
                              label: 'TOTAL',
                              amount: totalCents / 100,
                              emphasized: true,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              paymentMethod == 'Efectivo'
                                  ? 'Efectivo: ${_receiptMoney(amountReceived)} · Vuelto: ${_receiptMoney(changeDue)}'
                                  : 'Pago: $paymentMethod',
                              style: const TextStyle(
                                color: _receiptMuted,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE5F4ED),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 5,
                                  ),
                                  child: Text(
                                    'Ejemplo · Sin validez ante SUNAT',
                                    style: TextStyle(
                                      color: _receiptGreen,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _ReceiptMetric(
                              value: '${items.length}',
                              label: 'Artículos',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ReceiptMetric(
                              value: '$units',
                              label: 'Unidades',
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ReceiptMetric(
                              value: _receiptMoney(total),
                              label: 'Total',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _receiptCard(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              color: _receiptGreen,
                              size: 18,
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'MOVIMIENTO DE STOCK',
                                    style: TextStyle(
                                      color: _receiptGreen,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Se descontaron $units unidades del inventario por esta venta.',
                                    style: const TextStyle(
                                      color: _receiptMuted,
                                      fontSize: 10,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            Navigator.of(context)
                                .pop(SaleReceiptAction.history),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('Ver mi historial'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _receiptGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      OutlinedButton.icon(
                        onPressed: () =>
                            Navigator.of(context)
                                .pop(SaleReceiptAction.newSale),
                        icon: const Icon(Icons.add),
                        label: const Text('Nueva venta'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _receiptGreen,
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          side: const BorderSide(color: Color(0xFFDCE7E1)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
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

Widget _receiptCard({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFE4ECE7)),
    ),
    child: child,
  );
}

class _ReceiptMeta extends StatelessWidget {
  const _ReceiptMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              label,
              style: const TextStyle(color: _receiptMuted, fontSize: 9),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _receiptInk,
                fontSize: 9,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptItem extends StatelessWidget {
  const _ReceiptItem({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final name = item['name'] as String? ?? 'Producto';
    final sku = item['sku'] as String? ?? '';
    final quantity = _receiptInt(item['quantity']);
    final unitPrice = _receiptDouble(item['unitPrice']);
    final subtotal = _receiptDouble(item['subtotal']);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: _receiptInk,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${sku.isEmpty ? 'Artículo' : sku} · $quantity × ${_receiptMoney(unitPrice)}',
                  style: const TextStyle(color: _receiptMuted, fontSize: 9),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _receiptMoney(subtotal),
            style: const TextStyle(
              color: _receiptInk,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReceiptAmount extends StatelessWidget {
  const _ReceiptAmount({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final double amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: _receiptInk,
              fontSize: emphasized ? 12 : 10,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ),
        Text(
          _receiptMoney(amount),
          style: TextStyle(
            color: _receiptInk,
            fontSize: emphasized ? 20 : 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ReceiptMetric extends StatelessWidget {
  const _ReceiptMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5F4ED),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _receiptGreen,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: _receiptMuted, fontSize: 8),
          ),
        ],
      ),
    );
  }
}

String _receiptNumber(String id) {
  final shortId = id.substring(0, id.length < 6 ? id.length : 6).toUpperCase();
  return 'B001-$shortId';
}

String _receiptDate(DateTime? value) {
  if (value == null) return 'Fecha no disponible';
  final date = value.toLocal();
  return '${_receiptTwoDigits(date.day)}/${_receiptTwoDigits(date.month)}/${date.year} · '
      '${_receiptTwoDigits(date.hour)}:${_receiptTwoDigits(date.minute)}';
}

String _receiptMoney(double value) => 'S/ ${value.toStringAsFixed(2)}';

int _receiptInt(Object? value) => value is num ? value.toInt() : 0;

double _receiptDouble(Object? value) => value is num ? value.toDouble() : 0;

String _receiptTwoDigits(int value) => value.toString().padLeft(2, '0');
