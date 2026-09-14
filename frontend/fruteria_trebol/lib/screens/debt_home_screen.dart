import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/company.dart';
import '../models/debt.dart';
import '../providers/debt_provider.dart';
import 'debt_detail_screen.dart';
import 'debt_report_screen.dart';
import 'new_debt_screen.dart';

class DebtHomeScreen extends StatefulWidget {
  const DebtHomeScreen({super.key});

  @override
  State<DebtHomeScreen> createState() => _DebtHomeScreenState();
}

class _DebtHomeScreenState extends State<DebtHomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    final provider = context.read<DebtProvider>();
    await provider.init();
    if (provider.selectedCompany == null) {
      await provider.loadCompanies();
    } else {
      await provider.loadDebtors(search: _searchController.text);
    }
  }

  Future<void> _selectCompany(Company company) async {
    final provider = context.read<DebtProvider>();
    await provider.selectCompany(company);
    await provider.loadDebtors(search: _searchController.text);
  }

  Future<void> _changeCompany() async {
    final provider = context.read<DebtProvider>();
    if (provider.companies.isEmpty) {
      await provider.loadCompanies();
    }
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Selecciona la cede',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            ...provider.companies.map((c) => ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(c.name),
                  trailing: provider.selectedCompany?.id == c.id
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                  onTap: () {
                    Navigator.pop(context);
                    _selectCompany(c);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _openReport() {
    final provider = context.read<DebtProvider>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DebtReportScreen.listing(
          companyName: provider.selectedCompany?.name ?? '',
          listing: provider.debtors,
        ),
      ),
    );
  }

  Future<void> _openNewDebt() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NewDebtScreen()),
    );
    if (mounted) {
      await context.read<DebtProvider>().loadDebtors(search: _searchController.text);
    }
  }

  Future<void> _openDetail(DebtorSummary debtor) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DebtDetailScreen(employee: debtor.employee),
      ),
    );
    if (mounted) {
      await context.read<DebtProvider>().loadDebtors(search: _searchController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Deudas de empleados'),
            if (provider.selectedCompany != null)
              Text(provider.selectedCompany!.name,
                  style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.store),
            tooltip: 'Cambiar cede',
            onPressed: _changeCompany,
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Exportar listado',
            onPressed: provider.debtors.isEmpty ? null : _openReport,
          ),
        ],
      ),
      body: provider.selectedCompany == null
          ? _buildCompanyPicker(provider)
          : _buildDebtors(provider),
      floatingActionButton: provider.selectedCompany == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _openNewDebt,
              icon: const Icon(Icons.add),
              label: const Text('Nueva deuda'),
              backgroundColor: Colors.green.shade700,
              foregroundColor: Colors.white,
            ),
    );
  }

  Widget _buildCompanyPicker(DebtProvider provider) {
    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: ${provider.error}', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => provider.loadCompanies(),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (provider.companies.isEmpty) {
      return const Center(child: Text('No hay cedes disponibles en Odoo.'));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Selecciona la cede para continuar',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...provider.companies.map((c) => Card(
              child: ListTile(
                leading: const Icon(Icons.store, color: Colors.green),
                title: Text(c.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectCompany(c),
              ),
            )),
      ],
    );
  }

  Widget _buildDebtors(DebtProvider provider) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchController,
            onSubmitted: (value) => provider.loadDebtors(search: value),
            decoration: InputDecoration(
              labelText: 'Buscar deudor',
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
              suffixIcon: IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  provider.loadDebtors();
                },
              ),
            ),
          ),
        ),
        Expanded(
          child: provider.loading && provider.debtors.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : provider.error != null && provider.debtors.isEmpty
                  ? Center(child: Text('Error: ${provider.error}'))
                  : RefreshIndicator(
                      onRefresh: () => provider.loadDebtors(search: _searchController.text),
                      child: provider.debtors.isEmpty
                          ? ListView(
                              children: const [
                                SizedBox(height: 120),
                                Center(child: Text('No hay deudores con saldo pendiente.')),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 90),
                              itemCount: provider.debtors.length,
                              itemBuilder: (context, index) {
                                final debtor = provider.debtors[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.green.shade700,
                                      foregroundColor: Colors.white,
                                      child: Text(
                                        debtor.employee.name.isNotEmpty
                                            ? debtor.employee.name[0].toUpperCase()
                                            : '?',
                                      ),
                                    ),
                                    title: Text(debtor.employee.name),
                                    subtitle: Text(
                                      [
                                        if (debtor.employee.identification != null)
                                          debtor.employee.identification!,
                                        if (debtor.employee.jobTitle != null)
                                          debtor.employee.jobTitle!,
                                      ].join(' • '),
                                    ),
                                    trailing: Text(
                                      _money(debtor.balance),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, color: Colors.red),
                                    ),
                                    onTap: () => _openDetail(debtor),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }
}

String _money(double value) =>
    NumberFormat.currency(locale: 'es', symbol: 'Bs ', decimalDigits: 2).format(value);