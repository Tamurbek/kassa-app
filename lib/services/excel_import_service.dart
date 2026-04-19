import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../providers/features/inventory_provider.dart';
import 'database_service.dart';
import '../core/utils/formatter.dart';

class ExcelImportService {
  static Future<void> importFromExcel(BuildContext context) async {
    final inventory = Provider.of<InventoryProvider>(context, listen: false);

    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null || result.files.single.path == null) return;

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      File file = File(result.files.single.path!);
      var bytes = file.readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      Navigator.pop(context); // Close indicator

      if (excel.tables.isEmpty) {
        _showError(context, 'Excel fayli bo\'sh yoki noto\'g\'ri');
        return;
      }

      Sheet? sheet = excel.tables.values.first;
      if (sheet == null || sheet.maxRows < 2) {
        _showError(context, 'Faylda yetarli ma\'lumot yo\'q');
        return;
      }

      // Column detection with better defaults
      int nameIdx = -1, catIdx = -1, priceIdx = -1, costIdx = -1, barcodeIdx = -1, unitIdx = -1;
      int qtyIdx = -1, warehouseIdx = -1, qtyInBoxIdx = -1, boxPriceIdx = -1, boxBarcodeIdx = -1;
      
      var headerRow = sheet.rows[0];
      for (int i = 0; i < headerRow.length; i++) {
          String val = _getCellValue(headerRow[i]).toLowerCase().trim();
          if (val.isEmpty) continue;

          if (val.contains('ombor') || val.contains('warehouse')) {
            warehouseIdx = i;
          } else          if (val.contains('blok narxi') || val.contains('box price') || val.contains('upakovka narxi')) {
            boxPriceIdx = i;
          } else if (val.contains('blok ichi') || val.contains('box qty') || val.contains('pachka') || val.contains('upakovka soni')) {
            qtyInBoxIdx = i;
          } else if (val.contains('blok shtrix') || val.contains('box barcode')) {
            boxBarcodeIdx = i;
          } else if (val.contains('tan') || val.contains('cost') || val.contains('buy')) {
            costIdx = i;
          } else if (val.contains('sotish') || val.contains('sotuv') || val.contains('price') || val.contains('selling')) {
            priceIdx = i;
          } else if (val.contains('nom') || val.contains('name') || val.contains('mahsulot')) {
            nameIdx = i;
          } else if (val.contains('tur') || val.contains('categor') || val.contains('kat')) {
            catIdx = i;
          } else if (val.contains('shtrix') || val.contains('barcode')) {
            barcodeIdx = i;
          } else if (val.contains('birlik') || val.contains('unit')) {
            unitIdx = i;
          } else if (val.contains('soni') || val.contains('miqdor') || val.contains('qty') || val.contains('qoldiq')) {
            qtyIdx = i;
          } else if (val.contains('narx')) {
            // Fallback for generic "narx" if priceIdx is not set
            if (priceIdx == -1) priceIdx = i;
          }
      }

      // If defaults not found, use common indices as last resort
      if (nameIdx == -1) nameIdx = 0;
      if (catIdx == -1) catIdx = 1;
      if (costIdx == -1) costIdx = 2;
      if (priceIdx == -1) priceIdx = 3;

      Set<String> excelCategories = {};
      List<Map<String, dynamic>> rawRows = [];

