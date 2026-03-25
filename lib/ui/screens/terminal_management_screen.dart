import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';

class TerminalManagementScreen extends StatelessWidget {
  const TerminalManagementScreen({super.key});

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
              'Kassa Terminallari',
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
            itemCount: state.registers.length,
            itemBuilder: (context, index) {
              final reg = state.registers[index];
              final warehouse = state.warehouses.firstWhere(
                (w) => w.id == reg.warehouseId,
                orElse: () => Warehouse(id: '', name: 'Noma\'lum'),
              );

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
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.storefront_rounded, color: Colors.blue),
                  ),
                  title: Text(
                    reg.name,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  subtitle: Text(
                    'ID: ${reg.id.substring(0, reg.id.length < 8 ? reg.id.length : 8)}${reg.id.length > 8 ? "..." : ""} \nOmbor: ${warehouse.name}',
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.edit_outlined, color: Colors.blue),
                        onPressed: () =>
                            _showRegisterDialog(context, state, register: reg),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _confirmDelete(context, state, reg),
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
        onPressed: () => _showRegisterDialog(context, state),
        backgroundColor: Theme.of(context).colorScheme.primary,
        icon: Icon(Icons.add, color: Colors.white),
        label: Text(
          'Yangi Kassa',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  void _showRegisterDialog(
    BuildContext context,
    AppState state, {
    Register? register,
  }) {
    final nameController = TextEditingController(text: register?.name);
    String? selectedWarehouseId =
        register?.warehouseId ??
        (state.warehouses.isNotEmpty ? state.warehouses.first.id : null);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            register == null ? 'Yangi Kassa' : 'Kassani Tahrirlash',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: 'Kassa nomi',
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedWarehouseId,
                  decoration: InputDecoration(
                    labelText: 'Biriktirilgan ombor',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: state.warehouses
                      .map(
                        (w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)),
                      )
                      .toList(),
                  onChanged: (val) =>
                      setDialogState(() => selectedWarehouseId = val),
                  validator: (val) =>
                      val == null ? 'Ombor tanlanishi shart' : null,
                ),
              ],
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
                if (nameController.text.isNotEmpty &&
                    selectedWarehouseId != null) {
                  if (register == null) {
                    state.addRegister(
                      nameController.text,
                      selectedWarehouseId!,
                    );
                  } else {
                    state.updateRegister(
                      register.id,
                      nameController.text,
                      selectedWarehouseId!,
                    );
                  }
                  Navigator.pop(context);
                }
              },
              child: Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, AppState state, Register register) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('O\'chirishni tasdiqlang'),
        content: Text('"${register.name}" kassasini o\'chirmoqchimisiz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Bekor qilish'),
          ),
          TextButton(
            onPressed: () {
              state.deleteRegister(register.id);
              Navigator.pop(context);
            },
            child: Text('O\'chirish', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
