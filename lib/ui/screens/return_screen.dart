import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/sales_provider.dart';
import '../../providers/features/auth_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../widgets/app_status_bar.dart';
import '../widgets/custom_app_bar.dart';
import '../../providers/app_state.dart';
import '../../core/utils/responsive.dart';

class ReturnScreen extends StatefulWidget {
  final SaleReturn? saleReturn;

  const ReturnScreen({super.key, this.saleReturn});

  @override
  State<ReturnScreen> createState() => _ReturnScreenState();
}

class _ReturnScreenState extends State<ReturnScreen> {
  String? returnWarehouseId;
  final TextEditingController saleIdCtrl = TextEditingController();
  final List<Map<String, dynamic>> items = [];
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final inventory = context.read<InventoryProvider>();

    if (widget.saleReturn != null) {
      returnWarehouseId = widget.saleReturn!.warehouseId;
      saleIdCtrl.text = widget.saleReturn!.saleId;
      selectedDate = widget.saleReturn!.date;
      for (var item in widget.saleReturn!.items) {
        items.add({
          'productId': item.productId,
          'productName': item.productName,
          'quantity': item.quantity,
          'price': item.price,
        });
      }
    } else {
      if (inventory.warehouses.isNotEmpty) {
        returnWarehouseId = inventory.mainWarehouse?.id ?? inventory.warehouses.first.id;
      }
    }
  }

  @override
  void dispose() {
    saleIdCtrl.dispose();
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
    final bool isShort = Responsive.isShort(context);
    final inventory = context.watch<InventoryProvider>();
    final sales = context.watch<SalesProvider>();

    final auth = context.watch<AuthProvider>();
    final settingsProv = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: widget.saleReturn == null ? 'Yangi Vazvrat' : 'Vazvratni Tahrirlash',
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: Theme.of(context).colorScheme.primary,
        ),
        actions: [
          IconButton(
            icon: Icon(_isSaving ? Icons.sync_rounded : Icons.save_rounded, color: Colors.orange), 
            onPressed: _isSaving ? null : _save
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: ListView(
                  padding: EdgeInsets.all(isShort ? 12.sp : 24.sp),
                  children: [
                    Container(
                      padding: EdgeInsets.all(isShort ? 16.sp : 24.sp),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            value: returnWarehouseId,
                            decoration: const InputDecoration(labelText: 'Qaysi omborga qaytadi?', border: OutlineInputBorder(), prefixIcon: Icon(Icons.store_rounded)),
                            items: inventory.warehouses.map((w) => DropdownMenuItem(value: w.id, child: Text(w.name))).toList(),
                            onChanged: (val) => setState(() => returnWarehouseId = val),
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
                            controller: saleIdCtrl,
                            decoration: const InputDecoration(labelText: 'Sotuv ID (ixtiyoriy)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.receipt_long_rounded)),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isShort ? 16.h : 32.h),
                    Text('Mahsulotlar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp)),
                    SizedBox(height: isShort ? 8.h : 16.h),
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
                                    items[idx]['price'] = p.price;
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
                            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.orange), onPressed: () => setState(() => items.removeAt(idx))),
                          ],
                        ),
                      );
                    }),
                    SizedBox(height: isShort ? 8.h : 16.h),
                    OutlinedButton.icon(
                      onPressed: () => setState(() => items.add({'productId': null, 'productName': '', 'quantity': 0.0, 'price': 0.0})),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Mahsulot qo\'shish'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange, 
                        side: const BorderSide(color: Colors.orange),
                        padding: EdgeInsets.symmetric(vertical: isShort ? 10.h : 16.h),
                      ),
                    ),
                    SizedBox(height: isShort ? 16.h : 32.h),
                    SizedBox(
                      width: double.infinity,
                      height: isShort ? 44.h : 54.h,
                      child: ElevatedButton(
                        onPressed: _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange, 
                          foregroundColor: Colors.white, 
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: _isSaving 
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Text('VAZVRATNI SAQLASH', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 14.sp)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isSaving = false;
  Future<void> _save() async {
    if (_isSaving) return;
    final sales = context.read<SalesProvider>();
    if (returnWarehouseId == null) return;

    final finalItems = items.where((i) => i['productId'] != null && (i['quantity'] as num) > 0).map((i) => SaleReturnItem(productId: i['productId'], productName: i['productName'], quantity: (i['quantity'] as num).toDouble(), price: (i['price'] as num).toDouble())).toList();
    if (finalItems.isEmpty) return;

    setState(() => _isSaving = true);
    double total = finalItems.fold(0, (sum, i) => sum + (i.price * i.quantity));

    final entry = SaleReturn(
      id: widget.saleReturn?.id ?? const Uuid().v4(),
      warehouseId: returnWarehouseId!,
      date: selectedDate,
      saleId: saleIdCtrl.text.isEmpty ? 'HAND_RETURN' : saleIdCtrl.text,
      items: finalItems,
      total: total,
    );

    try {
      await sales.saveReturn(entry);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Xatolik: $e')));
      }
    }
  }
}
