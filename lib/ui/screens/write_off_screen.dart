import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../models/models.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/sales_provider.dart';
import '../../providers/app_state.dart';

class WriteOffScreen extends StatefulWidget {
  final WriteOff? writeOff;

  const WriteOffScreen({super.key, this.writeOff});

  @override
  State<WriteOffScreen> createState() => _WriteOffScreenState();
}

class _WriteOffScreenState extends State<WriteOffScreen> {
  String? woWarehouseId;
  final TextEditingController descCtrl = TextEditingController();
  final List<Map<String, dynamic>> items = [];
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final inventory = context.read<InventoryProvider>();

    if (widget.writeOff != null) {
      woWarehouseId = widget.writeOff!.warehouseId;
      descCtrl.text = widget.writeOff!.description;
      selectedDate = widget.writeOff!.date;
      for (var item in widget.writeOff!.items) {
        items.add({
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
        });
      }
    } else {
      woWarehouseId = inventory.mainWarehouse?.id ?? (inventory.warehouses.isNotEmpty ? inventory.warehouses.first.id : null);
    }
  }

  @override
  void dispose() {
    descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(selectedDate),
      );
      if (time != null) {
        setState(() {
          selectedDate = DateTime(date.year, date.month, date.day, time.hour, time.minute);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          color: Theme.of(context).cardColor,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: AppBar(
                title: Text(widget.writeOff == null ? 'Yangi Chiqit' : 'Chiqitni Tahrirlash', 
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  IconButton(icon: const Icon(Icons.save_rounded), onPressed: _save),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  children: [
                    DropdownButtonFormField<String>(
                      value: woWarehouseId,
                      decoration: const InputDecoration(labelText: 'Ombor', border: OutlineInputBorder(), prefixIcon: Icon(Icons.store_rounded)),
                      items: inventory.warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                      onChanged: (val) => setState(() => woWarehouseId = val),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _pickDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Sana va vaqt', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today_rounded)),
                        child: Text(DateFormat('dd.MM.yyyy HH:mm').format(selectedDate)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Sababi/Tavsif', border: OutlineInputBorder(), prefixIcon: Icon(Icons.comment_rounded)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text('Mahsulotlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 16),
              ...items.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          value: item['productId'],
                          decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                          hint: const Text('Tanlang'),
                          items: inventory.activeProducts.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            final p = inventory.activeProducts.firstWhere((p) => p.id == val);
                            setState(() {
                              items[idx]['productId'] = val;
                              items[idx]['productName'] = p.name;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextFormField(
                          initialValue: item['quantity'] == 0 ? '' : item['quantity'].toString(),
                          decoration: const InputDecoration(hintText: 'Soni', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                          keyboardType: TextInputType.number,
                          onChanged: (val) => items[idx]['quantity'] = double.tryParse(val) ?? 0,
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.red), onPressed: () => setState(() => items.removeAt(idx))),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => setState(() => items.add({'productId': null, 'productName': '', 'quantity': 0.0})),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Mahsulot qo\'shish'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent, side: const BorderSide(color: Colors.redAccent)),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('SAQLASH', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final sales = context.read<SalesProvider>();
    if (woWarehouseId == null) return;

    final finalItems = items.where((i) => i['productId'] != null && (i['quantity'] as num) > 0).map((i) => WriteOffItem(productId: i['productId'], productName: i['productName'], quantity: (i['quantity'] as num).toDouble())).toList();
    if (finalItems.isEmpty) return;

    final entry = WriteOff(
      id: widget.writeOff?.id ?? const Uuid().v4(),
      warehouseId: woWarehouseId!,
      date: selectedDate,
      description: descCtrl.text,
      items: finalItems,
    );

    try {
      final inventory = context.read<InventoryProvider>();
      final appState = context.read<AppState>();
      
      await sales.addWriteOff(entry);
      
      await inventory.reloadData();
      await appState.reloadData();
      
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
    }
  }
}
