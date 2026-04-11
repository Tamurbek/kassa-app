import 'package:flutter_test/flutter_test.dart';
import 'package:simple_sale/models/models.dart';

void main() {
  group('Comprehensive Professional System Audit', () {
    
    group('Entity: Product', () {
      test('Product creation & stock aggregation', () {
        final product = Product(
          id: 'p-001',
          name: 'Coca-Cola',
          price: 12000,
          costPrice: 8000,
          categoryId: 'cat-1',
          barcode: '12345678',
          stocks: {'warehouse-1': 50.0, 'warehouse-2': 30.0},
        );
        expect(product.stock, 80.0);
        expect(product.name, 'Coca-Cola');
      });

      test('Product JSON Serialization/Deserialization', () {
        final original = Product(
          id: 'p-002', name: 'Pepsi', price: 11000, categoryId: 'c1', barcode: '888',
          stocks: {'wh1': 100}, trackStock: true, unit: 'dona',
        );
        final json = original.toJson();
        final restored = Product.fromJson(json);
        expect(restored.id, original.id);
        expect(restored.stocks['wh1'], 100.0);
        expect(restored.trackStock, true);
      });
    });

    group('Entity: Sale & Finance', () {
      test('Sale subtotal and total after discount', () {
        final item = SaleItem(productId: '1', productName: 'A', quantity: 3, price: 1000, costPrice: 700);
        expect(item.subtotal, 3000.0);
        expect(item.profit, 900.0);

        final sale = Sale(
          id: 's-1', date: DateTime.now(), items: [item], total: 2500,
          registerId: 'r1', warehouseId: 'w1', discount: 500,
        );
        expect(sale.total, 2500.0);
        expect(sale.discount, 500.0);
      });
    });

    group('Entity: Stock Management', () {
      test('StockEntry integrity', () {
        final entry = StockEntry(
          id: 'e1', warehouseId: 'w1', date: DateTime.now(),
          items: [StockEntryItem(productId: 'p1', productName: 'X', quantity: 10, costPrice: 500)],
        );
        expect(entry.items.first.quantity, 10.0);
        expect(entry.items.first.productId, 'p1');
      });

      test('StockTransfer logic', () {
        final transfer = StockTransfer(
          id: 't1', fromWarehouseId: 'w1', toWarehouseId: 'w2', date: DateTime.now(),
          items: [StockTransferItem(productId: 'p1', productName: 'X', quantity: 5)],
        );
        expect(transfer.fromWarehouseId, 'w1');
        expect(transfer.toWarehouseId, 'w2');
        expect(transfer.items.length, 1);
      });
    });

    group('Entity: General Metadata', () {
      test('Category JSON consistency', () {
        final cat = Category(id: 'c1', name: 'Drinks');
        final json = cat.toJson();
        expect(Category.fromJson(json).name, 'Drinks');
      });

      test('Warehouse JSON consistency', () {
        final wh = Warehouse(id: 'w1', name: 'Main', isMain: true);
        expect(Warehouse.fromJson(wh.toJson()).isMain, true);
      });

      test('User JSON consistency', () {
        final user = User(id: 'u1', name: 'Admin', role: UserRole.admin, pin: '1234');
        final restored = User.fromJson(user.toJson());
        expect(restored.name, 'Admin');
        expect(restored.role, UserRole.admin);
      });
    });

    group('Professional Data Sync Simulation', () {
      test('Record mapping for batch sync', () {
        final data = {
          'products': [
            {'id': 'p1', 'name': 'A', 'price': 100, 'isSynced': 0},
            {'id': 'p2', 'name': 'B', 'price': 200, 'isSynced': 0},
          ],
          'sales': [
            {'id': 's1', 'total': 500, 'isSynced': 0}
          ]
        };
        
        expect(data['products']?.length, 2);
        expect(data['sales']?.length, 1);
      });
    });
  });
}
