import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/daily_list.dart';
import '../models/product.dart';

class PrintShareScreen extends StatelessWidget {
  final DailyList dailyList;

  const PrintShareScreen({super.key, required this.dailyList});

  String get formattedDate => DateFormat('dd/MM/yyyy').format(dailyList.listDate);

  List<DailyListItem> get _verduras =>
      dailyList.items.where((i) => i.product?.category == 'verdura').toList();

  List<DailyListItem> get _frutas =>
      dailyList.items.where((i) => i.product?.category == 'fruta').toList();

  String _quantityLabel(DailyListItem item) {
    final quantity = item.quantityToBring;
    if (quantity == null || quantity.isEmpty || quantity == '0') {
      return 'sin cantidad asignada';
    }
    return quantity;
  }

  String _buildText() {
    final buffer = StringBuffer();
    buffer.writeln('Fruteria El Trebol');
    buffer.writeln('Lista del dia: $formattedDate');
    if (dailyList.notes != null && dailyList.notes!.isNotEmpty) {
      buffer.writeln('Notas: ${dailyList.notes}');
    }
    buffer.writeln('');

    buffer.writeln('=== VERDURAS ===');
    for (final item in _verduras) {
      buffer.writeln('${item.product?.name ?? "Producto ${item.productId}"}: ${item.hay} | ${item.action} | Traer: ${_quantityLabel(item)}');
    }

    buffer.writeln('');
    buffer.writeln('=== FRUTAS ===');
    for (final item in _frutas) {
      buffer.writeln('${item.product?.name ?? "Producto ${item.productId}"}: ${item.hay} | ${item.action} | Traer: ${_quantityLabel(item)}');
    }

    return buffer.toString();
  }

  Future<void> _shareText() async {
    await Share.share(_buildText(), subject: 'Lista El Trebol $formattedDate');
  }

  Future<void> _sendWhatsApp() async {
    final text = Uri.encodeComponent(_buildText());
    final url = Uri.parse('whatsapp://send?text=$text');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      final webUrl = Uri.parse('https://wa.me/?text=$text');
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: _buildText()));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Texto copiado al portapapeles')),
      );
    }
  }

  Future<void> _print(BuildContext context) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'Fruteria El Trebol',
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Center(child: pw.Text('Lista del dia: $formattedDate')),
              if (dailyList.notes != null && dailyList.notes!.isNotEmpty)
                pw.Text('Notas: ${dailyList.notes}'),
              pw.SizedBox(height: 16),
              pw.Text('VERDURAS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              ..._verduras.map((item) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(child: pw.Text(item.product?.name ?? 'Producto ${item.productId}')),
                      pw.Text(item.hay.isEmpty ? '-' : item.hay),
                      pw.SizedBox(width: 16),
                      pw.Text(item.action),
                      pw.SizedBox(width: 16),
                      pw.Text(_quantityLabel(item)),
                    ],
                  )),
              pw.SizedBox(height: 16),
              pw.Text('FRUTAS', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              ..._frutas.map((item) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(child: pw.Text(item.product?.name ?? 'Producto ${item.productId}')),
                      pw.Text(item.hay.isEmpty ? '-' : item.hay),
                      pw.SizedBox(width: 16),
                      pw.Text(item.action),
                      pw.SizedBox(width: 16),
                      pw.Text(_quantityLabel(item)),
                    ],
                  )),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'lista_el_trebol_$formattedDate.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lista del $formattedDate'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection('VERDURAS', _verduras),
                    const SizedBox(height: 24),
                    _buildSection('FRUTAS', _frutas),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => _print(context),
              icon: const Icon(Icons.print),
              label: const Text('Imprimir lista'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _shareText,
              icon: const Icon(Icons.share),
              label: const Text('Compartir texto'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _sendWhatsApp,
              icon: const Icon(Icons.message),
              label: const Text('Enviar por WhatsApp'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => _copyToClipboard(context),
              icon: const Icon(Icons.copy),
              label: const Text('Copiar al portapapeles'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<DailyListItem> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const Divider(),
            ...items.map((item) => ListTile(
                  dense: true,
                  title: Text(item.product?.name ?? 'Producto ${item.productId}'),
                  subtitle: Text(
                    item.hay.isEmpty
                        ? 'Traer: ${_quantityLabel(item)}'
                        : 'Hay: ${item.hay} | Traer: ${_quantityLabel(item)}',
                  ),
                  trailing: Chip(
                    label: Text(item.action),
                    backgroundColor: _actionColor(item.action),
                  ),
                )),
          ],
        ),
      ),
    );
  }

  Color _actionColor(String action) {
    switch (action.toLowerCase()) {
      case 'traer':
        return Colors.orange.shade100;
      case 'opcional':
        return Colors.blue.shade100;
      default:
        return Colors.grey.shade200;
    }
  }
}
