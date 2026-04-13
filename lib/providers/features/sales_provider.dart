import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class SalesProvider extends ChangeNotifier {
  List<Sale> sales = [];
  List<SaleReturn> returns = [];
  List<WriteOff> writeOffs = [];
  List<SuspendedSale> suspendedSales = [];
  
  List<SaleItem> cart = [];
  double _cartDiscount = 0.0;
  String? _cartCustomerId;
  String? _cartCustomerName;
  String? _resumedSuspendedId;

  String? get resumedSuspendedId => _resumedSuspendedId;

  double get cartDiscount => _cartDiscount;
  String? get cartCustomerId => _cartCustomerId;
  String? get cartCustomerName => _cartCustomerName;
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  StreamSubscription<void>? _dbSubscription;

  SalesProvider() {
    _dbSubscription = DatabaseService.dbUpdateStream.stream.listen((_) {
      debugPrint("SalesProvider: Background data change detected. Reloading...");
      reloadSalesData();
    });
    reloadSalesData();
  }

  @override
  void dispose() {
    _dbSubscription?.cancel();
    super.dispose();
  }

  double get todaySalesTotal {
    final now = DateTime.now();
    final daySales = sales.where(
      (s) =>
          s.date.year == now.year &&
          s.date.month == now.month &&
          s.date.day == now.day,
    ).fold(0.0, (sum, s) => sum + s.total);

    final dayReturns = returns.where(
      (r) =>
          r.date.year == now.year &&
          r.date.month == now.month &&
          r.date.day == now.day,
    ).fold(0.0, (sum, r) => sum + r.total);

    return daySales - dayReturns;
  }

  double get todayProfitTotal {
    final now = DateTime.now();
    final dayProfit = sales.where(
      (s) =>
          s.date.year == now.year &&
          s.date.month == now.month &&
          s.date.day == now.day,
    ).fold(0.0, (sum, s) => sum + s.items.fold(0.0, (iSum, item) => iSum + item.profit));

    final dayReturnProfit = returns.where(
      (r) =>
          r.date.year == now.year &&
          r.date.month == now.month &&
          r.date.day == now.day,
    ).fold(0.0, (sum, r) => sum + r.items.fold(0.0, (iSum, item) => iSum + item.profit));

    return dayProfit - dayReturnProfit;
  }

  int get todaySalesCount {
    final now = DateTime.now();
    final daySalesCount = sales.where(
      (s) =>
          s.date.year == now.year &&
          s.date.month == now.month &&
          s.date.day == now.day,
    ).length;

    final dayReturnsCount = returns.where(
      (r) =>
          r.date.year == now.year &&
          r.date.month == now.month &&
          r.date.day == now.day,
    ).length;

    return daySalesCount - dayReturnsCount;
  }

  double get averageCheck {
    final count = todaySalesCount;
    return count == 0 ? 0 : todaySalesTotal / count;
  }

  List<MapEntry<String, double>> get topSellingProducts {
    final now = DateTime.now();
    final todaySales = sales.where(
      (s) =>
          s.date.year == now.year &&
          s.date.month == now.month &&
          s.date.day == now.day,
    );

    final Map<String, double> topMap = {};
    for (var sale in todaySales) {
      for (var item in sale.items) {
        topMap[item.productName] =
            (topMap[item.productName] ?? 0.0) + item.quantity;
      }
    }

    final sorted = topMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }

  double get cartTotal => (cart.fold(0.0, (sum, item) => sum + (item.price * item.quantity))) - _cartDiscount;
  double get cartProfit => cart.fold(0.0, (sum, item) => sum + item.profit);
  double get cartSubtotal => cart.fold(0.0, (sum, item) => sum + (item.price * item.quantity));

  void addToCart(Product product, {String? warehouseId}) {
    // Check if product tracks stock and has 0 quantity for the selected warehouse
    // OR if no warehouse selected and stock is 0
    final stock = product.stocks[warehouseId] ?? 0;
    
    if (product.trackStock && stock <= 0) {
      if (warehouseId == null) {
        throw Exception('Ombor tanlanmagan va mahsulot qoldig\'i 0');
      } else {
        throw Exception('Ushbu omborda mahsulot qoldig\'i 0');
      }
    }

    final existingIndex = cart.indexWhere((item) => item.productId == product.id);
    
    if (existingIndex != -1) {
      final item = cart[existingIndex];
      // Also check if we have enough stock for the increment
      if (product.trackStock && (item.quantity + 1) > stock) {
        throw Exception('Omborda yetarli mahsulot yo\'q');
      }

      cart[existingIndex] = item.copyWith(
        quantity: item.quantity + 1,
      );
    } else {
      cart.add(SaleItem(
        productId: product.id,
        productName: product.name,
        quantity: 1,
        price: product.price,
        costPrice: product.costPrice,
      ));
    }
    notifyListeners();
  }

  void addToCartByBarcode(String barcode, List<Product> products, {String? warehouseId}) {
    try {
      final product = products.firstWhere(
        (p) => p.barcode == barcode || p.additionalBarcodes.contains(barcode),
      );
      addToCart(product, warehouseId: warehouseId);
    } catch (e) {
      if (e.toString().contains('Exception:')) {
        rethrow;
      }
      throw Exception('Mahsulot topilmadi: $barcode');
    }
  }

  void removeFromCart(String productId) {
    cart.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  void updateCartQuantity(String productId, double quantity, {Product? product, String? warehouseId}) {
    final index = cart.indexWhere((item) => item.productId == productId);
    if (index != -1) {
      if (quantity <= 0) {
        cart.removeAt(index);
      } else {
        if (product != null && product.trackStock) {
          final stock = product.stocks[warehouseId] ?? 0;
          if (quantity > stock) {
            if (warehouseId == null) {
              throw Exception('Ombor tanlanmagan va mahsulot qoldig\'i 0');
            }
            throw Exception('Omborda yetarli mahsulot yo\'q (Mavjud: $stock ${product.unit})');
          }
        }
        
        final item = cart[index];
        cart[index] = item.copyWith(
          quantity: quantity,
        );
      }
      notifyListeners();
    }
  }

  void clearCart() {
    cart.clear();
    _cartDiscount = 0.0;
    _cartCustomerId = null;
    _cartCustomerName = null;
    _resumedSuspendedId = null;
    notifyListeners();
  }

  void setCartDiscount(double discount) {
    _cartDiscount = discount;
    notifyListeners();
  }

  void setCartCustomer(String? id, String? name) {
    _cartCustomerId = id;
    _cartCustomerName = name;
    notifyListeners();
  }

  Future<void> suspendCurrentCart({String? note}) async {
    if (cart.isEmpty) return;
    final suspendedSale = SuspendedSale(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: DateTime.now(),
      items: List.from(cart),
      total: cartTotal,
      note: note,
    );
    await DatabaseService.saveSuspendedSale(suspendedSale);

    // If this was a resumed sale, delete the OLD record now
    if (_resumedSuspendedId != null) {
      await DatabaseService.deleteSuspendedSale(_resumedSuspendedId!);
      _resumedSuspendedId = null;
    }

    clearCart();
    await reloadSuspendedSales();
  }

  Future<void> resumeSuspendedSale(SuspendedSale suspendedSale) async {
    // Fill cart with suspended items
    cart = List.from(suspendedSale.items);
    _resumedSuspendedId = suspendedSale.id;
    // We DON'T delete from DB yet, to prevent loss if app crashes or user backs out
    notifyListeners();
  }

  Future<void> reloadSuspendedSales() async {
    suspendedSales = await DatabaseService.getSuspendedSales();
    notifyListeners();
  }

  Future<void> deleteSuspendedSale(String id) async {
    await DatabaseService.deleteSuspendedSale(id);
    await reloadSuspendedSales();
  }

  Future<void> checkout({
    required String? registerId,
    required String? warehouseId,
  }) async {
    if (cart.isEmpty) throw Exception('Savat bo\'sh');

    final sale = Sale(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      items: List.from(cart),
      total: cartTotal,
      date: DateTime.now(),
      registerId: registerId ?? 'unknown',
      warehouseId: warehouseId ?? 'unknown',
      discount: _cartDiscount,
      customerId: _cartCustomerId,
      customerName: _cartCustomerName,
    );

    await DatabaseService.saveSale(sale);
    
    // If this was a resumed sale, delete it from suspended table now
    if (_resumedSuspendedId != null) {
      await DatabaseService.deleteSuspendedSale(_resumedSuspendedId!);
      _resumedSuspendedId = null;
    }
    
    clearCart();
    await reloadSalesData();
  }

  Future<void> processReturn({
    required String? registerId,
    required String? warehouseId,
  }) async {
    if (cart.isEmpty) throw Exception('Savat bo\'sh');

    final saleReturn = SaleReturn(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      saleId: '', // Direct return from cart
      date: DateTime.now(),
      items: cart.map((item) => SaleReturnItem(
        productId: item.productId,
        productName: item.productName,
        quantity: item.quantity,
        price: item.price,
      )).toList(),
      total: cartTotal,
      warehouseId: warehouseId ?? 'unknown',
    );

    await DatabaseService.saveReturn(saleReturn);
    clearCart();
    await reloadSalesData();
  }

  Future<void> reloadSalesData() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      sales = await DatabaseService.getSales();
      returns = await DatabaseService.getReturns();
      writeOffs = await DatabaseService.getWriteOffs();
      suspendedSales = await DatabaseService.getSuspendedSales();
    } catch (e) {
      debugPrint('SalesProvider reloadData error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> saveSale(Sale sale) async {
    await DatabaseService.saveSale(sale);
    await reloadSalesData();
  }

  Future<void> saveReturn(SaleReturn saleReturn) async {
    await DatabaseService.saveReturn(saleReturn);
    await reloadSalesData();
  }

  Future<void> addReturn(SaleReturn saleReturn) => saveReturn(saleReturn);

  Future<void> deleteReturn(String id) async {
    await DatabaseService.deleteReturn(id);
    await reloadSalesData();
  }

  Future<void> addWriteOff(WriteOff writeOff) async {
    await DatabaseService.saveWriteOff(writeOff);
    await reloadSalesData();
  }

  Future<void> deleteWriteOff(String id) async {
    await DatabaseService.deleteWriteOff(id);
    await reloadSalesData();
  }
}
