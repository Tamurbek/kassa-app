import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import '../providers/app_state.dart';
import 'database_service.dart';

class ExcelImportService {
  static Future<void> importProducts(BuildContext context) async {
    final state = Provider.of<AppState>(context, listen: false);

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.single.path == null) return;

    // Show loading indicator during parse
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      File file = File(result.files.single.path!);
      var bytes = file.readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      Navigator.pop(context); // Close parsing indicator

      if (excel.tables.isEmpty) {
        _showError(context, 'Excel fayli bo\'sh yoki noto\'g\'ri');
        return;
      }

      Sheet? sheet = excel.tables.values.first;
      if (sheet == null || sheet.maxRows < 2) {
        _showError(context, 'Faylda yetarli ma\'lumot yo\'q');
        return;
      }

      // Column detection
      int nameIdx = 0, catIdx = 1, priceIdx = 2, costIdx = 3, barcodeIdx = 4, unitIdx = 5;
      
      var headerRow = sheet.rows[0];
      for (int i = 0; i < headerRow.length; i++) {
          String val = headerRow[i]?.value?.toString().toLowerCase() ?? '';
          if (val.contains('nom') || val.contains('name')) nameIdx = i;
          else if (val.contains('tur') || val.contains('categor') || val.contains('kat')) catIdx = i;
          else if (val.contains('sotish') || val.contains('price') || val.contains('narx')) priceIdx = i;
          else if (val.contains('tan') || val.contains('cost')) costIdx = i;
          else if (val.contains('shtrix') || val.contains('barcode')) barcodeIdx = i;
          else if (val.contains('birlik') || val.contains('unit')) unitIdx = i;
      }

      Set<String> excelCategories = {};
      List<Map<String, dynamic>> rawRows = [];

      for (int i = 1; i < sheet.maxRows; i++) {
        var row = sheet.rows[i];
        if (row.length <= nameIdx || row[nameIdx]?.value == null) continue;

        String name = row[nameIdx]?.value?.toString() ?? '';
        String categoryName = (row.length > catIdx ? row[catIdx]?.value?.toString() : null) ?? 'Boshqa';
        
        dynamic priceVal = row.length > priceIdx ? row[priceIdx]?.value : 0;
        double price = double.tryParse(priceVal?.toString() ?? '0') ?? 0.0;
        
        dynamic costVal = row.length > costIdx ? row[costIdx]?.value : 0;
        double costPrice = double.tryParse(costVal?.toString() ?? '0') ?? 0.0;
        
        String barcode = (row.length > barcodeIdx ? row[barcodeIdx]?.value?.toString() : null) ?? '';
        String unit = (row.length > unitIdx ? row[unitIdx]?.value?.toString() : null) ?? 'dona';

        excelCategories.add(categoryName);
        rawRows.add({
          'name': name,
          'categoryName': categoryName,
          'price': price,
          'costPrice': costPrice,
          'barcode': barcode,
          'unit': unit,
        });
      }

      if (rawRows.isEmpty) {
        _showError(context, 'Ma\'lumotlar topilmadi');
        return;
      }

      // Category mapping
      Map<String, String>? mapping = await _showMappingDialog(context, excelCategories.toList(), state);
      if (mapping == null) return;

      // Final Import
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      int count = 0;
      for (var r in rawRows) {
        String catId = mapping[r['categoryName']]!;
        await state.addProduct(Product.create(
          r['name'],
          r['price'],
          catId,
          r['barcode'],
          costPrice: r['costPrice'],
          unit: r['unit'],
        ));
        count++;
      }

