import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/models.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:simple_sale/core/utils/formatter.dart';

class PrintService {
  static String _clean(String text) {
    if (text == null) return '';
    
    // Transliteration map for Cyrillic (Russian + Uzbek)
    const cyrillicToLatin = {
      'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo', 'ж': 'zh',
      'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm', 'н': 'n', 'о': 'o',
      'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u', 'ф': 'f', 'х': 'kh', 'ц': 'ts',
      'ч': 'ch', 'ш': 'sh', 'щ': 'shch', 'ъ': '', 'ы': 'y', 'ь': "'", 'э': 'e', 'ю': 'yu', 'я': 'ya',
      'А': 'A', 'Б': 'B', 'В': 'V', 'Г': 'G', 'Д': 'D', 'Е': 'E', 'Ё': 'Yo', 'Ж': 'Zh',
      'З': 'Z', 'И': 'I', 'Й': 'Y', 'К': 'K', 'Л': 'L', 'М': 'M', 'Н': 'N', 'О': 'O',
      'П': 'P', 'Р': 'R', 'С': 'S', 'Т': 'T', 'У': 'U', 'Ф': 'F', 'Х': 'Kh', 'Ц': 'Ts',
      'Ч': 'Ch', 'Ш': 'Sh', 'Щ': 'Shch', 'Ъ': '', 'Ы': 'Y', 'Ь': "'", 'Э': 'E', 'Ю': 'Yu', 'Я': 'Ya',
      'ў': "o'", 'қ': 'q', 'ғ': "g'", 'ҳ': 'h',
      'Ў': "O'", 'Қ': 'Q', 'Ғ': "G'", 'Ҳ': 'H',
    };

    String result = text;
    
    // Apply transliteration
    cyrillicToLatin.forEach((cyr, lat) {
      result = result.replaceAll(cyr, lat);
    });

    return result
        .replaceAll('\u00A0', ' ') // Non-breaking space
        .replaceAll('\u202F', ' ') // Narrow non-breaking space
        .replaceAll('ʻ', "'")      // Uzbek modifier
        .replaceAll('ʼ', "'")      // Uzbek modifier
        .replaceAll('‘', "'")      // Left single quote
        .replaceAll('’', "'")      // Right single quote
        .replaceAll('`', "'")
        .replaceAll('´', "'")
        .replaceAll('«', '"')
        .replaceAll('»', '"')
        .split('')
        .where((char) => char.codeUnitAt(0) < 128) // Only ASCII remains after transliteration
        .join('');
  }

