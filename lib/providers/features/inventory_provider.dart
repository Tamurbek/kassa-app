import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class InventoryProvider extends ChangeNotifier {
  List<Category> categories = [];
  List<Product> products = [];
  List<Warehouse> warehouses = [];
  List<Register> registers = [];
  List<Organization> organizations = []; // Added for multi-org management
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

  // --- Filtered Accessors ---
  List<Category> get activeCategories => categories.where((c) => !c.isDeleted).toList();
  List<Category> get deletedCategories => categories.where((c) => c.isDeleted).toList();
  
  List<Product> get activeProducts => products.where((p) => !p.isDeleted).toList();
  List<Product> get deletedProducts => products.where((p) => p.isDeleted).toList();

  List<Warehouse> get activeWarehouses => warehouses.where((w) => !w.isDeleted).toList();
  List<Warehouse> get deletedWarehouses => warehouses.where((w) => w.isDeleted).toList();

  List<Register> get activeRegisters => registers.where((r) => !r.isDeleted).toList();
  List<Register> get deletedRegisters => registers.where((r) => r.isDeleted).toList();

  List<Organization> get activeOrganizations => organizations.where((o) => !o.isDeleted).toList();
  List<Organization> get deletedOrganizations => organizations.where((o) => o.isDeleted).toList();

  Warehouse? get mainWarehouse => activeWarehouses.where((w) => w.isMain).firstOrNull ?? (activeWarehouses.isNotEmpty ? activeWarehouses.first : null);

  Future<void> reloadData({bool forceRecalculate = false, bool skipRecalculate = false}) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      if (!skipRecalculate) {
        try {
          await DatabaseService.recalculateStocks(force: forceRecalculate, skipNotify: true);
        } catch (e) {
          debugPrint('Stock recalculation error: $e');
        }
      }

      categories = await DatabaseService.getCategories(); // getCategories filters deleted by default in repository
      products = await DatabaseService.getProducts(); // getProducts filters deleted by default
      
      // We use 'getAll' for internal lists so provider can manage active/deleted filtering
      warehouses = await DatabaseService.getAllWarehouses();
      registers = await DatabaseService.getAllRegisters();
      organizations = await DatabaseService.getOrganizations();
      
      stockEntries = await DatabaseService.getStockEntries();
      inventories = await DatabaseService.getInventories();
      transfers = await DatabaseService.getStockTransfers();
      
      // Also need to fetch ALL categories/products if we want them in Trash as well, 
      // but repos often filter them. We'll stick to active for now and fix repos if needed.
    } catch (e) {
      debugPrint('InventoryProvider reloadData error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // --- Warehouse Management ---
  Future<void> saveWarehouse(Warehouse warehouse) async {
    await DatabaseService.saveWarehouse(warehouse);
    await reloadData();
  }

  Future<void> deleteWarehouse(String id) async {
    await DatabaseService.deleteWarehouse(id);
    await reloadData();
  }

  Future<void> restoreWarehouse(String id) async {
    final w = warehouses.firstWhere((w) => w.id == id);
    await DatabaseService.saveWarehouse(Warehouse(
      id: w.id,
      name: w.name,
      isMain: w.isMain,
      isDeleted: false,
    ));
    await reloadData();
  }

  Future<void> setWarehouseAsMain(String id) async {
    for (var w in activeWarehouses) {
      final updated = Warehouse(id: w.id, name: w.name, isMain: w.id == id, isDeleted: w.isDeleted);
      await DatabaseService.saveWarehouse(updated);
    }
    await reloadData();
  }

  // --- Register Management ---
  Future<void> saveRegister(Register register) async {
    await DatabaseService.saveRegister(register);
    await reloadData();
  }

  Future<void> deleteRegister(String id) async {
    await DatabaseService.deleteRegister(id);
    await reloadData();
  }

  Future<void> restoreRegister(String id) async {
    final r = registers.firstWhere((r) => r.id == id);
    await DatabaseService.saveRegister(Register(
      id: r.id,
      name: r.name,
      warehouseId: r.warehouseId,
      activeDeviceId: r.activeDeviceId,
      isDeleted: false,
    ));
    await reloadData();
  }

  // --- Organization Management ---
  Future<void> saveOrganization(Organization org) async {
    await DatabaseService.saveOrganization(org);
    await reloadData();
  }

  Future<void> deleteOrganization(String id) async {
    await DatabaseService.deleteOrganization(id);
    await reloadData();
  }

  Future<void> restoreOrganization(String id) async {
    await DatabaseService.restoreOrganization(id);
    await reloadData();
  }

  Future<void> permanentDeleteOrganization(String id) async {
    await DatabaseService.permanentDeleteOrganization(id);
    await reloadData();
  }

  // --- Product & Category Management ---
  Future<List<Product>> getProductsPaged({int? limit, int? offset, String? search}) async {
    return DatabaseService.getProducts(limit: limit, offset: offset, searchQuery: search);
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

  Future<void> restoreProduct(String id) async {
    final p = products.firstWhere((p) => p.id == id);
    await DatabaseService.saveProduct(p.copyWith(isDeleted: false));
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

  Future<void> restoreCategory(String id) async {
    final c = categories.firstWhere((c) => c.id == id);
    await DatabaseService.saveCategory(c.copyWith(isDeleted: false));
    await reloadData();
  }

  // --- Stock & Inventory ---
  Future<void> addStockEntry(StockEntry entry) async {
    await DatabaseService.saveStockEntry(entry);
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
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    final core = timestamp.substring(timestamp.length - 10);
    return '200$core';
  }
}