      Navigator.pop(context); // Close import indicator
      _showSuccess(context, '$count ta mahsulot muvaffaqiyatli qo\'shildi');

    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showError(context, 'Xatolik: $e');
    }
  }

  static Future<Map<String, String>?> _showMappingDialog(
      BuildContext context, List<String> excelCats, AppState state) async {
    
    Map<String, String> mapping = {};
    for (var cat in excelCats) {
      final match = state.activeCategories.firstWhere(
        (c) => c.name.toLowerCase() == cat.toLowerCase(),
        orElse: () => Category(id: '', name: ''),
      );
      if (match.id.isNotEmpty) mapping[cat] = match.id;
    }

    List<String> remaining = excelCats.where((c) => !mapping.containsKey(c)).toList();
    if (remaining.isEmpty) return mapping;

    return await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Kategoriyalar biriktirish'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Topilmagan kategoriyalarni tizimdagi mavjudlariga biriktiring:'),
                  const SizedBox(height: 20),
                  ...remaining.map((cat) => Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text(cat, style: const TextStyle(fontWeight: FontWeight.bold))),
                        const Icon(Icons.arrow_right_alt),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 3,
                          child: DropdownButtonFormField<String>(
                            value: mapping[cat],
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                            hint: const Text('Tanlang...'),
                            items: [
                              const DropdownMenuItem(value: '__new__', child: Text('+ Yangi yaratish', style: TextStyle(color: Colors.green))),
                              ...state.activeCategories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                            ],
                            onChanged: (val) => setState(() => mapping[cat] = val!),
                          ),
                        ),
                      ],
                    ),
                  )),
                  if (remaining.length > 2) ...[
                    const Divider(),
                    TextButton.icon(
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Mavjud bo\'lmaganlarni hammasini yangi yaratish'),
                      onPressed: () {
                        setState(() {
                          for (var r in remaining) mapping[r] = '__new__';
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
            ElevatedButton(
              onPressed: mapping.length == excelCats.length ? () async {
                for (var key in mapping.keys.toList()) {
                  if (mapping[key] == '__new__') {
                    final newCat = await state.addCategory(key);
                    mapping[key] = newCat.id;
                  }
                }
                Navigator.pop(context, mapping);
              } : null,
              child: const Text('Boshlash'),
            ),
          ],
        ),
      ),
    );
  }

  static String _getCellValue(Data? data) {
    if (data == null || data.value == null) return '';
    var v = data.value;
    if (v is TextCellValue) return v.value.toString().trim();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toString();
    if (v is BoolCellValue) return v.value.toString();
    return v.toString().trim();
  }

  static Future<void> importStockEntry(BuildContext context, String warehouseId) async {
    final state = Provider.of<AppState>(context, listen: false);

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.single.path == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      File file = File(result.files.single.path!);
      var bytes = file.readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      Navigator.pop(context);

      if (excel.tables.isEmpty) {
        _showError(context, 'Excel fayli bo\'sh');
        return;
      }

      Sheet? sheet = excel.tables.values.first;
      if (sheet == null || sheet.maxRows < 2) {
        _showError(context, 'Ma\'lumotlar topilmadi');
        return;
      }

      int barcodeIdx = -1, nameIdx = -1, qtyIdx = -1, costIdx = -1;
      var headerRow = sheet.rows[0];
      List<String> foundHeaders = [];
      for (int i = 0; i < headerRow.length; i++) {
        String val = _getCellValue(headerRow[i]).toLowerCase();
        foundHeaders.add(val);
        if (val.contains('barcode') || val.contains('shtrix')) barcodeIdx = i;
        else if (val.contains('nom') || val.contains('name')) nameIdx = i;
        else if (val.contains('soni') || val.contains('qty') || val.contains('miqdor') || val.contains('son')) qtyIdx = i;
        else if (val.contains('tan') || val.contains('cost')) costIdx = i;
      }

      if (qtyIdx == -1 || (barcodeIdx == -1 && nameIdx == -1)) {
        _showError(context, 'Kerakli ustunlar topilmadi (Shtrix kod yoki Nom, va Soni)');
        return;
      }

      List<StockEntryItem> items = [];
      int skipCount = 0;

      for (int i = 1; i < sheet.maxRows; i++) {
        var row = sheet.rows[i];
        String barcode = barcodeIdx != -1 && row.length > barcodeIdx ? _getCellValue(row[barcodeIdx]) : '';
        String name = nameIdx != -1 && row.length > nameIdx ? _getCellValue(row[nameIdx]) : '';
        String qtyStr = qtyIdx != -1 && row.length > qtyIdx ? _getCellValue(row[qtyIdx]) : '0';
        String costStr = costIdx != -1 && row.length > costIdx ? _getCellValue(row[costIdx]) : '0';
        
        // Remove spaces and handle commas for numeric parsing
        double qty = double.tryParse(qtyStr.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;
        double cost = double.tryParse(costStr.replaceAll(' ', '').replaceAll(',', '.')) ?? 0.0;

        if (qty <= 0) continue;

        Product? product;
        if (barcode.isNotEmpty) {
           product = state.products.where((p) => p.barcode == barcode || p.additionalBarcodes.contains(barcode)).firstOrNull;
        }
        if (product == null && name.isNotEmpty) {
           product = state.products.where((p) => p.name.toLowerCase() == name.toLowerCase()).firstOrNull;
        }

        if (product != null) {
          items.add(StockEntryItem(
            productId: product.id,
            productName: product.name,
            quantity: qty,
          ));
          if (cost > 0) {
            final idx = state.products.indexOf(product);
            if (idx >= 0) {
               state.products[idx] = product.copyWith(costPrice: cost);
               await DatabaseService.updateProductCostPrice(product.id, cost);
            }
          }
        } else {
          skipCount++;
        }
      }

      if (items.isEmpty) {
        String msg = 'Exceldan ma\'lumot o\'qib bo\'lmadi.\n'
                    'Tizim aniqlagan ustunlar: $foundHeaders\n'
                    'Soni ustuni: ${qtyIdx != -1 ? 'D' : 'TOPILMADI'}\n'
                    'Tekshiring:\n'
                    '- Soni ustunida raqam yozilganmi?\n'
                    '- Mahsulotlar bazada bormi? ($skipCount ta topilmadi)';
        _showError(context, msg);
        return;
      }

      final entry = StockEntry(
        id: const Uuid().v4(),
        warehouseId: warehouseId,
        date: DateTime.now(),
        items: items,
        description: 'Exceldan import qilindi',
      );

      await state.addStockEntry(entry);
      await state.reloadData();
      _showSuccess(context, '${items.length} ta mahsulot kirim qilindi. ($skipCount ta topilmadi)');

    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showError(context, 'Xatolik: $e');
    }
  }

  static Future<void> downloadStockEntryTemplate(BuildContext context, List<Product> products) async {
    final state = Provider.of<AppState>(context, listen: false);
    final allCategories = state.activeCategories;
    
    List<String>? selectedCategoryIds = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        List<String> selected = [];
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Kategoriyalarni tanlang'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Shablonda qaysi turdagi mahsulotlar bo\'lishini xohlaysiz?'),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => setDialogState(() => selected = allCategories.map((c) => c.id).toList()),
                    child: const Text('Hammasini tanlash'),
                  ),
                  const Divider(),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: allCategories.map((cat) => CheckboxListTile(
                          title: Text(cat.name),
                          value: selected.contains(cat.id),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) selected.add(cat.id);
                              else selected.remove(cat.id);
                            });
                          },
                        )).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
              ElevatedButton(
                onPressed: selected.isNotEmpty ? () => Navigator.pop(context, selected) : null,
                child: const Text('Yuklab olish'),
              ),
            ],
          ),
        );
      },
    );

    if (selectedCategoryIds == null) return;

    final filteredProducts = products.where((p) => selectedCategoryIds.contains(p.categoryId)).toList();
    if (filteredProducts.isEmpty) {
      _showError(context, 'Tanlangan kategoriyalar bo\'yicha mahsulotlar topilmadi');
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      // Headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = TextCellValue("Shtrix kod");
      sheetObject.cell(CellIndex.indexByString("B1")).value = TextCellValue("Mahsulot nomi");
      sheetObject.cell(CellIndex.indexByString("C1")).value = TextCellValue("Kategoriya");
      sheetObject.cell(CellIndex.indexByString("D1")).value = TextCellValue("Soni");
      sheetObject.cell(CellIndex.indexByString("E1")).value = TextCellValue("Tan narxi (ixtiyoriy)");

      // Fill products
      for (int i = 0; i < filteredProducts.length; i++) {
        final p = filteredProducts[i];
        int row = i + 1;
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(p.barcode);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(p.name);
        
        final cat = state.categories.where((c) => c.id == p.categoryId).firstOrNull;
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value = TextCellValue(cat?.name ?? 'Boshqa');
      }

      var fileBytes = excel.save();
      String? outputPath = await FilePicker.platform.saveFile(
        fileName: "shablon_kirim.xlsx",
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );

      if (outputPath != null) {
        File(outputPath)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
        _showSuccess(context, "Kirim shabloni saqlandi");
      }
    } catch (e) {
      _showError(context, "Xatolik: $e");
    }
  }

  static Future<void> downloadTemplate(BuildContext context) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      // Headers
      sheetObject.cell(CellIndex.indexByString("A1")).value = TextCellValue("Mahsulot nomi");
      sheetObject.cell(CellIndex.indexByString("B1")).value = TextCellValue("Kategoriya");
      sheetObject.cell(CellIndex.indexByString("C1")).value = TextCellValue("Tan narxi");
      sheetObject.cell(CellIndex.indexByString("D1")).value = TextCellValue("Sotish narxi");
      sheetObject.cell(CellIndex.indexByString("E1")).value = TextCellValue("Shtrix kod");
      sheetObject.cell(CellIndex.indexByString("F1")).value = TextCellValue("O'lchov birligi");

      // Sample Data
      sheetObject.cell(CellIndex.indexByString("A2")).value = TextCellValue("Olma (Qizil)");
      sheetObject.cell(CellIndex.indexByString("B2")).value = TextCellValue("Mevalar");
      sheetObject.cell(CellIndex.indexByString("C2")).value = IntCellValue(12000);
      sheetObject.cell(CellIndex.indexByString("D2")).value = IntCellValue(15000);
      sheetObject.cell(CellIndex.indexByString("E2")).value = TextCellValue("12345678");
      sheetObject.cell(CellIndex.indexByString("F2")).value = TextCellValue("kg");

      sheetObject.cell(CellIndex.indexByString("A3")).value = TextCellValue("Coca-Cola 1.5L");
      sheetObject.cell(CellIndex.indexByString("B3")).value = TextCellValue("Ichimliklar");
      sheetObject.cell(CellIndex.indexByString("C3")).value = IntCellValue(10000);
      sheetObject.cell(CellIndex.indexByString("D3")).value = IntCellValue(12000);
      sheetObject.cell(CellIndex.indexByString("E3")).value = TextCellValue("87654321");
      sheetObject.cell(CellIndex.indexByString("F3")).value = TextCellValue("dona");

      var fileBytes = excel.save();
      
      String? outputPath = await FilePicker.platform.saveFile(
        fileName: "shablon_mahsulotlar.xlsx",
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );

      if (outputPath != null) {
        File(outputPath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes!);
        _showSuccess(context, "Shablon saqlandi: $outputPath");
      }
    } catch (e) {
      _showError(context, "Shablonni saqlashda xatolik: $e");
    }
  }

  static void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  static void _showSuccess(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }
}