  static Future<void> printBarcodeLabels({
    required List<Map<String, dynamic>> items, // [{'product': Product, 'quantity': int}]
    String? printerName,
    String? ipAddress,
    bool isPriceLabel = false,
    int width = 0, // 0 means default 40x30
  }) async {
    final doc = pw.Document();

    final double labelWidth = width > 0 ? width.toDouble() : 40.0;
    final double labelHeight = width > 58 ? 45.0 : 30.0;
    
    final labelFormat = PdfPageFormat(
      labelWidth * PdfPageFormat.mm,
      labelHeight * PdfPageFormat.mm,
      marginAll: 0,
    );

    final double scale = labelWidth / 40.0;

    for (var item in items) {
      final Product product = item['product'];
      final int quantity = item['quantity'] ?? 1;

      for (int i = 0; i < quantity; i++) {
        doc.addPage(
          pw.Page(
            pageFormat: labelFormat,
            build: (pw.Context context) {
              return pw.Container(
                alignment: pw.Alignment.center,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Text(
                      product.name.toUpperCase(),
                      style: pw.TextStyle(fontSize: 8 * scale, fontWeight: pw.FontWeight.bold),
                      maxLines: 2,
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: (isPriceLabel ? 4 : 2) * scale),
                    if (isPriceLabel) ...[
                      pw.Text(
                        'NARXI:',
                        style: pw.TextStyle(fontSize: 8 * scale, fontWeight: pw.FontWeight.normal),
                      ),
                      pw.SizedBox(height: 2 * scale),
                      pw.Text(
                        NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(product.price),
                        style: pw.TextStyle(fontSize: 22 * scale, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        'so\'m',
                        style: pw.TextStyle(fontSize: 10 * scale, fontWeight: pw.FontWeight.bold),
                      ),
                    ] else ...[
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.code128(),
                        data: product.barcode,
                        width: (labelWidth - 6) * PdfPageFormat.mm,
                        height: (12 * scale) * PdfPageFormat.mm,
                        drawText: true,
                        textStyle: pw.TextStyle(fontSize: 8 * scale, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 2 * scale),
                      pw.Text(
                        'Narxi: ${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(product.price)} so\'m',
                        style: pw.TextStyle(fontSize: 9 * scale, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      }
    }

    if (printerName != null && printerName != 'Network') {
      final printers = await Printing.listPrinters();
      if (printers.isNotEmpty) {
        final printer = printers.firstWhere(
          (p) => p.name == printerName,
          orElse: () => printers.first,
        );
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (format) => doc.save(),
        );
      }
    } else if (printerName == null && (ipAddress == null || ipAddress.isEmpty)) {
      await Printing.layoutPdf(onLayout: (format) => doc.save());
    }

    if (ipAddress != null && ipAddress.isNotEmpty) {
      try {
        final socket = await Socket.connect(ipAddress, 9100, timeout: const Duration(seconds: 3));
        List<int> bytes = [];
        
        // Init
        bytes.addAll([0x1B, 0x40]);
        
        for (var item in items) {
          final Product product = item['product'];
          final int quantity = item['quantity'] ?? 1;
          
          for (int i = 0; i < quantity; i++) {
            // center
            bytes.addAll([0x1B, 0x61, 0x01]);
            
            // Vertical offset
            bytes.addAll([0x0A]); 
            
            // Name
            bytes.addAll(utf8.encode(_clean('${product.name.toUpperCase()}\n')));
            
            if (isPriceLabel) {
               // Large Price
               bytes.addAll([0x1D, 0x21, width > 58 ? 0x22 : 0x11]); // triple or double size
               bytes.addAll(utf8.encode(_clean('\n${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(product.price)} so\'m\n')));
               bytes.addAll([0x1D, 0x21, 0x00]); // normal size
            } else {
              // Barcode
              bytes.addAll([0x1D, 0x68, width > 58 ? 0x80 : 0x50]); 
              bytes.addAll([0x1D, 0x77, width > 58 ? 0x03 : 0x02]); 
              bytes.addAll([0x1D, 0x48, 0x02]); 
              bytes.addAll([0x1D, 0x6B, 0x49, product.barcode.length + 2, 0x7B, 0x42]); 
              bytes.addAll(utf8.encode(product.barcode));
              bytes.addAll(utf8.encode(_clean('\nNarxi: ${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(product.price)} so\'m\n')));
            }
            
            bytes.addAll([0x0A, 0x0A]);
          }
        }
        
        bytes.addAll([0x1D, 0x56, 0x42, 0x00]); // cut
        
        socket.add(bytes);
        await socket.flush();
        await socket.close();
      } catch (e) {
        debugPrint('IP Barcode Printer error: $e');
      }
    }
  }


  static Future<void> printBarcodeLabel({
    required Product product,
    String? printerName,
    String? ipAddress,
  }) async {
    await printBarcodeLabels(
      items: [{'product': product, 'quantity': 1}],
      printerName: printerName,
      ipAddress: ipAddress,
    );
  }

  static Future<void> printReceipt({
    required List<SaleItem> items,
    required double total,
    required String registerName,
    double discount = 0,
    String? printerName,
    String? ipAddress,
    String? orgName,
    String? orgAddress,
    String? instagram,
    int width = 80,
    String? footerText,
    bool showInstagram = true,
  }) async {
    final doc = pw.Document();
    final fmt = NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0);
    

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          width * PdfPageFormat.mm,
          double.infinity,
          marginAll: 0,
        ),
        build: (pw.Context context) {
          final double scale = width / 58;
          return pw.Padding(
            padding: const pw.EdgeInsets.symmetric(horizontal: 2, vertical: 10),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                pw.SizedBox(height: 5),
                pw.Text(
                  _clean((orgName ?? 'SIMPLE SALE').toUpperCase()),
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 10 * scale,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                if (orgAddress != null && orgAddress.isNotEmpty)
                  pw.Text(
                    _clean(orgAddress),
                    style: pw.TextStyle(fontSize: 7.5 * scale),
                    textAlign: pw.TextAlign.center,
                  ),
                pw.SizedBox(height: 5),
                pw.Divider(thickness: 0.5),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(_clean('Kassa: $registerName'), style: pw.TextStyle(fontSize: 7.5 * scale)),
                    pw.Text(
                      _clean('Sana: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}'),
                      style: pw.TextStyle(fontSize: 7.5 * scale),
                    ),
                  ],
                ),
                pw.Divider(thickness: 0.5),
              ...items.map(
                (item) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 3),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        _clean(item.productName.toUpperCase()),
                        style: pw.TextStyle(fontSize: 8 * scale, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            _clean('${AppFormatter.formatDouble(item.quantity)} x ${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(item.price)}'),
                            style: pw.TextStyle(fontSize: 8 * scale),
                          ),
                          pw.Text(
                            _clean(NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(item.quantity * item.price)),
                            style: pw.TextStyle(fontSize: 8.5 * scale, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              pw.Divider(thickness: 1),
              if (discount > 0) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(_clean('UMUMIY:'), style: pw.TextStyle(fontSize: 9 * scale)),
                    pw.Text(_clean('${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(total + discount)} s'), style: pw.TextStyle(fontSize: 9 * scale)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(_clean('CHEGIRMA:'), style: pw.TextStyle(fontSize: 9 * scale)),
                    pw.Text(_clean('-${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(discount)} s'), style: pw.TextStyle(fontSize: 9 * scale)),
                  ],
                ),
                pw.SizedBox(height: 2),
                pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
              ],
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    _clean('TO\'LANADIGAN:'),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10 * scale),
                  ),
                  pw.Text(
                    _clean('${fmt.format(total)} so\'m'),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11 * scale),
                  ),
                ],
              ),
              pw.SizedBox(height: 5 * scale),
              pw.Text(
                _clean(footerText ?? 'Xaridingiz uchun rahmat!'),
                style: pw.TextStyle(fontSize: 8 * scale, fontStyle: pw.FontStyle.italic),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 10),
              if (showInstagram && instagram != null && instagram.isNotEmpty) ...[
                pw.Divider(thickness: 0.5, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 5),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(12)),
                  ),
                  child: pw.Column(
                    children: [
                      pw.BarcodeWidget(
                        barcode: pw.Barcode.qrCode(),
                        data: 'https://instagram.com/$instagram',
                        width: 45 * scale,
                        height: 45 * scale,
                        color: PdfColors.black,
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        instagram.toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 9 * scale,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              pw.SizedBox(height: 30),
            ],
          ),
        );
      },
    ),
  );

    if (printerName != null && printerName != 'Network') {
      final printers = await Printing.listPrinters();
      if (printers.isNotEmpty) {
        final printer = printers.firstWhere(
          (p) => p.name == printerName,
          orElse: () => printers.first,
        );
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (format) => doc.save(),
        );
      }
    }

    if (ipAddress != null && ipAddress.isNotEmpty) {
      try {
        final socket = await Socket.connect(
          ipAddress,
          9100,
          timeout: const Duration(seconds: 3),
        );
        final commands = _generateEscPosCommands(
          items, 
          total, 
          registerName, 
          discount: discount,
          orgName: orgName, 
          orgAddress: orgAddress, 
          instagram: instagram,
          width: width,
          footerText: footerText,
          showInstagram: showInstagram,
        );
        socket.add(commands);
        await socket.flush();
        await socket.close();
      } catch (e) {
        print('IP Printer error: $e');
      }
    }
  }

  static List<int> _generateEscPosCommands(
    List<SaleItem> items,
    double total,
    String registerName, {
    double discount = 0,
    String? orgName,
    String? orgAddress,
    String? instagram,
    int width = 80,
    String? footerText,
    bool showInstagram = true,
  }) {
    List<int> bytes = [];
    int maxChars = width == 58 ? 32 : 42; // Safer 42 for 80mm to avoid cutoff
    String divider = (width == 58 ? '-' : '=') * maxChars;
    String thinDivider = '-' * maxChars;

    // init printer
    bytes.addAll([0x1B, 0x40]);

    // Chararacter set selection (optional, usually default works for latin)

    // Align center
    bytes.addAll([0x1B, 0x61, 0x01]);

    // Title
    bytes.addAll([0x1B, 0x45, 0x01]); // bold on
    bytes.addAll([0x1D, 0x21, 0x11]); // double size
    bytes.addAll(utf8.encode(_clean('${orgName ?? 'SIMPLE SALE'}\n')));
    bytes.addAll([0x1D, 0x21, 0x00]); // normal size
    bytes.addAll([0x1B, 0x45, 0x00]); // bold off
    
    if (orgAddress != null && orgAddress.isNotEmpty) {
      bytes.addAll(utf8.encode(_clean('$orgAddress\n')));
    }

    bytes.addAll([0x1B, 0x61, 0x00]); // Align left

    bytes.addAll(utf8.encode(_clean('$divider\n')));
    bytes.addAll(utf8.encode(_clean('Kassa: $registerName\n')));
    bytes.addAll(utf8.encode(_clean('Sana: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}\n')));
    bytes.addAll(utf8.encode('$divider\n\n'));

    for (var item in items) {
      // Product Name (Upper Case for clarity)
      bytes.addAll([0x1B, 0x45, 0x01]); // bold on for name
      bytes.addAll(utf8.encode(_clean('${item.productName.toUpperCase()}\n')));
      bytes.addAll([0x1B, 0x45, 0x00]); // bold off
      
      // Quantity x Price
      String qtyPrice = ' ${AppFormatter.formatDouble(item.quantity)} x ${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(item.price)}';
      // Item total (right side)
      String totalItem = NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(item.quantity * item.price);
      
      int spaces = maxChars - qtyPrice.length - totalItem.length;
      bytes.addAll(utf8.encode(_clean(qtyPrice + (' ' * (spaces > 0 ? spaces : 1)) + totalItem + '\n')));
    }

    bytes.addAll(utf8.encode('\n' + thinDivider + '\n'));
    
    if (discount > 0) {
      // Subtotal
      String subtotalLabel = 'UMUMIY:';
      String subtotalVal = '${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(total + discount)} s';
      int subSpaces = maxChars - subtotalLabel.length - subtotalVal.length;
      bytes.addAll(utf8.encode(_clean(subtotalLabel + (' ' * (subSpaces > 0 ? subSpaces : 1)) + subtotalVal + '\n')));
      
      // Discount
      String discountLabel = 'CHEGIRMA:';
      String discountVal = '-${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(discount)} s';
      int discSpaces = maxChars - discountLabel.length - discountVal.length;
      bytes.addAll(utf8.encode(_clean(discountLabel + (' ' * (discSpaces > 0 ? discSpaces : 1)) + discountVal + '\n')));
      
      bytes.addAll(utf8.encode('$divider\n'));
    }

    // Grand Total
    bytes.addAll([0x1B, 0x61, 0x01]); // Align center
    bytes.addAll([0x1B, 0x45, 0x01]); // bold on
    bytes.addAll([0x1D, 0x21, 0x01]); // double height
    bytes.addAll(utf8.encode(_clean('\nTO\'LANADIGAN: ${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(total)} so\'m\n')));
    bytes.addAll([0x1D, 0x21, 0x00]); // normal size
    bytes.addAll([0x1B, 0x45, 0x00]); // bold off
    
    bytes.addAll(utf8.encode(_clean('\n' + divider + '\n')));

    bytes.addAll(utf8.encode(_clean('${footerText ?? "Xaridingiz uchun rahmat!"}\n')));

    if (showInstagram && instagram != null && instagram.isNotEmpty) {
      bytes.addAll([0x1B, 0x61, 0x01]); // Align center
      bytes.addAll(utf8.encode(_clean('\nInstagram: ${instagram.toUpperCase()}\n\n')));
      
      // QR Code
      String qrData = 'https://instagram.com/${instagram.replaceAll('@', '')}';
      List<int> qrBytes = utf8.encode(qrData);
      int pL = (qrBytes.length + 3) % 256;
      int pH = (qrBytes.length + 3) ~/ 256;

      bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
      bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06]);
      bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x30]);
      bytes.addAll([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30]);
      bytes.addAll(qrBytes);
      bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);
      bytes.addAll(utf8.encode('\n'));
    }

    bytes.addAll(utf8.encode('\n\n\n\n\n\n\n\n\n\n'));

    // Cut paper (partial cut)
    bytes.addAll([0x1D, 0x56, 0x42, 0x00]);

    return bytes;
  }

  static Future<void> printReport({
    required String reportTitle,
    required List<Map<String, dynamic>> sections,
    String? printerName,
    String? ipAddress,
    int width = 80,
    String? orgName,
  }) async {
    final doc = pw.Document();
    
    doc.addPage(
      pw.Page(
        pageFormat: width == 58 ? PdfPageFormat.roll57 : PdfPageFormat.roll80,
        margin: const pw.EdgeInsets.all(5),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Text(
                (orgName ?? 'SIMPLE SALE').toUpperCase(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: width == 58 ? 10 : 12),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                reportTitle.toUpperCase(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: width == 58 ? 12 : 14),
              ),
              pw.Text(
                'Sana: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}',
                style: pw.TextStyle(fontSize: width == 58 ? 8 : 10),
              ),
              pw.Divider(thickness: 1),
              ...sections.map((section) {
                final String title = section['title'] ?? '';
                final List<Map<String, String>> rows = (section['rows'] as List?)?.cast<Map<String, String>>() ?? [];
                
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: width == 58 ? 9 : 11)),
                      pw.Divider(thickness: 0.5),
                    ],
                    ...rows.map((row) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Expanded(child: pw.Text(_clean(row['label'] ?? ''), style: pw.TextStyle(fontSize: width == 58 ? 8 : 10))),
                          pw.Text(_clean(row['value'] ?? ''), style: pw.TextStyle(fontSize: width == 58 ? 8 : 10, fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    )),
                  ],
                );
              }),
              pw.SizedBox(height: 20),
              pw.Divider(thickness: 0.5),
              pw.Text('Simple Sale hisoboti', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
            ],
          );
        },
      ),
    );

    if (printerName != null && printerName != 'Network' && printerName.isNotEmpty) {
      final printers = await Printing.listPrinters();
      if (printers.isNotEmpty) {
        final printer = printers.firstWhere(
          (p) => p.name == printerName,
          orElse: () => printers.first,
        );
        await Printing.directPrintPdf(
          printer: printer,
          onLayout: (format) => doc.save(),
        );
      }
    }

    if (ipAddress != null && ipAddress.isNotEmpty) {
      try {
        final socket = await Socket.connect(ipAddress, 9100, timeout: const Duration(seconds: 3));
        List<int> bytes = [];
        int maxChars = width == 58 ? 32 : 42;
        
        // init
        bytes.addAll([0x1B, 0x40]);
        // center
        bytes.addAll([0x1B, 0x61, 0x01]);
        bytes.addAll(utf8.encode(_clean('${orgName ?? 'SIMPLE SALE'}\n')));
        bytes.addAll([0x1B, 0x45, 0x01]);
        bytes.addAll(utf8.encode(_clean('${reportTitle.toUpperCase()}\n')));
        bytes.addAll([0x1B, 0x45, 0x00]);
        bytes.addAll(utf8.encode(_clean('Sana: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}\n')));
        bytes.addAll(utf8.encode(_clean('-' * maxChars + '\n')));
        
        for (var section in sections) {
          final String title = section['title'] ?? '';
          final List<Map<String, String>> rows = (section['rows'] as List?)?.cast<Map<String, String>>() ?? [];
          
          if (title.isNotEmpty) {
            bytes.addAll([0x1B, 0x61, 0x00]); // left
            bytes.addAll([0x1B, 0x45, 0x01]);
            bytes.addAll(utf8.encode(_clean('\n$title\n')));
            bytes.addAll([0x1B, 0x45, 0x00]);
            bytes.addAll(utf8.encode(_clean('-' * maxChars + '\n')));
          }
          
          for (var row in rows) {
            String label = row['label'] ?? '';
            String value = row['value'] ?? '';
            int spaces = maxChars - label.length - value.length;
            if (spaces < 1) spaces = 1;
            bytes.addAll(utf8.encode(_clean(label + (' ' * spaces) + value + '\n')));
          }
        }
        
        bytes.addAll(utf8.encode(_clean('\n' + '-' * maxChars + '\n')));
        bytes.addAll(utf8.encode(_clean('Simple Sale hisoboti\n\n\n\n\n')));
        bytes.addAll([0x1D, 0x56, 0x42, 0x00]);
        
        socket.add(bytes);
        await socket.flush();
        await socket.close();
      } catch (e) {
        debugPrint('IP Printer error: $e');
      }
    }
  }

  static Future<void> testPrint({
    required String? printerName,
    required String? ipAddress,
    required String registerName,
    int width = 80,
  }) async {
    final List<SaleItem> testItems = [
      SaleItem(
        productId: 'test-pro',
        productName: 'TEST MAHSULOT',
        quantity: 1.0,
        price: 15000.0,
      ),
      SaleItem(
        productId: 'test-pro-2',
        productName: 'MUVOFFIQUYATLI ULANISH!',
        quantity: 2.0,
        price: 5000.0,
      ),
    ];

    await printReceipt(
      items: testItems,
      total: 25000.0,
      registerName: registerName,
      printerName: printerName,
      ipAddress: ipAddress,
      orgName: 'TEST PRINT',
      orgAddress: 'TIZIM TEKSHIRUVI',
      width: width,
      footerText: 'Printer muvaffaqiyatli sozlandi!',
      showInstagram: false,
    );
  }

  static Future<List<Printer>> getPrinters() async {
    return await Printing.listPrinters();
  }
}
