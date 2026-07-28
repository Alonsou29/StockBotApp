import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/daily_list.dart';
import '../constants/print_order.dart';

class PrintShareScreen extends StatelessWidget {
  final DailyList dailyList;

  const PrintShareScreen({super.key, required this.dailyList});

  String get formattedDate => DateFormat('dd/MM/yyyy').format(dailyList.listDate);

  List<DailyListItem> get _verduras {
    final items = dailyList.items.where((i) => i.product?.category == 'verdura').toList();
    items.sort((a, b) => compareByPrintOrder(
          a.product?.name ?? '',
          b.product?.name ?? '',
        ));
    return items;
  }

  List<DailyListItem> get _frutas {
    final items = dailyList.items.where((i) => i.product?.category == 'fruta').toList();
    items.sort((a, b) => compareByPrintOrder(
          a.product?.name ?? '',
          b.product?.name ?? '',
        ));
    return items;
  }

  String _quantityLabel(DailyListItem item) {
    final quantity = item.quantityToBring;
    if (quantity == null || quantity.isEmpty || quantity == '0') {
      return 'sin cantidad asignada';
    }
    return quantity;
  }

  String _formatHay(String hay) {
    final trimmed = hay.trim();
    return trimmed.isEmpty ? '-' : trimmed;
  }

  String _formatTraer(DailyListItem item) {
    final action = item.action.trim().toLowerCase();
    final quantity = item.quantityToBring?.trim() ?? '';
    if (action == 'traer') {
      return quantity.isEmpty ? 'SI' : quantity;
    }
    if (action == 'no') return 'NO';
    if (action == 'opcional') return 'OPCIONAL';
    return item.action;
  }

  String _buildText() {
    final buffer = StringBuffer();
    buffer.writeln('Fruteria El Trebol');
    buffer.writeln('Lista del dia: $formattedDate');
    if (dailyList.notes != null && dailyList.notes!.isNotEmpty) {
      buffer.writeln('Notas: ${dailyList.notes}');
    }
    buffer.writeln('');
    buffer.writeln('VERDURA            HAY    TRAER      FRUTAS             HAY    TRAER');
    buffer.writeln('---------------------------------------------------------------');

    final maxRows = _verduras.length > _frutas.length ? _verduras.length : _frutas.length;
    for (var i = 0; i < maxRows; i++) {
      final v = i < _verduras.length ? _verduras[i] : null;
      final f = i < _frutas.length ? _frutas[i] : null;

      String leftCol;
      if (v == null) {
        leftCol = '${' '.padRight(18)}${' '.padRight(6)}${' '.padRight(10)}';
      } else {
        final name = displayProductName(v.product?.name ?? 'Producto ${v.productId}').padRight(18);
        final hay = _formatHay(v.hay).padRight(6);
        final traer = _formatTraer(v).padRight(10);
        leftCol = '$name$hay$traer';
      }

      String rightCol;
      if (f == null) {
        rightCol = '';
      } else {
        final name = displayProductName(f.product?.name ?? 'Producto ${f.productId}').padRight(18);
        final hay = _formatHay(f.hay).padRight(6);
        final traer = _formatTraer(f).padRight(10);
        rightCol = '$name$hay$traer';
      }

      buffer.writeln('$leftCol$rightCol'.trimRight());
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
    final pdf = pw.Document(compress: true);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(16),
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Text(
              'Fruteria El Trebol',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Center(
            child: pw.Text(
              'Lista del dia: $formattedDate',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          if (dailyList.notes != null && dailyList.notes!.isNotEmpty)
            pw.Text('Notas: ${dailyList.notes}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 6),
          _buildPrintTable(),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'lista_el_trebol_$formattedDate.pdf',
    );
  }

  pw.Widget _buildPrintTable() {
    final headerStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
    const cellStyle = pw.TextStyle(fontSize: 9);

    pw.Widget cell(String text, pw.TextStyle style, {pw.TextAlign align = pw.TextAlign.left}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        child: pw.Text(text, style: style, textAlign: align),
      );
    }

    final rows = <pw.TableRow>[
      pw.TableRow(
        children: [
          cell('VERDURA', headerStyle),
          cell('HAY', headerStyle, align: pw.TextAlign.center),
          cell('TRAER', headerStyle, align: pw.TextAlign.center),
          cell('FRUTAS', headerStyle),
          cell('HAY', headerStyle, align: pw.TextAlign.center),
          cell('TRAER', headerStyle, align: pw.TextAlign.center),
        ],
      ),
    ];

    final maxRows = _verduras.length > _frutas.length ? _verduras.length : _frutas.length;
    for (var i = 0; i < maxRows; i++) {
      final v = i < _verduras.length ? _verduras[i] : null;
      final f = i < _frutas.length ? _frutas[i] : null;
      rows.add(
        pw.TableRow(
          children: [
            cell(v != null ? displayProductName(v.product?.name ?? 'Producto ${v.productId}') : '', cellStyle),
            cell(v != null ? _formatHay(v.hay) : '', cellStyle, align: pw.TextAlign.center),
            cell(v != null ? _formatTraer(v) : '', cellStyle, align: pw.TextAlign.center),
            cell(f != null ? displayProductName(f.product?.name ?? 'Producto ${f.productId}') : '', cellStyle),
            cell(f != null ? _formatHay(f.hay) : '', cellStyle, align: pw.TextAlign.center),
            cell(f != null ? _formatTraer(f) : '', cellStyle, align: pw.TextAlign.center),
          ],
        ),
      );
    }

    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(3),
        1: const pw.FlexColumnWidth(1),
        2: const pw.FlexColumnWidth(1),
        3: const pw.FlexColumnWidth(3),
        4: const pw.FlexColumnWidth(1),
        5: const pw.FlexColumnWidth(1),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: rows,
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
