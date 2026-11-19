import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/cash_shift.dart';
import 'models/product.dart';
import 'sale_receipt_page.dart';
import 'services/cash_shift_service.dart';
import 'services/inventory_service.dart';

const _cashierGreen = Color(0xFF07835F);
const _cashierInk = Color(0xFF17362D);
const _cashierMuted = Color(0xFF61756C);
const _cashierForest = Color(0xFF07382D);

class CashierHomePage extends StatefulWidget {
  const CashierHomePage({
    required this.inventory,
    required this.cashShifts,
    required this.displayName,
    required this.onOpenProducts,
    required this.onOpenSales,
    required this.onOpenHistory,
    super.key,
  });

  final InventoryService inventory;
  final CashShiftService cashShifts;
  final String displayName;
  final VoidCallback onOpenProducts;
  final VoidCallback onOpenSales;
  final VoidCallback onOpenHistory;

  @override
  State<CashierHomePage> createState() => _CashierHomePageState();
}

class _CashierHomePageState extends State<CashierHomePage> {
  final _productSearch = TextEditingController();
  late final _shiftStream = widget.cashShifts.watchCurrentShift();
  late final _productsStream = widget.inventory.watchProducts();
  final Map<String?, Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>>>
  _salesStreams = {};
  String _query = '';
  bool _working = false;

  @override
  void dispose() {
    _productSearch.dispose();
    super.dispose();
  }

