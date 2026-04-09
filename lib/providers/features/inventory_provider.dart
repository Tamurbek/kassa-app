import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class InventoryProvider extends ChangeNotifier {
  List<Category> categories = [];
  List<Product> products = [];
  List<Warehouse> warehouses = [];
  List<StockEntry> stockEntries = [];
  List<InventoryEntry> inventories = [];
  List<StockTransfer> transfers = [];
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  StreamSubscription<void>? _dbSubscription;

  InventoryProvider() {
    _dbSubscription = DatabaseService.dbUpdateStream.stream.listen((_) {
      debugPrint("InventoryProvider: Background data change detected. Reloading...");
      reloadData();
    });
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    super.dispose();
  }

  List<Category> get activeCategories => categories.where((c) => !c.isDeleted).toList();
  List<Category> get deletedCategories => categories.where((c) => c.isDeleted).toList();
  List<Product> get activeProducts => products.where((p) => !p.isDeleted).toList();
  List<Product> get deletedProducts => products.where((p) => p.isDeleted).toList();

  Warehouse? get mainWarehouse => warehouses.where((w) => w.isMain).firstOrNull ?? (warehouses.isNotEmpty ? warehouses.first : null);

  Future<void> addStockEntry(StockEntry entry) async {
    await DatabaseService.saveStockEntry(entry);
    await reloadData();
  }

  Future<void> reloadData({bool forceRecalculate = false, bool skipRecalculate = false}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      if (!skipRecalculate) {
        // Force recalculate stocks if requested (e.g. from cloud sync or manual fix)
        try {
          await DatabaseService.recalculateStocks(force: forceRecalculate);
        } catch (e) {
          debugPrint('Stock recalculation error: $e');
        }
      }

      categories = await DatabaseService.getCategories();
      products = await DatabaseService.getProducts();
      warehouses = await DatabaseService.getWarehouses();
      stockEntries = await DatabaseService.getStockEntries();
      inventories = await DatabaseService.getInventories();
      transfers = await DatabaseService.getStockTransfers();
    } catch (e) {
      debugPrint('InventoryProvider reloadData error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveProduct(Product product) async {
    await DatabaseService.saveProduct(product);
    await reloadData();
  }

  Future<void> saveProductsBatch(List<Product> products, {bool skipRecalculate = false}) async {
    await DatabaseService.saveProductsBatch(products);
    await reloadData(skipRecalculate: skipRecalculate);
  }

  Future<void> deleteProduct(String id) async {
    await DatabaseService.deleteProduct(id);
    await reloadData();
  }

  Future<void> saveCategory(Category category) async {
    await DatabaseService.saveCategory(category);
    await reloadData();
  }

  Future<void> deleteCategory(String id) async {
     await DatabaseService.deleteCategory(id);
     await reloadData();
  }

  Future<void> addInventory(InventoryEntry entry) async {
    await DatabaseService.saveInventory(entry);
    await reloadData();
  }

  Future<void> updateInventory(InventoryEntry entry) async {
    await DatabaseService.saveInventory(entry);
    await reloadData();
  }

  Future<void> restoreProduct(String id) async {
    final p = products.firstWhere((p) => p.id == id);
    await DatabaseService.saveProduct(p.copyWith(isDeleted: false));
    await reloadData();
  }

  Future<void> restoreCategory(String id) async {
    final c = categories.firstWhere((c) => c.id == id);
    await DatabaseService.saveCategory(c.copyWith(isDeleted: false));
    await reloadData();
  }

  Future<void> deleteStockEntry(String id) async {
    await DatabaseService.deleteStockEntry(id);
    await reloadData();
  }

  Future<void> deleteInventory(String id) async {
    await DatabaseService.deleteInventory(id);
    await reloadData();
  }

  Future<void> saveStockTransfer(StockTransfer transfer) async {
    await DatabaseService.saveStockTransfer(transfer);
    await reloadData();
  }

  Future<void> deleteStockTransfer(String id) async {
    await DatabaseService.deleteStockTransfer(id);
    await reloadData();
  }

  String generateBarcode() {
    // Generate a simple unique barcode (e.g. internal use)
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    final core = timestamp.substring(timestamp.length - 10);
    return '200$core';
  }
}
