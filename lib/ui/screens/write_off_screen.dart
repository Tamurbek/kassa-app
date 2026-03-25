import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
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
    final state = context.read<AppState>();

    if (widget.writeOff != null) {
      woWarehouseId = widget.writeOff!.warehouseId;
      descCtrl.text = widget.writeOff!.description ?? '';
      selectedDate = widget.writeOff!.date;
      for (var item in widget.writeOff!.items) {
        items.add({
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
        });
      }
    } else {
      if (state.warehouses.isNotEmpty) {
        woWarehouseId = state.warehouses.first.id;
      }
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
          selectedDate = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.writeOff == null
              ? 'Yangi Hisobdan Chiqarish (Spisaniye)'
              : 'Spisaniyeni Tahrirlash',
        ),
        actions: [
          IconButton(icon: Icon(Icons.save), onPressed: _save),
          SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: woWarehouseId,
                          decoration: const InputDecoration(
                            labelText: 'Ombor',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.store),
                          ),
                          items: state.warehouses
                              .map(
                                (w) => DropdownMenuItem(
                                  value: w.id,
                                  child: Text(w.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => setState(() => woWarehouseId = val),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: _pickDate,
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Sana va vaqt',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(selectedDate.toString().substring(0, 16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Sababi/Tavsif',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.comment),
                    ),
                  ),
                  SizedBox(height: 24),
                  const Divider(),
                  SizedBox(height: 16),
                  Text(
                    'Mahsulotlar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  SizedBox(height: 16),
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
                              decoration: InputDecoration(
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              hint: Text('Tanlang'),
                              items: state.activeProducts
                                  .map(
                                    (p) => DropdownMenuItem(
                                      value: p.id,
                                      child: Text(p.name),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val == null) return;
                                final p = state.activeProducts.firstWhere(
                                  (p) => p.id == val,
                                );
                                setState(() {
                                  items[idx]['productId'] = val;
                                  items[idx]['productName'] = p.name;
                                });
                              },
                            ),
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: TextFormField(
                              initialValue: item['quantity'] == 0
                                  ? ''
                                  : item['quantity'].toString(),
                              decoration: const InputDecoration(
                                hintText: 'Soni',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (val) => items[idx]['quantity'] =
                                  double.tryParse(val) ?? 0,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.remove_circle, color: Colors.red),
                            onPressed: () => setState(() => items.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }),
                  SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => setState(
                      () => items.add({
                        'productId': null,
                        'productName': '',
                        'quantity': 0.0,
                      }),
                    ),
                    icon: Icon(Icons.add),
                    label: Text('Mahsulot qo\'shish'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.1),
                      foregroundColor: Colors.redAccent,
                      elevation: 0,
                    ),
                  ),
                  SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                      ),
                      child: Text(
                        'Saqlash',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    final state = context.read<AppState>();
    if (woWarehouseId == null) return;

    final finalItems = items
        .where((i) => i['productId'] != null && i['quantity'] > 0)
        .map(
          (i) => WriteOffItem(
            productId: i['productId'],
            productName: i['productName'],
            quantity: i['quantity'],
          ),
        )
        .toList();

    if (finalItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Kamida 1 ta mahsulot kiriting!')));
      return;
    }

    final entry = WriteOff(
      id: widget.writeOff?.id ?? Uuid().v4(),
      warehouseId: woWarehouseId!,
      date: selectedDate,
      description: descCtrl.text,
      items: finalItems,
    );

    if (widget.writeOff == null) {
      state.addWriteOff(entry);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hisobdan chiqarish saqlandi')));
    } else {
      state.updateWriteOff(entry);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Hisobdan chiqarish tahrirlandi')));
    }

    Navigator.pop(context);
  }
}
