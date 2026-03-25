import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';

class WarehouseManagementScreen extends StatelessWidget {
  const WarehouseManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/icon.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Omborlar Boshqaruvi',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        centerTitle: true,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: ListView.builder(
            padding: const EdgeInsets.all(24),
            itemCount: state.warehouses.length,
            itemBuilder: (context, index) {
              final warehouse = state.warehouses[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(
                        Theme.of(context).brightness == Brightness.dark
                            ? 0.3
                            : 0.02,
                      ),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.warehouse_rounded, color: Colors.orange),
                  ),
                  title: Row(
                    children: [
                      Text(
                        warehouse.name,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      if (warehouse.isMain) ...[
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Asosiy',
                            style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    'ID: ${warehouse.id.substring(0, warehouse.id.length < 8 ? warehouse.id.length : 8)}${warehouse.id.length > 8 ? "..." : ""}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!warehouse.isMain)
                        IconButton(
                          icon: Icon(Icons.star_outline_rounded, color: Colors.orange),
                          tooltip: 'Asosiy ombor qilib belgilash',
                          onPressed: () => state.setWarehouseAsMain(warehouse.id),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.star_rounded, color: Colors.orange),
                        ),
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () => _showWarehouseDialog(
                          context,
                          state,
                          warehouse: warehouse,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _confirmDelete(context, state, warehouse),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWarehouseDialog(context, state),
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Yangi Ombor',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showWarehouseDialog(
    BuildContext context,
    AppState state, {
    Warehouse? warehouse,
  }) {
    final nameController = TextEditingController(text: warehouse?.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          warehouse == null ? 'Yangi Ombor' : 'Omborni Tahrirlash',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Ombor nomi',
            filled: true,
            fillColor: Theme.of(context).colorScheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Bekor qilish'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                if (warehouse == null) {
                  state.addWarehouse(nameController.text);
                } else {
                  state.updateWarehouse(warehouse.id, nameController.text);
                }
                Navigator.pop(context);
              }
            },
            child: Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    AppState state,
    Warehouse warehouse,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('O\'chirishni tasdiqlang'),
        content: Text('"${warehouse.name}" omborini o\'chirmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () {
              state.deleteWarehouse(warehouse.id);
              Navigator.pop(context);
            },
            child: Text('O\'chirish', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
