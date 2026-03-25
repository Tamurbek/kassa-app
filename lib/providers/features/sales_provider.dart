import 'package:flutter/material.dart';
import '../../models/models.dart';
import '../../services/database_service.dart';

class SalesProvider extends ChangeNotifier {
  List<Sale> sales = [];
  List<SaleReturn> returns = [];
  List<WriteOff> writeOffs = [];
  
  List<SaleItem> cart = [];
  
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  double get todaySalesTotal {
    final now = DateTime.now();
    return sales
        .where(
          (s) =>
              s.date.year == now.year &&
              s.date.month == now.month &&
              s.date.day == now.day,
        )
        .fold(0.0, (sum, s) => sum + s.total);
  }

  double get todayProfitTotal {
    final now = DateTime.now();
    return sales
        .where(
          (s) =>
              s.date.year == now.year &&
              s.date.month == now.month &&
              s.date.day == now.day,
        )
        .fold(0.0, (sum, s) => sum + s.items.fold(0.0, (iSum, item) => iSum + item.profit));
  }

  int get todaySalesCount {
    final now = DateTime.now();
    return sales
        .where(
          (s) =>
              s.date.year == now.year &&
              s.date.month == now.month &&
              s.date.day == now.day,
        )
        .length;
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

  double get cartTotal => cart.fold(0, (sum, item) => sum + (item.price * item.quantity));
  double get cartProfit => cart.fold(0, (sum, item) => sum + item.profit);

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
    notifyListeners();
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
    );

    await DatabaseService.saveSale(sale);
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
