import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../providers/debt_provider.dart';
import '../services/api_service.dart';

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
        subtitle: Text('${debt.items.length} producto(s)${debt.notes != null ? ' • ${debt.notes}' : ''}'),
        trailing: Text(_money(debt.total),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
        children: debt.items
            .map((item) => ListTile(
                  dense: true,
                  title: Text(item.productName),
                  subtitle: Text('${_qty(item.quantity)} x ${_money(item.unitPrice)}'),
                  trailing: Text(_money(item.subtotal)),
                ))
            .toList(),
      ),
    );
  }
}

String _money(double value) =>
    NumberFormat.currency(locale: 'es', symbol: 'Bs ', decimalDigits: 2).format(value);

String _qty(double value) {
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
}