      for (int i = 1; i < sheet.maxRows; i++) {
        var row = sheet.rows[i];
        if (nameIdx >= row.length || row[nameIdx]?.value == null) continue;

        String name = _getCellValue(row[nameIdx]);
        if (name.isEmpty) continue;

        String categoryName = (catIdx != -1 && row.length > catIdx) ? _getCellValue(row[catIdx]) : '';
        if (categoryName.isEmpty) categoryName = 'Boshqa';
        
        String priceStr = (priceIdx != -1 && row.length > priceIdx) ? _getCellValue(row[priceIdx]) : '0';
        double price = _parseRobustDouble(priceStr);
        
        String costStr = (costIdx != -1 && row.length > costIdx) ? _getCellValue(row[costIdx]) : '0';
        double costPrice = _parseRobustDouble(costStr);
        
        String additionalBarcodesRaw = (barcodeIdx != -1 && row.length > barcodeIdx ? _getCellValue(row[barcodeIdx]) : '');
        List<String> barcodes = additionalBarcodesRaw.split(RegExp(r'[,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        String barcode = barcodes.isNotEmpty ? barcodes[0] : '';
        List<String> additionalBarcodes = barcodes.length > 1 ? barcodes.sublist(1) : [];
        
        String unit = (unitIdx != -1 && row.length > unitIdx ? _getCellValue(row[unitIdx]) : 'dona');
        double quantity = (qtyIdx != -1 && row.length > qtyIdx) ? _parseRobustDouble(_getCellValue(row[qtyIdx])) : 0;
        String warehouseName = (warehouseIdx != -1 && row.length > warehouseIdx) ? _getCellValue(row[warehouseIdx]) : '';
        
        String qtyInBoxStr = (qtyInBoxIdx != -1 && row.length > qtyInBoxIdx) ? _getCellValue(row[qtyInBoxIdx]) : '1';
        double qtyInBox = _parseRobustDouble(qtyInBoxStr);
        
        double? boxPrice;
        if (boxPriceIdx != -1 && row.length > boxPriceIdx) {
          String val = _getCellValue(row[boxPriceIdx]);
          if (val.isNotEmpty) boxPrice = _parseRobustDouble(val);
        }
        
        String boxBarcodeRaw = (boxBarcodeIdx != -1 && row.length > boxBarcodeIdx) ? _getCellValue(row[boxBarcodeIdx]) : '';
        List<String> boxBars = boxBarcodeRaw.split(RegExp(r'[,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        String boxBarcode = boxBars.isNotEmpty ? boxBars[0] : '';
        List<String> additionalBoxBarcodes = boxBars.length > 1 ? boxBars.sublist(1) : [];

        excelCategories.add(categoryName);
        rawRows.add({
          'name': name,
          'categoryName': categoryName,
          'price': price,
          'costPrice': costPrice,
          'barcode': barcode,
          'additionalBarcodes': additionalBarcodes,
          'unit': unit,
          'quantity': quantity,
          'warehouseName': warehouseName,
          'quantityInBox': qtyInBox > 0 ? qtyInBox : 1.0,
          'boxPrice': boxPrice,
          'boxBarcode': boxBarcode,
          'additionalBoxBarcodes': additionalBoxBarcodes,
        });
      }

      if (rawRows.isEmpty) {
        _showError(context, 'Ma\'lumotlar topilmadi');
        return;
      }

      // Category mapping
      Map<String, String>? mapping = await _showMappingDialog(context, excelCategories.toList(), inventory);
      if (mapping == null) return;

      // Warehouse mapping (NEW)
      Set<String> excelWarehouses = rawRows.map((r) => r['warehouseName'] as String).where((w) => w.isNotEmpty).toSet();
      Map<String, String> warehouseMapping = {};
      
      if (excelWarehouses.isNotEmpty) {
        for (var wName in excelWarehouses) {
          final match = inventory.activeWarehouses.where((w) => w.name.toLowerCase() == wName.toLowerCase().trim()).firstOrNull;
          if (match != null) {
            warehouseMapping[wName] = match.id;
          }
        }
        
        List<String> remainingWarehouses = excelWarehouses.where((w) => !warehouseMapping.containsKey(w)).toList();
        if (remainingWarehouses.isNotEmpty) {
          Map<String, String>? wMap = await _showWarehouseMappingDialog(context, remainingWarehouses, inventory);
          if (wMap == null) return; // User cancelled
          warehouseMapping.addAll(wMap);
        }
      }

      // Final Import
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );

      Map<String, Product> productsMap = {}; // id -> product
      Map<String, String> barcodeToId = {}; // barcode -> id
      Map<String, List<StockEntryItem>> warehouseStockItems = {}; // warehouseId -> items

      for (var r in rawRows) {
        String catId = mapping[r['categoryName']]!;
        String barcode = r['barcode'] as String;
        String name = r['name'] as String;
        
        Product? product;

        // 1. Check if we already processed this product in THIS import session
        if (barcode.isNotEmpty && barcodeToId.containsKey(barcode)) {
          product = productsMap[barcodeToId[barcode]];
        }

        // 2. Search in existing database products (including deleted ones)
        if (product == null) {
          Product? existing;
          final rowBarcodes = [r['barcode'] as String, ...(r['additionalBarcodes'] as List<String>)].where((b) => b.isNotEmpty).toList();
          
          if (rowBarcodes.isNotEmpty) {
            // Check if ANY of the barcodes from Excel match ANY existing product (primary or additional)
            for (var b in rowBarcodes) {
              existing = inventory.products.where((p) => 
                p.barcode == b || 
                p.additionalBarcodes.contains(b) ||
                p.boxBarcode == b ||
                p.additionalBoxBarcodes.contains(b)
              ).firstOrNull;
              if (existing != null) break;
            }
          }
          
          // Fallback to name search if barcode not found or empty
          if (existing == null && name.isNotEmpty) {
            existing = inventory.products.where((p) => p.name.toLowerCase() == name.toLowerCase()).firstOrNull;
          }

          if (existing != null) {
            // Update existing product
            product = existing.copyWith(
              name: name,
              price: r['price'],
              costPrice: r['costPrice'],
              categoryId: catId,
              unit: r['unit'],
              quantityInBox: r['quantityInBox'],
              boxPrice: r['boxPrice'],
              boxBarcode: r['boxBarcode'],
              isDeleted: false, // Restore if it was deleted
              additionalBarcodes: r['additionalBarcodes'] as List<String>,
              additionalBoxBarcodes: r['additionalBoxBarcodes'] as List<String>,
              trackStock: true, // Ensure tracking is enabled
            );
          } else {
            // Create new product
            product = Product.create(
              name,
              r['price'],
              catId,
              barcode,
              costPrice: r['costPrice'],
              unit: r['unit'],
              quantityInBox: r['quantityInBox'],
              boxPrice: r['boxPrice'],
              boxBarcode: r['boxBarcode'],
              trackStock: true, // Explicitly enable for new products
            ).copyWith(
              additionalBarcodes: r['additionalBarcodes'] as List<String>,
              additionalBoxBarcodes: r['additionalBoxBarcodes'] as List<String>,
            );
          }
        } else {
          // If we already have a product in this session, just update its info from this row
          product = product.copyWith(
            name: name,
            price: r['price'],
            costPrice: r['costPrice'],
            categoryId: catId,
            unit: r['unit'],
            quantityInBox: r['quantityInBox'],
            boxPrice: r['boxPrice'],
            boxBarcode: r['boxBarcode'],
          );
        }

        // Update tracking maps
        productsMap[product.id] = product;
        if (product.barcode.isNotEmpty) {
          barcodeToId[product.barcode] = product.id;
        }

        // Stock Entry Logic
        if (r['quantity'] > 0) {
          String warehouseId = '';
          String wName = r['warehouseName'];
          
          if (wName.isNotEmpty && warehouseMapping.containsKey(wName)) {
            warehouseId = warehouseMapping[wName]!;
          }
          
          if (warehouseId.isEmpty) {
            warehouseId = inventory.mainWarehouse?.id ?? '';
          }

          if (warehouseId.isNotEmpty) {
            warehouseStockItems.putIfAbsent(warehouseId, () => []);
            warehouseStockItems[warehouseId]!.add(StockEntryItem(
              productId: product.id,
              productName: product.name,
              quantity: r['quantity'],
              costPrice: r['costPrice'],
              price: r['price'],
            ));
          }
        }
      }

      List<Product> productsToSave = [];
      for (var product in productsMap.values) {
        // Prepare product with updated stocks from Excel rows
        Product updatedProduct = product;
        
        // Find if we have stock entries for this product in the current import
        for (var warehouseId in warehouseStockItems.keys) {
          final items = warehouseStockItems[warehouseId]!;
          final excelItem = items.where((it) => it.productId == product.id).firstOrNull;
          
          if (excelItem != null) {
            // SET the stock to exactly what's in Excel, overwriting current value
            Map<String, double> newStocks = Map.from(updatedProduct.stocks);
            newStocks[warehouseId] = excelItem.quantity;
            updatedProduct = updatedProduct.copyWith(stocks: newStocks);
          }
        }
        productsToSave.add(updatedProduct);
      }
      
      // Important: skipRecalculate here because we will do it after adding InventoryEntry
      await inventory.saveProductsBatch(productsToSave, skipRecalculate: true);

      // Create Inventory entries (Invertarizatsiya) to explicitly SET the stock levels
      for (var entry in warehouseStockItems.entries) {
        final inventoryEntry = InventoryEntry(
          id: const Uuid().v4(),
          warehouseId: entry.key,
          date: DateTime.now(),
          items: entry.value.map((it) => InventoryItem(
            productId: it.productId,
            productName: it.productName,
            expectedQuantity: 0, // We don't care about expected, we are setting actual
            actualQuantity: it.quantity,
          )).toList(),
          description: 'Katalog importi: Qoldiqlar Exceldagiga tenglashtirildi',
        );
        
        await inventory.addInventory(inventoryEntry);
      }

      await inventory.reloadData(forceRecalculate: true);

      Navigator.pop(context); // Close indicator
      _showSuccess(context, '${productsToSave.length} ta mahsulot muvaffaqiyatli yangilandi');

    } catch (e) {
      if (Navigator.canPop(context)) Navigator.pop(context);
      _showError(context, 'Xatolik: $e');
    }
  }

  static Future<Map<String, String>?> _showMappingDialog(
      BuildContext context, List<String> excelCats, InventoryProvider inventory) async {
    
    Map<String, String> mapping = {};
    for (var cat in excelCats) {
      final match = inventory.activeCategories.firstWhere(
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
                              ...inventory.activeCategories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                            ],
                            onChanged: (val) => setState(() => mapping[cat] = val!),
                          ),
                        ),
                      ],
                    ),
                  )),
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
                    final newCat = Category(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      name: key,
                    );
                    await inventory.saveCategory(newCat);
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

  static Future<Map<String, String>?> _showWarehouseMappingDialog(
      BuildContext context, List<String> excelWarehouses, InventoryProvider inventory) async {
    
    Map<String, String> mapping = {};
    String mainWarehouseId = inventory.mainWarehouse?.id ?? '';

    return await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Omborlarni biriktirish'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Exceldagi quyidagi omborlar tizimda topilmadi. Ularni mavjud omborlarga biriktiring:'),
                  const SizedBox(height: 20),
                  ...excelWarehouses.map((wName) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(wName, style: const TextStyle(fontWeight: FontWeight.bold))),
                        const Icon(Icons.arrow_right_alt),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: mapping[wName] ?? (inventory.activeWarehouses.length == 1 ? mainWarehouseId : null),
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                            hint: const Text('Tanlang...'),
                            items: inventory.activeWarehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                            onChanged: (val) => setState(() => mapping[wName] = val!),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Bekor qilish')),
            ElevatedButton(
              onPressed: mapping.length == excelWarehouses.length ? () => Navigator.pop(context, mapping) : null,
              child: const Text('Davom etish'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<List<StockEntryItem>?> parseStockEntryFile(BuildContext context) async {
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    
    try {
      final file = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (file == null || file.files.isEmpty) return null;

      var bytes = File(file.files.first.path!).readAsBytesSync();
      var excel = Excel.decodeBytes(bytes);

      if (excel.tables.isEmpty) {
        _showError(context, 'Excel bo\'sh');
        return null;
      }

      var sheet = excel.tables.values.first;
      if (sheet.maxRows <= 1) {
        _showError(context, 'Excelda ma\'lumotlar topilmadi');
        return null;
      }

      int barcodeIdx = -1, nameIdx = -1, qtyIdx = -1, costIdx = -1, priceIdx = -1;
      var headerRow = sheet.rows[0];
      for (int i = 0; i < headerRow.length; i++) {
        String h = _getCellValue(headerRow[i]).toLowerCase().trim();
        if (h.isEmpty) continue;
        
        if (h.contains('shtrix') || h.contains('barcode')) {
          barcodeIdx = i;
        } else if (h.contains('tan') || h.contains('cost') || h.contains('buy')) {
          costIdx = i;
        } else if (h.contains('sotish') || h.contains('price') || h.contains('sotuv') || h.contains('sotish')) {
          priceIdx = i;
        } else if ((h.contains('nomi') || h.contains('mahsulot')) && !h.contains('ombor') && !h.contains('warehouse')) {
          nameIdx = i;
        } else if (h.contains('soni') || h.contains('miqdor') || h.contains('qty') || h.contains('qoldiq')) {
          qtyIdx = i;
        } else if (h.contains('narx')) {
          if (priceIdx == -1) priceIdx = i;
        }
      }

      if (qtyIdx == -1 || (barcodeIdx == -1 && nameIdx == -1)) {
        _showError(context, 'Kerakli ustunlar topilmadi (Shtrix kod yoki Nom, va Soni)');
        return null;
      }

      List<StockEntryItem> items = [];
      for (int i = 1; i < sheet.maxRows; i++) {
        var row = sheet.rows[i];
        if (row.isEmpty) continue;

        String barcode = barcodeIdx != -1 && row.length > barcodeIdx ? _getCellValue(row[barcodeIdx]) : '';
        String name = nameIdx != -1 && row.length > nameIdx ? _getCellValue(row[nameIdx]) : '';
        String qtyStr = qtyIdx != -1 && row.length > qtyIdx ? _getCellValue(row[qtyIdx]) : '0';
        String costStr = costIdx != -1 && row.length > costIdx ? _getCellValue(row[costIdx]) : '0';
        String priceStr = priceIdx != -1 && row.length > priceIdx ? _getCellValue(row[priceIdx]) : '0';
        
        double qty = _parseRobustDouble(qtyStr);
        double cost = _parseRobustDouble(costStr);
        double price = _parseRobustDouble(priceStr);

        if (barcode.isEmpty && name.isEmpty) continue;
        if (qty <= 0) continue;

        Product? product;
        if (barcode.isNotEmpty) {
           final bars = barcode.split(RegExp(r'[,;]')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
           for (var b in bars) {
             product = inventory.activeProducts.where((p) => 
               p.barcode == b || 
               p.additionalBarcodes.contains(b) ||
               p.boxBarcode == b ||
               p.additionalBoxBarcodes.contains(b)
             ).firstOrNull;
             if (product != null) break;
           }
        }
        if (product == null && name.isNotEmpty) {
           product = inventory.activeProducts.where((p) => p.name.toLowerCase() == name.toLowerCase()).firstOrNull;
        }

        if (product != null) {
          items.add(StockEntryItem(
            productId: product.id,
            productName: product.name,
            quantity: qty,
            costPrice: cost > 0 ? cost : product.costPrice,
            price: price > 0 ? price : product.price,
          ));
        }
      }
      return items;
    } catch (e) {
      _showError(context, 'Excel o\'qishda xato: $e');
      return null;
    }
  }

  static Future<void> importStockEntry(BuildContext context, String warehouseId) async {
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    List<StockEntryItem>? items = await parseStockEntryFile(context);
    if (items == null || items.isEmpty) return;

    try {
      final entry = StockEntry(
        id: const Uuid().v4(),
        warehouseId: warehouseId,
        date: DateTime.now(),
        items: items,
        description: 'Exceldan import qilindi',
      );

      await inventory.addStockEntry(entry);
      _showSuccess(context, '${items.length} ta mahsulot muvaffaqiyatli kirim qilindi.');
    } catch (e) {
      _showError(context, 'Kirim qilishda xatolik: $e');
    }
  }

  static Future<void> downloadStockEntryTemplate(BuildContext context, List<Product> products) async {
     final inventory = Provider.of<InventoryProvider>(context, listen: false);
     try {
      var excel = Excel.createExcel();
      Sheet sheetObject = excel['Sheet1'];

      sheetObject.cell(CellIndex.indexByString("A1")).value = TextCellValue("Shtrix kod");
      sheetObject.cell(CellIndex.indexByString("B1")).value = TextCellValue("Mahsulot nomi");
      sheetObject.cell(CellIndex.indexByString("C1")).value = TextCellValue("Soni");
      sheetObject.cell(CellIndex.indexByString("D1")).value = TextCellValue("Tan narxi");
      sheetObject.cell(CellIndex.indexByString("E1")).value = TextCellValue("Sotuv narxi");

      for (int i = 0; i < products.length; i++) {
        final p = products[i];
        int row = i + 1;
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value = TextCellValue(p.barcode);
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value = TextCellValue(p.name);
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

      sheetObject.cell(CellIndex.indexByString("A1")).value = TextCellValue("Mahsulot nomi");
      sheetObject.cell(CellIndex.indexByString("B1")).value = TextCellValue("Kategoriya");
      sheetObject.cell(CellIndex.indexByString("C1")).value = TextCellValue("Tan narxi");
      sheetObject.cell(CellIndex.indexByString("D1")).value = TextCellValue("Sotish narxi");
      sheetObject.cell(CellIndex.indexByString("E1")).value = TextCellValue("Shtrix kod");
      sheetObject.cell(CellIndex.indexByString("F1")).value = TextCellValue("O'lchov birligi");
      sheetObject.cell(CellIndex.indexByString("G1")).value = TextCellValue("Soni (Qoldiq)");
      sheetObject.cell(CellIndex.indexByString("H1")).value = TextCellValue("Ombor nomi");
      sheetObject.cell(CellIndex.indexByString("I1")).value = TextCellValue("Blok ichidagi soni");
      sheetObject.cell(CellIndex.indexByString("J1")).value = TextCellValue("Blok narxi");
      sheetObject.cell(CellIndex.indexByString("K1")).value = TextCellValue("Blok shtrix-kodi");

      var fileBytes = excel.save();
      String? outputPath = await FilePicker.platform.saveFile(
        fileName: "shablon_mahsulotlar.xlsx",
        allowedExtensions: ['xlsx'],
        type: FileType.custom,
      );

      if (outputPath != null) {
        File(outputPath)..createSync(recursive: true)..writeAsBytesSync(fileBytes!);
        _showSuccess(context, "Shablon saqlandi");
      }
    } catch (e) {
      _showError(context, "Xatolik: $e");
    }
  }

  static String _getCellValue(Data? data) {
    if (data == null || data.value == null) return '';
    var v = data.value;
    if (v is TextCellValue) return v.value.toString().trim();
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) {
      return AppFormatter.formatDouble(v.value.toDouble());
    }
    if (v is BoolCellValue) return v.value.toString();
    return v.toString().trim();
  }

  static double _parseRobustDouble(String val) {
    if (val.isEmpty) return 0.0;
    String clean = val.replaceAll(RegExp(r'[^0-9.,-]'), '').trim();
    if (clean.isEmpty) return 0.0;
    
    if (clean.contains(',') && clean.contains('.')) {
      if (clean.indexOf('.') < clean.indexOf(',')) {
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        clean = clean.replaceAll(',', '');
      }
    } else {
      clean = clean.replaceAll(',', '.');
    }
    
    return double.tryParse(clean) ?? 0.0;
  }

  static void _showError(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  static void _showSuccess(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.green));
  }
}
