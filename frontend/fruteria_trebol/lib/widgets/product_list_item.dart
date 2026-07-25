import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/product.dart';
import '../models/daily_list.dart';

class ProductListItem extends StatefulWidget {
  final Product product;
  final DailyListItem item;
  final void Function(String hay, String action, String? quantityToBring) onChanged;

  const ProductListItem({
    super.key,
    required this.product,
    required this.item,
    required this.onChanged,
  });

  @override
  State<ProductListItem> createState() => _ProductListItemState();
}

class _ProductListItemState extends State<ProductListItem> {
  static const List<String> _actions = ['NO', 'traer', 'OPCIONAL'];
  late final TextEditingController _hayController;
  late final FocusNode _hayFocus;
  late final TextEditingController _quantityController;
  late final FocusNode _quantityFocus;

  @override
  void initState() {
    super.initState();
    _hayController = TextEditingController(text: widget.item.hay);
    _hayFocus = FocusNode();
    _quantityController = TextEditingController(text: widget.item.quantityToBring ?? '');
    _quantityFocus = FocusNode();
  }

  @override
  void didUpdateWidget(covariant ProductListItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.hay != _hayController.text && !_hayFocus.hasFocus) {
      _hayController.text = widget.item.hay;
    }
    if ((widget.item.quantityToBring ?? '') != _quantityController.text && !_quantityFocus.hasFocus) {
      _quantityController.text = widget.item.quantityToBring ?? '';
    }
  }

  @override
  void dispose() {
    _hayController.dispose();
    _hayFocus.dispose();
    _quantityController.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }

  void _notifyChange({String? action}) {
    widget.onChanged(
      _hayController.text,
      action ?? widget.item.action,
      _quantityController.text.isEmpty ? null : _quantityController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.product.name,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _hayController,
                      focusNode: _hayFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Hay',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _notifyChange(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _quantityController,
                      focusNode: _quantityFocus,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Cant. a traer',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => _notifyChange(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      value: _actions.contains(widget.item.action) ? widget.item.action : 'NO',
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: _actions
                          .map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12))))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          _notifyChange(action: value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
