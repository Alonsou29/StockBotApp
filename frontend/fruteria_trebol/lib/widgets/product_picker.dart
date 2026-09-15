import 'package:flutter/material.dart';

import '../models/debt.dart';
import '../models/odoo_product.dart';
import '../services/api_service.dart';
import '../utils/format.dart';

class ProductPickerDialog extends StatefulWidget {
  final int? companyId;

  const ProductPickerDialog({super.key, this.companyId});

  @override
  State<ProductPickerDialog> createState() => _ProductPickerDialogState();
}

class _ProductPickerDialogState extends State<ProductPickerDialog> {
  static const int _perPage = 5;

  final TextEditingController _searchController = TextEditingController();

  List<OdooProduct> _results = [];
  bool _searching = false;
  int _page = 0;

  int get _totalPages {
    final pages = (_results.length / _perPage).ceil();
    return pages < 1 ? 1 : pages;
  }

  List<OdooProduct> get _visible {
    final start = _page * _perPage;
    if (start >= _results.length) return const [];
    final end = (start + _perPage).clamp(0, _results.length);
    return _results.sublist(start, end);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _search());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    setState(() {
      _searching = true;
      _page = 0;
    });
    try {
      final results = await ApiService.fetchOdooProducts(
        companyId: widget.companyId,
        search: query.isEmpty ? null : query,
      );
      if (mounted) {
        setState(() {
          _results = results;
          _page = 0;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error buscando productos: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _goToPage(int page) {
    final target = page < 0 ? 0 : (page > _totalPages - 1 ? _totalPages - 1 : page);
    setState(() => _page = target);
  }

  Future<void> _pick(OdooProduct product) async {
    final controller = TextEditingController(text: '1');
    final qty = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(product.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Precio: ${formatMoney(product.listPrice)}'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
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
              final value =
                  double.tryParse(controller.text.replaceAll(',', '.'));
              Navigator.pop(context, value);
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (qty == null || qty <= 0) return;
    if (!mounted) return;
    Navigator.pop(
      context,
      DebtItem(
        odooProductId: product.id,
        productName: product.name,
        productCode: product.code,
        unitPrice: product.listPrice,
        quantity: qty,
        subtotal: double.parse((product.listPrice * qty).toStringAsFixed(2)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar producto'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              onSubmitted: (_) => _search(),
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Buscar en Odoo',
                border: const OutlineInputBorder(),
                isDense: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_searching)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_results.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: Text('Sin resultados')),
              )
            else ...[
              SizedBox(
                height: 200,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _visible.length,
                  itemBuilder: (context, index) {
                    final product = _visible[index];
                    return ListTile(
                      dense: true,
                      title: Text(product.name),
                      subtitle: Text(formatMoney(product.listPrice)),
                      trailing: const Icon(Icons.add_circle, color: Colors.green),
                      onTap: () => _pick(product),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _page > 0 ? () => _goToPage(_page - 1) : null,
                  ),
                  Text('Página ${_page + 1} de $_totalPages'),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _page < _totalPages - 1
                        ? () => _goToPage(_page + 1)
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}