import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/daily_list_provider.dart';
import '../widgets/product_list_item.dart';
import 'print_share_screen.dart';

class DailyListScreen extends StatefulWidget {
  const DailyListScreen({super.key});

  @override
  State<DailyListScreen> createState() => _DailyListScreenState();
}

class _DailyListScreenState extends State<DailyListScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final provider = context.read<DailyListProvider>();
    await provider.loadProducts();
    await provider.loadDailyListForDate(_selectedDate);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await context.read<DailyListProvider>().loadDailyListForDate(picked);
    }
  }

  Future<void> _save() async {
    final provider = context.read<DailyListProvider>();
    try {
      await provider.saveDailyList();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lista guardada exitosamente')),
        );
        if (provider.currentList != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PrintShareScreen(dailyList: provider.currentList!),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DailyListProvider>();
    final dateLabel = DateFormat('dd/MM/yyyy').format(_selectedDate);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Lista del $dateLabel'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(text: 'VERDURAS'),
              Tab(text: 'FRUTAS'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.calendar_today),
              onPressed: _pickDate,
            ),
          ],
        ),
        body: provider.loading && provider.currentList == null
            ? const Center(child: CircularProgressIndicator())
            : provider.error != null && provider.currentList == null
                ? Center(child: Text('Error: ${provider.error}'))
                : TabBarView(
                    children: [
                      _buildCategoryList(provider, 'verdura'),
                      _buildCategoryList(provider, 'fruta'),
                    ],
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: provider.loading ? null : _save,
          icon: provider.loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.save),
          label: Text(provider.loading ? 'Guardando...' : 'Guardar'),
          backgroundColor: Colors.green.shade700,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCategoryList(DailyListProvider provider, String category) {
    final products = provider.products.where((p) => p.category == category).toList();
    if (provider.currentList == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        final item = provider.currentList!.items.firstWhere((i) => i.productId == product.id);
        return ProductListItem(
          product: product,
          item: item,
          onChanged: (hay, action, quantityToBring) => provider.updateItem(
            product.id,
            hay: hay,
            action: action,
            quantityToBring: quantityToBring,
          ),
        );
      },
    );
  }
}
