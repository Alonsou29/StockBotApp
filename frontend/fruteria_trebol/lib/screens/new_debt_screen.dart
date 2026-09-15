import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/debt.dart';
import '../models/employee.dart';
import '../providers/debt_provider.dart';
import '../utils/format.dart';
import '../widgets/product_picker.dart';
import 'debt_report_screen.dart';

class NewDebtScreen extends StatefulWidget {
  const NewDebtScreen({super.key});

  @override
  State<NewDebtScreen> createState() => _NewDebtScreenState();
}

class _NewDebtScreenState extends State<NewDebtScreen> {
  int _currentStep = 0;

  Employee? _employee;
  final List<DebtItem> _items = [];
  final DateTime _date = DateTime.now();  final TextEditingController _notesController = TextEditingController();

  final TextEditingController _employeeSearch = TextEditingController();

  List<Employee> _employeeResults = [];
  bool _searchingEmployees = false;
  bool _saving = false;

  @override
  void dispose() {
    _notesController.dispose();
    _employeeSearch.dispose();
    super.dispose();
  }

  double get _total => _items.fold(0.0, (sum, i) => sum + i.subtotal);

  Future<void> _searchEmployees(String query) async {
    if (query.trim().length < 2) return;
    setState(() => _searchingEmployees = true);
    try {
      final results = await context.read<DebtProvider>().searchEmployees(query.trim());
      if (mounted) setState(() => _employeeResults = results);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error buscando empleados: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _searchingEmployees = false);
    }
  }

  Future<void> _pickProduct() async {
    final item = await showDialog<DebtItem>(
      context: context,
      builder: (_) => ProductPickerDialog(
        companyId: context.read<DebtProvider>().selectedCompany?.id,
      ),
    );
    if (item == null || !mounted) return;
    setState(() => _items.add(item));
  }

  void _selectEmployee(Employee employee) {
    setState(() {
      _employee = employee;
      _employeeResults = [];
      _employeeSearch.clear();
    });
  }

  Future<void> _editItemQuantity(int index) async {
    final item = _items[index];
    final controller = TextEditingController(text: _qty(item.quantity));
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.productName),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Cantidad',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(context, value);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (value == null || value <= 0) return;
    setState(() {
      _items[index] = DebtItem(
        odooProductId: item.odooProductId,
        productName: item.productName,
        productCode: item.productCode,
        unitPrice: item.unitPrice,
        quantity: value,
        subtotal: double.parse((item.unitPrice * value).toStringAsFixed(2)),
      );
    });
  }

  Future<void> _save() async {
    if (_employee == null || _items.isEmpty) return;
    setState(() => _saving = true);
    try {
      final debt = await context.read<DebtProvider>().createDebt(
            employee: _employee!,
            date: _date,
            notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
            items: _items,
          );
      if (!mounted) return;
      final companyName = context.read<DebtProvider>().selectedCompany?.name ?? '';
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => DebtReportScreen.receipt(
            companyName: companyName,
            receipt: debt,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error guardando deuda: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<DebtProvider>().selectedCompany;
    if (company == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Nueva deuda')),
        body: const Center(child: Text('Selecciona una cede primero.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva deuda'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepTapped: (step) => setState(() => _currentStep = step),
        controlsBuilder: (context, details) {
          final isLast = _currentStep == 2;
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                ElevatedButton(
                  onPressed: _saving
                      ? null
                      : isLast
                          ? _save
                          : () => _onContinue(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(_saving ? 'Guardando...' : (isLast ? 'Guardar deuda' : 'Continuar')),
                ),
                const SizedBox(width: 8),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: _saving ? null : details.onStepCancel,
                    child: const Text('Atrás'),
                  ),
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Empleado'),
            subtitle: Text(_employee?.name ?? 'Busca y selecciona'),
            isActive: _currentStep >= 0,
            state: _employee != null ? StepState.complete : StepState.indexed,
            content: _buildEmployeeStep(),
          ),
          Step(
            title: const Text('Productos'),
            subtitle: Text('${_items.length} producto(s)'),
            isActive: _currentStep >= 1,
            state: _items.isNotEmpty ? StepState.complete : StepState.indexed,
            content: _buildProductsStep(),
          ),
          Step(
            title: const Text('Confirmar'),
            isActive: _currentStep >= 2,
            content: _buildConfirmStep(company.name),
          ),
        ],
      ),
    );
  }

  void _onContinue() {
    if (_currentStep == 0 && _employee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona un empleado')),
      );
      return;
    }
    if (_currentStep == 1 && _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto')),
      );
      return;
    }
    setState(() => _currentStep += 1);
  }

  Widget _buildEmployeeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_employee != null)
          Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: const Icon(Icons.person, color: Colors.green),
              title: Text(_employee!.name),
              subtitle: Text([
                if (_employee!.identification != null) _employee!.identification!,
                if (_employee!.jobTitle != null) _employee!.jobTitle!,
              ].join(' • ')),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _employee = null),
              ),
            ),
          ),
        TextField(
          controller: _employeeSearch,
          onSubmitted: _searchEmployees,
          decoration: InputDecoration(
            labelText: 'Buscar empleado por nombre',
            border: const OutlineInputBorder(),
            isDense: true,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => _searchEmployees(_employeeSearch.text),
            ),
          ),
        ),
        if (_searchingEmployees)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          ),
        ..._employeeResults.map(
          (e) => ListTile(
            dense: true,
            leading: const Icon(Icons.person_outline),
            title: Text(e.name),
            subtitle: Text(e.identification ?? e.jobTitle ?? ''),
            onTap: () => _selectEmployee(e),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OutlinedButton.icon(
          onPressed: _pickProduct,
          icon: const Icon(Icons.add_circle, color: Colors.green),
          label: const Text('Buscar y agregar producto'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.green,
            minimumSize: const Size.fromHeight(48),
          ),
        ),
        const SizedBox(height: 4),
        if (_items.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('Aún no has agregado productos.'),
          ),
        if (_items.isNotEmpty) ...[
          const Divider(),
          const Text('Productos agregados',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          ...List.generate(_items.length, (index) {
            final item = _items[index];
            return ListTile(
              dense: true,
              title: Text(item.productName),
              subtitle: Text('${_qty(item.quantity)} x ${_money(item.unitPrice)} = ${_money(item.subtotal)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 20),
                    onPressed: () => _editItemQuantity(index),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: () => setState(() => _items.removeAt(index)),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildConfirmStep(String companyName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _confirmRow('Cede', companyName),
                _confirmRow('Empleado', _employee?.name ?? '-'),
                _confirmRow('Cédula', _employee?.identification ?? '-'),
                _confirmRow('Fecha', DateFormat('dd/MM/yyyy').format(_date)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Productos', style: TextStyle(fontWeight: FontWeight.bold)),
        ..._items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(item.productName)),
                  Text('${_qty(item.quantity)} x ${_money(item.unitPrice)}'),
                  const SizedBox(width: 8),
                  Text(_money(item.subtotal),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            )),
        const Divider(),
        TextField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Notas (opcional)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Total: ${_money(_total)}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ),
      ],
    );
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

String _money(double value) => formatMoney(value);

String _qty(double value) => formatQty(value);