  Stream<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _salesFor(
    CashShift? shift,
  ) {
    final shiftId = shift?.isOpen == true ? shift!.id : null;
    return _salesStreams.putIfAbsent(
      shiftId,
      () => widget.inventory.watchMySales(
        shiftId: shiftId,
        limit: shiftId == null ? 3 : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CashShift?>(
      stream: _shiftStream,
      builder: (context, shiftSnapshot) {
        if (shiftSnapshot.hasError) {
          return _CashierErrorCard(
            message: 'No se pudo cargar el turno: ${shiftSnapshot.error}',
          );
        }
        if (shiftSnapshot.connectionState == ConnectionState.waiting) {
          return const _CashierLoadingCard();
        }
        final shift = shiftSnapshot.data;
        return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: _salesFor(shift),
          builder: (context, salesSnapshot) => _buildDashboard(
            context,
            shift: shift,
            salesSnapshot: salesSnapshot,
          ),
        );
      },
    );
  }

  Widget _buildDashboard(
    BuildContext context, {
    required CashShift? shift,
    required AsyncSnapshot<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    salesSnapshot,
  }) {
    final sales = salesSnapshot.data ?? const [];
    final total = _salesTotal(sales);
    final cashSales = _salesTotal(
      sales.where((sale) => sale.data()['paymentMethod'] == 'Efectivo'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CashierHeading(
          eyebrow: 'CAJA · CHINCHA',
          title: 'Lista para atender',
          subtitle:
              'Hola, ${widget.displayName}. Revisa tu turno y continúa con la atención.',
        ),
        const SizedBox(height: 16),
        if (salesSnapshot.hasError)
          _CashierErrorCard(
            message: 'No se pudieron cargar las ventas: ${salesSnapshot.error}',
          ),
        _shiftCard(
          context,
          shift: shift,
          sales: sales,
          total: total,
          cashSales: cashSales,
        ),
        const SizedBox(height: 16),
        _productCatalogPreview(),
        const SizedBox(height: 16),
        _recentSales(salesSnapshot),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE5F4ED),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.verified_user_outlined,
                color: _cashierGreen,
                size: 19,
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Tu espacio de Caja: consulta precios y stock, registra ventas y controla tu turno. No permite ver costos ni editar productos.',
                  style: TextStyle(
                    color: _cashierInk,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _shiftCard(
    BuildContext context, {
    required CashShift? shift,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> sales,
    required double total,
    required double cashSales,
  }) {
    final isOpen = shift?.isOpen == true;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _cashierForest,
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'VENTAS DEL TURNO',
                  style: TextStyle(
                    color: Color(0xFFB8D3C9),
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _ShiftBadge(isOpen: isOpen),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isOpen ? _cashierMoney(total) : 'Turno cerrado',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isOpen
                ? 'Turno #${_shortId(shift!.id)} · ${_dateTime(shift.openedAt)}'
                : 'Abre un turno con el fondo inicial contado en caja.',
            style: const TextStyle(color: Color(0xFFB8D3C9), fontSize: 11),
          ),
          if (isOpen) ...[
            const SizedBox(height: 13),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                _ShiftMetric(
                  label: '${sales.length} comprobantes',
                  icon: Icons.receipt_long_outlined,
                ),
                _ShiftMetric(
                  label: '${_unitsSold(sales)} productos vendidos',
                  icon: Icons.inventory_2_outlined,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              'Efectivo esperado: ${_cashierMoney(shift!.openingCash + cashSales)}',
              style: const TextStyle(
                color: Color(0xFFDCEFE7),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _working ? null : widget.onOpenSales,
              icon: const Icon(Icons.add),
              label: const Text('Nueva venta'),
              style: FilledButton.styleFrom(
                backgroundColor: _cashierGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _working ? null : () => _closeShift(context, shift),
                icon: const Icon(Icons.lock_outline, size: 17),
                label: Text(_working ? 'Procesando…' : 'Cerrar turno'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFDCEFE7),
                ),
              ),
            ),
          ] else ...[
            if (shift?.countedCash != null) ...[
              const SizedBox(height: 7),
              Text(
                'Último arqueo: ${_cashierMoney(shift!.countedCash!)}',
                style: const TextStyle(color: Color(0xFFDCEFE7), fontSize: 12),
              ),
            ],
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _working ? null : () => _openShift(context),
              icon: const Icon(Icons.lock_open_outlined),
              label: Text(_working ? 'Procesando…' : 'Abrir turno'),
              style: FilledButton.styleFrom(
                backgroundColor: _cashierGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _productCatalogPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Precios y existencias',
                style: TextStyle(
                  color: _cashierInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: widget.onOpenProducts,
              child: const Text('Catálogo'),
            ),
          ],
        ),
        TextField(
          controller: _productSearch,
          onChanged: (value) => setState(() => _query = value.trim()),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Nombre, SKU o código de barras',
            isDense: true,
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Product>>(
          stream: _productsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _CashierErrorCard(
                message:
                    'No se pudieron cargar los productos: ${snapshot.error}',
              );
            }
            if (!snapshot.hasData) return const _CashierLoadingCard();
            final query = _query.toLowerCase();
            final products = snapshot.data!
                .where((product) => product.active)
                .where(
                  (product) =>
                      query.isEmpty ||
                      product.name.toLowerCase().contains(query) ||
                      product.sku.toLowerCase().contains(query),
                )
                .take(4)
                .toList();
            if (products.isEmpty) {
              return const _CashierEmptyCard(
                message: 'No hay productos que coincidan con la búsqueda.',
              );
            }
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (var index = 0; index < products.length; index++) ...[
                    _ProductPreviewTile(
                      product: products[index],
                      onTap: widget.onOpenProducts,
                    ),
                    if (index < products.length - 1) const Divider(height: 1),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _recentSales(
    AsyncSnapshot<List<QueryDocumentSnapshot<Map<String, dynamic>>>> snapshot,
  ) {
    final sales = snapshot.data ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mis últimas ventas',
                style: TextStyle(
                  color: _cashierInk,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton(
              onPressed: widget.onOpenHistory,
              child: const Text('Historial'),
            ),
          ],
        ),
        if (snapshot.hasError)
          _CashierErrorCard(
            message: 'No se pudo cargar el historial: ${snapshot.error}',
          )
        else if (!snapshot.hasData)
          const _CashierLoadingCard()
        else if (sales.isEmpty)
          const _CashierEmptyCard(
            message: 'Tus ventas aparecerán aquí al registrar el primer cobro.',
          )
        else
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var index = 0; index < sales.length && index < 3; index++)
                  _SalePreviewTile(sale: sales[index]),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _openShift(BuildContext context) async {
    final openingCash = await showDialog<double>(
      context: context,
      builder: (_) => const _CashAmountDialog(
        title: 'Abrir turno de caja',
        subtitle:
            'Cuenta el efectivo inicial del cajón antes de comenzar a vender.',
        amountLabel: 'Fondo inicial',
        confirmLabel: 'Abrir turno',
      ),
    );
    if (openingCash == null || !mounted) return;
    setState(() => _working = true);
    try {
      await widget.cashShifts.openShift(openingCash: openingCash);
    } on FirebaseException catch (error) {
      if (mounted) _showMessage(_cashierFirebaseMessage(error));
    } on StateError catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _closeShift(BuildContext context, CashShift shift) async {
    setState(() => _working = true);
    try {
      final sales = await widget.inventory.getMyShiftSales(shift.id);
      if (!mounted || !context.mounted) return;
      final cashSales = _salesTotal(
        sales.where((sale) => sale.data()['paymentMethod'] == 'Efectivo'),
      );
      final expectedCash = shift.openingCash + cashSales;
      final countedCash = await showDialog<double>(
        context: context,
        builder: (_) => _CashAmountDialog(
          title: 'Cerrar turno',
          subtitle: 'Cuenta el efectivo físico antes de confirmar el arqueo.',
          amountLabel: 'Efectivo contado',
          confirmLabel: 'Confirmar cierre',
          expectedCash: expectedCash,
        ),
      );
      if (countedCash == null || !mounted) return;
      await widget.cashShifts.closeShift(
        shift: shift,
        countedCash: countedCash,
      );
      if (mounted) {
        _showMessage('Turno cerrado. El arqueo quedó guardado.');
      }
    } on FirebaseException catch (error) {
      if (mounted) _showMessage(_cashierFirebaseMessage(error));
    } on StateError catch (error) {
      if (mounted) _showMessage(error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class CashierSalesHistoryPage extends StatelessWidget {
  const CashierSalesHistoryPage({
    required this.inventory,
    required this.onOpenSales,
    super.key,
  });

  final InventoryService inventory;
  final VoidCallback onOpenSales;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _CashierHeading(
          eyebrow: 'ACTIVIDAD / CAJA',
          title: 'Historial de ventas',
          subtitle: 'Consulta los comprobantes registrados por tu cuenta.',
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          stream: inventory.watchMySales(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _CashierErrorCard(
                message: 'No se pudo cargar el historial: ${snapshot.error}',
              );
            }
            if (!snapshot.hasData) return const _CashierLoadingCard();
            final sales = snapshot.data!;
            if (sales.isEmpty) {
              return const _CashierEmptyCard(
                message: 'Aún no tienes ventas registradas.',
              );
            }
            return Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final sale in sales)
                    _SalePreviewTile(
                      sale: sale,
                      onTap: () => _showSaleDetails(context, sale),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Future<void> _showSaleDetails(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> sale,
  ) async {
    final data = sale.data();
    final rawItems = data['items'];
    final items = rawItems is List
        ? rawItems.whereType<Map<String, dynamic>>().toList()
        : <Map<String, dynamic>>[];
    final action = await showSaleReceipt(
      context,
      saleId: sale.id,
      items: items,
      total: _numeric(data['total']),
      paymentMethod: data['paymentMethod'] as String? ?? 'No especificado',
      amountReceived: _numeric(data['amountReceived'] ?? data['total']),
      changeDue: _numeric(data['changeDue']),
      sellerName: data['createdByName'] as String? ?? '',
      occurredAt: _timestamp(data['occurredAt']),
    );
    if (action == SaleReceiptAction.newSale) onOpenSales();
  }
}

class _CashAmountDialog extends StatefulWidget {
  const _CashAmountDialog({
    required this.title,
    required this.subtitle,
    required this.amountLabel,
    required this.confirmLabel,
    this.expectedCash,
  });

  final String title;
  final String subtitle;
  final String amountLabel;
  final String confirmLabel;
  final double? expectedCash;

  @override
  State<_CashAmountDialog> createState() => _CashAmountDialogState();
}

class _CashAmountDialogState extends State<_CashAmountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController(text: '0.00');

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double? get _amount => _parseMoney(_amountController.text);

  @override
  Widget build(BuildContext context) {
    final amount = _amount;
    final difference = widget.expectedCash == null || amount == null
        ? null
        : amount - widget.expectedCash!;
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.subtitle),
            if (widget.expectedCash != null) ...[
              const SizedBox(height: 14),
              _DetailAmountRow(
                label: 'Efectivo esperado',
                amount: widget.expectedCash!,
                emphasized: true,
              ),
              const SizedBox(height: 10),
            ] else
              const SizedBox(height: 14),
            TextFormField(
              controller: _amountController,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: InputDecoration(
                labelText: widget.amountLabel,
                prefixText: 'S/ ',
              ),
              onChanged: (_) => setState(() {}),
              validator: (value) => _parseMoney(value ?? '') == null
                  ? 'Ingresa un monto válido.'
                  : null,
            ),
            if (difference != null) ...[
              const SizedBox(height: 12),
              _DetailAmountRow(
                label: difference >= 0 ? 'Diferencia a favor' : 'Faltante',
                amount: difference.abs(),
                emphasized: true,
                color: difference >= 0
                    ? _cashierGreen
                    : const Color(0xFFAE4545),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            Navigator.of(context).pop(_amount);
          },
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _CashierHeading extends StatelessWidget {
  const _CashierHeading({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
  });

  final String eyebrow;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: const TextStyle(
            color: _cashierGreen,
            fontSize: 10,
            letterSpacing: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          title,
          style: const TextStyle(
            color: _cashierInk,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: _cashierMuted,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ShiftBadge extends StatelessWidget {
  const _ShiftBadge({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFE5F4ED) : const Color(0xFFFFF5D6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOpen ? 'Abierta' : 'Cerrada',
        style: TextStyle(
          color: isOpen ? _cashierGreen : const Color(0xFF765711),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ShiftMetric extends StatelessWidget {
  const _ShiftMetric({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFFB8D3C9)),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Color(0xFFB8D3C9), fontSize: 11),
        ),
      ],
    );
  }
}

class _ProductPreviewTile extends StatelessWidget {
  const _ProductPreviewTile({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFE5F4ED),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.inventory_2_outlined,
          color: _cashierGreen,
          size: 20,
        ),
      ),
      title: Text(
        product.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _cashierInk,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        '${product.sku} · ${product.category}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: _cashierMuted, fontSize: 10),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            _cashierMoney(product.price),
            style: const TextStyle(
              color: _cashierGreen,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            '${product.stock} u.',
            style: const TextStyle(color: _cashierMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SalePreviewTile extends StatelessWidget {
  const _SalePreviewTile({required this.sale, this.onTap});

  final QueryDocumentSnapshot<Map<String, dynamic>> sale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final data = sale.data();
    return ListTile(
      onTap: onTap,
      leading: const CircleAvatar(
        radius: 17,
        backgroundColor: Color(0xFFE5F4ED),
        child: Icon(
          Icons.receipt_long_outlined,
          color: _cashierGreen,
          size: 17,
        ),
      ),
      title: Text(
        '#${_shortId(sale.id)} · ${data['paymentMethod'] ?? 'Venta'}',
        style: const TextStyle(
          color: _cashierInk,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        _dateTime(_timestamp(data['occurredAt'])),
        style: const TextStyle(color: _cashierMuted, fontSize: 10),
      ),
      trailing: Text(
        _cashierMoney(_numeric(data['total'])),
        style: const TextStyle(
          color: _cashierInk,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DetailAmountRow extends StatelessWidget {
  const _DetailAmountRow({
    required this.label,
    required this.amount,
    this.emphasized = false,
    this.color = _cashierInk,
  });

  final String label;
  final double amount;
  final bool emphasized;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
        Text(
          _cashierMoney(amount),
          style: TextStyle(color: color, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _CashierErrorCard extends StatelessWidget {
  const _CashierErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => _CashierMessageCard(
    message: message,
    icon: Icons.error_outline,
    color: const Color(0xFFAE4545),
    background: const Color(0xFFFDEDEE),
  );
}

class _CashierEmptyCard extends StatelessWidget {
  const _CashierEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => _CashierMessageCard(
    message: message,
    icon: Icons.info_outline,
    color: _cashierMuted,
    background: Colors.white,
  );
}

class _CashierLoadingCard extends StatelessWidget {
  const _CashierLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _CashierMessageCard extends StatelessWidget {
  const _CashierMessageCard({
    required this.message,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String message;
  final IconData icon;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: const Color(0xFFDCE7E1)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontSize: 12, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

double _salesTotal(
  Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> sales,
) {
  return sales.fold<double>(
    0,
    (total, sale) => total + _numeric(sale.data()['total']),
  );
}

int _unitsSold(Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> sales) {
  return sales.fold<int>(0, (total, sale) {
    final items = sale.data()['items'];
    if (items is! List) return total;
    return total +
        items.fold<int>(0, (subtotal, item) {
          if (item is! Map) return subtotal;
          final quantity = item['quantity'];
          return subtotal + (quantity is num ? quantity.toInt() : 0);
        });
  });
}

double _numeric(Object? value) => value is num ? value.toDouble() : 0;

DateTime? _timestamp(Object? value) =>
    value is Timestamp ? value.toDate() : null;

String _dateTime(DateTime? date) {
  if (date == null) return 'Registrando…';
  final local = date.toLocal();
  return '${_twoDigits(local.day)}/${_twoDigits(local.month)}/${local.year} · '
      '${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _shortId(String id) =>
    id.substring(0, id.length < 8 ? id.length : 8).toUpperCase();

String _cashierMoney(double value) => 'S/ ${value.toStringAsFixed(2)}';

double? _parseMoney(String raw) {
  final value = double.tryParse(raw.trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite || value < 0) return null;
  return (value * 100).round() / 100;
}

String _cashierFirebaseMessage(FirebaseException error) {
  return switch (error.code) {
    'permission-denied' =>
      'Firestore no permitió esta operación. Verifica las reglas publicadas.',
    'unavailable' =>
      'No hay conexión con Firestore. Revisa internet e inténtalo otra vez.',
    _ => 'No se pudo guardar el turno (${error.code}). Inténtalo otra vez.',
  };
}
