import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../providers/debt_provider.dart';
import '../services/api_service.dart';
import '../utils/format.dart';
import '../widgets/product_picker.dart';

class DebtDetailScreen extends StatefulWidget {
  final DebtEmployee employee;

  const DebtDetailScreen({super.key, required this.employee});

  @override
  State<DebtDetailScreen> createState() => _DebtDetailScreenState();
}

class _DebtDetailScreenState extends State<DebtDetailScreen> {
  EmployeeAccount? _account;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final account = await ApiService.fetchEmployeeAccount(widget.employee.id);
      if (mounted) setState(() => _account = account);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerPayment() async {
    final account = _account;
    if (account == null) return;
    final provider = context.read<DebtProvider>();
    final controller = TextEditingController(
      text: account.balance > 0 ? account.balance.toStringAsFixed(2) : '',
    );
    final notesController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Registrar abono'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Saldo pendiente: ${_money(account.balance)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Monto',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Registrar')),
        ],
      ),
    );

    if (confirmed != true) return;
    final amount = double.tryParse(controller.text.replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Monto inválido')),
        );
      }
      return;
    }

    try {
      await provider.registerPayment(
            employee: widget.employee,
            amount: amount,
            date: DateTime.now(),
            notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abono registrado')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _addProductsToDebt(Debt debt) async {
    final item = await showDialog<DebtItem>(
      context: context,
      builder: (_) => ProductPickerDialog(
        companyId: context.read<DebtProvider>().selectedCompany?.id,
      ),
    );
    if (item == null || !mounted) return;
    try {
      await ApiService.addDebtItems(debt.id!, [item]);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto agregado a la deuda')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _editItem(DebtItem item) async {
    final result = await showDialog<_ItemEditResult>(
      context: context,
      builder: (_) => _ItemEditDialog(item: item),
    );
    if (result == null || !mounted) return;
    try {
      await ApiService.updateDebtItem(
        item.id!,
        unitPrice: result.unitPrice,
        quantity: result.quantity,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto actualizado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _deleteItem(DebtItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar producto?'),
        content: Text('${item.productName} se quitará de la deuda.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiService.deleteDebtItem(item.id!);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Producto eliminado')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employee.name),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Error: $_error'))
              : _buildBody(),
      floatingActionButton: _account == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _registerPayment,
              icon: const Icon(Icons.payments),
              label: const Text('Abonar'),
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
    );
  }

  Widget _buildBody() {
    final account = _account!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
        children: [
          Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (account.employee.identification != null)
                    Text('Cédula: ${account.employee.identification}'),
                  Text(account.employee.jobTitle ?? '',
                      style: const TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  Text(
                    'Saldo: ${_money(account.balance)}',
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Cargos ${_money(account.totalCharged)}  •  Abonos ${_money(account.totalPaid)}',
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _sectionTitle('Cargos (${account.debts.length})'),
          ...account.debts.map(_buildDebtCard),
          const SizedBox(height: 8),
          _sectionTitle('Abonos (${account.payments.length})'),
          if (account.payments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Sin abonos registrados.'),
            ),
          ...account.payments.map((p) => Card(
                child: ListTile(
                  leading: const Icon(Icons.payments_outlined, color: Colors.green),
                  title: Text(_money(p.amount)),
                  subtitle: Text(
                    [
                      if (p.paymentDate != null) DateFormat('dd/MM/yyyy').format(p.paymentDate!),
                      if (p.notes != null && p.notes!.isNotEmpty) p.notes!,
                    ].join(' • '),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(text,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
    );
  }

  Widget _buildDebtCard(Debt debt) {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.shopping_basket_outlined, color: Colors.green),
        title: Text(debt.debtDate != null ? DateFormat('dd/MM/yyyy').format(debt.debtDate!) : ''),
        subtitle: Text(
          '${debt.items.length} producto(s) • ${_money(debt.total)}${debt.notes != null ? ' • ${debt.notes}' : ''}',
        ),
        trailing: Text(_money(debt.total),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        children: [
          ...debt.items.map((item) => ListTile(
                dense: true,
                title: Text(item.productName),
                subtitle: Text('${_qty(item.quantity)} x ${_money(item.unitPrice)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_money(item.subtotal),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit, size: 18),
                      tooltip: 'Editar',
                      onPressed: item.id != null ? () => _editItem(item) : null,
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      tooltip: 'Eliminar',
                      onPressed: item.id != null ? () => _deleteItem(item) : null,
                    ),
                  ],
                ),
              )),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: const Icon(Icons.add_circle_outline, color: Colors.green),
            title: const Text('Agregar producto a esta deuda',
                style: TextStyle(color: Colors.green)),
            onTap: () => _addProductsToDebt(debt),
          ),
        ],
      ),
    );
  }
}

class _ItemEditResult {
  final double unitPrice;
  final double quantity;
  _ItemEditResult(this.unitPrice, this.quantity);
}

class _ItemEditDialog extends StatefulWidget {
  final DebtItem item;
  const _ItemEditDialog({required this.item});

  @override
  State<_ItemEditDialog> createState() => _ItemEditDialogState();
}

class _ItemEditDialogState extends State<_ItemEditDialog> {
  late final TextEditingController _priceController;
  late final TextEditingController _qtyController;

  @override
  void initState() {
    super.initState();
    _priceController = TextEditingController(
        text: widget.item.unitPrice.toStringAsFixed(2));
    _qtyController = TextEditingController(text: formatQty(widget.item.quantity));
  }

  @override
  void dispose() {
    _priceController.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.productName),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: r'Precio ($)',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _qtyController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Cantidad',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final price =
                double.tryParse(_priceController.text.replaceAll(',', '.'));
            final qty =
                double.tryParse(_qtyController.text.replaceAll(',', '.'));
            if (price == null || price < 0 || qty == null || qty <= 0) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Valores inválidos')),
              );
              return;
            }
            Navigator.pop(context, _ItemEditResult(price, qty));
          },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

String _money(double value) => formatMoney(value);

String _qty(double value) => formatQty(value);