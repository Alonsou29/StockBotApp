import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/debt.dart';
import '../utils/format.dart';

class DebtReportScreen extends StatefulWidget {
  final String companyName;
  final Debt? receipt;
  final List<DebtorSummary>? listing;

  const DebtReportScreen.receipt({
    super.key,
    required this.companyName,
    required Debt this.receipt,
  }) : listing = null;

  const DebtReportScreen.listing({
    super.key,
    required this.companyName,
    required List<DebtorSummary> this.listing,
  }) : receipt = null;

  @override
  State<DebtReportScreen> createState() => _DebtReportScreenState();
}

class _DebtReportScreenState extends State<DebtReportScreen> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _busy = false;

  bool get _isReceipt => widget.receipt != null;

  String get _title => _isReceipt ? 'Comprobante de deuda' : 'Listado de deudores';

  double get _listingTotal =>
      (widget.listing ?? []).fold(0.0, (sum, e) => sum + e.balance);

  Future<void> _sharePdf() async {
    await _run(() async {
      final bytes = await _buildPdf();
      await Printing.sharePdf(bytes: bytes, filename: '$_fileBase.pdf');
    });
  }

  Future<void> _print() async {
    await _run(() async {
      final bytes = await _buildPdf();
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: '$_fileBase.pdf',
      );
    });
  }

  Future<void> _shareImage() async {
    await _run(() async {
      final boundary =
          _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      await Share.shareXFiles(
        [XFile.fromData(bytes, mimeType: 'image/png', name: '$_fileBase.png')],
        subject: _title,
      );
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _fileBase {
    if (_isReceipt) {
      final name = widget.receipt!.employee?.name ?? 'empleado';
      return 'deuda_${name.replaceAll(' ', '_').toLowerCase()}';
    }
    return 'deudores_${_dateStr(DateTime.now()).replaceAll('/', '-')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: RepaintBoundary(
                key: _boundaryKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: _buildReportBody(),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _sharePdf,
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Compartir PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _busy ? null : _shareImage,
                          icon: const Icon(Icons.image),
                          label: const Text('Compartir imagen'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade500,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _print,
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimir'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                  if (_busy) const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        if (_isReceipt) _buildReceiptContent() else _buildListingContent(),
        const SizedBox(height: 16),
        Text(
          'Generado el ${_dateStr(DateTime.now())} a las ${_timeStr(DateTime.now())}',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Frutería El Trébol',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green),
        ),
        const SizedBox(height: 2),
        Text('Cede: ${widget.companyName}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
        Text(_title, style: const TextStyle(fontSize: 13)),
        const Divider(),
      ],
    );
  }

  Widget _buildReceiptContent() {
    final debt = widget.receipt!;
    final employee = debt.employee;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoRow('Empleado', employee?.name ?? '-'),
        _infoRow('Cédula', employee?.identification ?? '-'),
        _infoRow('Cargo', employee?.jobTitle ?? '-'),
        _infoRow('Fecha', debt.debtDate != null ? _dateStr(debt.debtDate!) : '-'),
        if (debt.notes != null && debt.notes!.isNotEmpty)
          _infoRow('Notas', debt.notes!),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(border: Border.all(width: 0.5)),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(4),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(2),
            },
            border: TableBorder.all(width: 0.5),
            children: [
              _tableHeader(['Producto', 'Cant.', 'P. Unit', 'Subtotal']),
              ...debt.items.map((item) => TableRow(children: [
                    _cell(item.productName),
                    _cell(_qty(item.quantity), align: TextAlign.center),
                    _cell(_money(item.unitPrice), align: TextAlign.right),
                    _cell(_money(item.subtotal), align: TextAlign.right),
                  ])),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Total: ${_money(debt.total)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ),
      ],
    );
  }

  Widget _buildListingContent() {
    final debtors = widget.listing ?? [];
    if (debtors.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('No hay deudores con saldo pendiente.'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(border: Border.all(width: 0.5)),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(2),
              2: FlexColumnWidth(2),
            },
            border: TableBorder.all(width: 0.5),
            children: [
              _tableHeader(['Empleado', 'Cargo', 'Saldo']),
              ...debtors.map((d) => TableRow(children: [
                    _cell('${d.employee.name}\n${d.employee.identification ?? ''}'.trim()),
                    _cell(_money(d.totalCharged), align: TextAlign.right),
                    _cell(_money(d.balance), align: TextAlign.right),
                  ])),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Total adeudado: ${_money(_listingTotal)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  TableRow _tableHeader(List<String> labels) {
    return TableRow(
      decoration: BoxDecoration(color: Colors.green.shade100),
      children: labels
          .map((label) => _cell(label,
              bold: true,
              align: label == 'Producto' || label == 'Empleado'
                  ? TextAlign.left
                  : TextAlign.center))
          .toList(),
    );
  }

  Widget _cell(String text, {bool bold = false, TextAlign align = TextAlign.left}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      child: Text(
        text,
        textAlign: align,
        style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
      ),
    );
  }

  // --------------------------
  // PDF
  // --------------------------
  Future<Uint8List> _buildPdf() async {
    final pdf = pw.Document(compress: true);
    final headerStyle = pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold);
    const cellStyle = pw.TextStyle(fontSize: 9);

    pw.Widget cell(String text,
        {pw.TextStyle style = cellStyle, pw.TextAlign align = pw.TextAlign.left}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(text, style: style, textAlign: align),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Text('Frutería El Trébol',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 2),
          pw.Center(child: pw.Text('Cede: ${widget.companyName}', style: cellStyle)),
          pw.Center(child: pw.Text(_title, style: cellStyle)),
          pw.Divider(),
          if (_isReceipt) ...[
            pw.Text('Empleado: ${widget.receipt!.employee?.name ?? '-'}', style: cellStyle),
            pw.Text('Cédula: ${widget.receipt!.employee?.identification ?? '-'}', style: cellStyle),
            pw.Text('Cargo: ${widget.receipt!.employee?.jobTitle ?? '-'}', style: cellStyle),
            pw.Text(
              'Fecha: ${widget.receipt!.debtDate != null ? _dateStr(widget.receipt!.debtDate!) : '-'}',
              style: cellStyle,
            ),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(2),
                3: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(children: [
                  cell('Producto', style: headerStyle),
                  cell('Cant.', style: headerStyle, align: pw.TextAlign.center),
                  cell('P. Unit', style: headerStyle, align: pw.TextAlign.right),
                  cell('Subtotal', style: headerStyle, align: pw.TextAlign.right),
                ]),
                ...widget.receipt!.items.map((item) => pw.TableRow(children: [
                      cell(item.productName),
                      cell(_qty(item.quantity), align: pw.TextAlign.center),
                      cell(_money(item.unitPrice), align: pw.TextAlign.right),
                      cell(_money(item.subtotal), align: pw.TextAlign.right),
                    ])),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total: ${_money(widget.receipt!.total)}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ),
          ] else ...[
            pw.Table(
              border: pw.TableBorder.all(width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(4),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(2),
              },
              children: [
                pw.TableRow(children: [
                  cell('Empleado', style: headerStyle),
                  cell('Cargos', style: headerStyle, align: pw.TextAlign.right),
                  cell('Saldo', style: headerStyle, align: pw.TextAlign.right),
                ]),
                ...(widget.listing ?? []).map((d) => pw.TableRow(children: [
                      cell('${d.employee.name} ${d.employee.identification ?? ''}'.trim()),
                      cell(_money(d.totalCharged), align: pw.TextAlign.right),
                      cell(_money(d.balance), align: pw.TextAlign.right),
                    ])),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('Total adeudado: ${_money(_listingTotal)}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ),
          ],
          pw.SizedBox(height: 12),
          pw.Text(
            'Generado el ${_dateStr(DateTime.now())} a las ${_timeStr(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return pdf.save();
  }
}

String _money(double value) {
  return formatMoney(value);
}

String _qty(double value) {
  return formatQty(value);
}

String _dateStr(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

String _timeStr(DateTime date) => DateFormat('hh:mm a').format(date);