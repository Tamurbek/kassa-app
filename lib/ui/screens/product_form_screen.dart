import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/features/inventory_provider.dart';
import '../../core/utils/formatter.dart';
import '../../providers/features/settings_provider.dart';
import '../widgets/app_button.dart';
import '../../services/print_service.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _costPriceController;
  late TextEditingController _barcodeController;
  late TextEditingController _quantityInBoxController;
  late TextEditingController _boxPriceController;
  late TextEditingController _boxBarcodeController;
  String? _selectedCategoryId;
  bool _trackStock = true;
  List<TextEditingController> _additionalBarcodeControllers = [];
  List<TextEditingController> _additionalBoxBarcodeControllers = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(text: widget.product?.price == 0 ? '' : widget.product?.price.toString());
    _costPriceController = TextEditingController(text: widget.product?.costPrice == 0 ? '' : widget.product?.costPrice.toString());
    _barcodeController = TextEditingController(
      text: widget.product?.barcode ?? '',
    );
    _quantityInBoxController = TextEditingController(
      text: AppFormatter.formatDouble(widget.product?.quantityInBox ?? 1.0),
    );
    _boxPriceController = TextEditingController(
      text: widget.product?.boxPrice?.toString() ?? '',
    );
    _boxBarcodeController = TextEditingController(
      text: widget.product?.boxBarcode ?? '',
    );
    _selectedCategoryId = widget.product?.categoryId;
    _trackStock = widget.product?.trackStock ?? true;
    _additionalBarcodeControllers = (widget.product?.additionalBarcodes ?? [])
        .map((b) => TextEditingController(text: b))
        .toList();
    _additionalBoxBarcodeControllers = (widget.product?.additionalBoxBarcodes ?? [])
        .map((b) => TextEditingController(text: b))
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _barcodeController.dispose();
    for (var c in _additionalBarcodeControllers) {
      c.dispose();
    }
    for (var c in _additionalBoxBarcodeControllers) {
      c.dispose();
    }
    super.dispose();
  }


  void _save() async {
    if (_formKey.currentState!.validate()) {
      final inventory = context.read<InventoryProvider>();

      if (_selectedCategoryId == null && inventory.categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avval kategoriya yarating')),
        );
        return;
      }

      if (_selectedCategoryId == null && inventory.categories.isNotEmpty) {
        _selectedCategoryId = inventory.categories.first.id;
      }

      final name = _nameController.text;
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final costPrice = double.tryParse(_costPriceController.text) ?? 0.0;
      final barcode = _barcodeController.text.trim();
      final quantityInBox = double.tryParse(_quantityInBoxController.text) ?? 1.0;
      final boxPrice = double.tryParse(_boxPriceController.text);
      final boxBarcode = _boxBarcodeController.text.trim();
      
      final additionalBarcodes = _additionalBarcodeControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final additionalBoxBarcodes = _additionalBoxBarcodeControllers
          .map((c) => c.text.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      // Check all barcodes uniqueness (primary, additional unit, primary box, additional box)
      List<String> allToCheck = [barcode, ...additionalBarcodes, boxBarcode, ...additionalBoxBarcodes]
          .where((b) => b.isNotEmpty).toList();

      for (var b in allToCheck) {
        final exists = inventory.activeProducts.where((p) => 
          (p.barcode == b || p.additionalBarcodes.contains(b) || 
           p.boxBarcode == b || p.additionalBoxBarcodes.contains(b)) && 
          p.id != widget.product?.id
        ).isNotEmpty;
        
        if (exists) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Shtrix-kod bazada mavjud: $b'), backgroundColor: Colors.red),
          );
          return;
        }
      }

      final Product product;
      if (widget.product != null) {
        product = widget.product!.copyWith(
          name: name,
          categoryId: _selectedCategoryId ?? '',
          barcode: barcode,
          additionalBarcodes: additionalBarcodes,
          additionalBoxBarcodes: additionalBoxBarcodes,
          trackStock: _trackStock,
          quantityInBox: quantityInBox,
          boxPrice: boxPrice,
          boxBarcode: boxBarcode,
        );
      } else {
        product = Product.create(
          name,
          price,
          _selectedCategoryId ?? '',
          barcode.isEmpty ? inventory.generateBarcode() : barcode,
          costPrice: costPrice,
          trackStock: _trackStock,
          quantityInBox: quantityInBox,
          boxPrice: boxPrice,
          boxBarcode: boxBarcode,
        ).copyWith(
          additionalBarcodes: additionalBarcodes,
          additionalBoxBarcodes: additionalBoxBarcodes,
        );
      }

      await inventory.saveProduct(product);
      if (mounted) Navigator.pop(context, product);
    }
  }

  void _showAddCategoryDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yangi Kategoriya'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Kategoriya nomi',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('BEKOR QILISH'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                final category = Category.create(name);
                await context.read<InventoryProvider>().saveCategory(category);
                setState(() {
                  _selectedCategoryId = category.id;
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('SAQLASH'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final settings = context.watch<SettingsProvider>();

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
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        'assets/icon.png',
                        width: 30,
                        height: 30,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(widget.product == null ? 'Yangi Mahsulot' : 'Tahrirlash'),
                  ],
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                centerTitle: true,
              ),
            ),
          ),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 32),
                  _buildTextField(
                    'Mahsulot nomi',
                    _nameController,
                    Icons.inventory_2_outlined,
                  ),
                  SizedBox(height: 20),
                  _buildCategoryDropdown(inventory),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Tan narxi',
                          _costPriceController,
                          Icons.shopping_cart_outlined,
                          isNumber: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          'Sotish narxi',
                          _priceController,
                          Icons.sell_outlined,
                          isNumber: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Shtrix-kod',
                          _barcodeController,
                          Icons.qr_code_scanner_outlined,
                          isRequired: false,
                          suffix: IconButton(
                            icon: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
                            tooltip: 'Generatsiya qilish',
                            onPressed: () {
                              setState(() {
                                _barcodeController.text = inventory.generateBarcode();
                              });
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  _buildAdditionalBarcodes(),
                  SizedBox(height: 20),
                  _buildTrackStockToggle(),
                  const SizedBox(height: 32),
                  const Text('Blok (Upakovka) sozlamalari', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Blok ichidagi soni',
                          _quantityInBoxController,
                          Icons.numbers,
                          isNumber: true,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          'Blok narxi (ixtiyoriy)',
                          _boxPriceController,
                          Icons.payments_outlined,
                          isNumber: true,
                          isRequired: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Blok shtrix-kodi',
                    _boxBarcodeController,
                    Icons.qr_code_2_outlined,
                    isRequired: false,
                  ),
                  const SizedBox(height: 16),
                  _buildAdditionalBoxBarcodes(),
                  if (widget.product != null) ...[
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: () => PrintService.printBarcodeLabel(
                          product: widget.product!,
                          printerName: settings.barcodePrinterName,
                          ipAddress: settings.networkBarcodePrinterIp,
                        ),
                        icon: Icon(Icons.print_outlined),
                        label: Text('SHTRIX-KODNI CHOP ETISH'),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.teal),
                          foregroundColor: Colors.teal,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                  SizedBox(height: 48),
                  AppButton(
                    label: 'SAQLASH',
                    onPressed: _save,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
    bool isRequired = true,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: isNumber
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              prefixIcon: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              suffixIcon: suffix,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
              hintStyle: TextStyle(
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            validator: (v) {
              if (isRequired && (v == null || v.isEmpty)) {
                return 'Maydonni to\'ldiring';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(InventoryProvider inventory) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Kategoriya',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            InkWell(
              onTap: _showAddCategoryDialog,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  '+ Yangi Kategoriya',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategoryId,
              hint: Text('Kategoriyani tanlang'),
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              items: inventory.categories
                  .map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedCategoryId = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdditionalBarcodes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Qo\'shimcha Shtrix-kodlar',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(
                () =>
                    _additionalBarcodeControllers.add(TextEditingController()),
              ),
              icon: Icon(Icons.add, size: 18),
              label: Text('Qo\'shish', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        SizedBox(height: 8),
        ..._additionalBarcodeControllers.asMap().entries.map((entry) {
          final idx = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.qr_code,
                    color: Theme.of(context).hintColor,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () => setState(
                      () => _additionalBarcodeControllers.removeAt(idx),
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  hintText: 'Shtrix-kodni kiriting',
                  hintStyle: TextStyle(fontSize: 13),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAdditionalBoxBarcodes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Qo\'shimcha Blok Shtrix-kodlari',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
            TextButton.icon(
              onPressed: () => setState(
                () => _additionalBoxBarcodeControllers.add(TextEditingController()),
              ),
              icon: Icon(Icons.add, size: 18),
              label: Text('Qo\'shish', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        SizedBox(height: 8),
        ..._additionalBoxBarcodeControllers.asMap().entries.map((entry) {
          final idx = entry.key;
          final controller = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: TextFormField(
                controller: controller,
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    Icons.qr_code,
                    color: Theme.of(context).hintColor,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      Icons.remove_circle_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    onPressed: () => setState(
                      () => _additionalBoxBarcodeControllers.removeAt(idx),
                    ),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.all(12),
                  hintText: 'Blok shtrix-kodini kiriting',
                  hintStyle: TextStyle(fontSize: 13),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTrackStockToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: SwitchListTile(
        title: Text(
          'Ombor hisobini yuritish',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          'Sotilganda ombordan ayiriladi',
          style: TextStyle(fontSize: 12),
        ),
        value: _trackStock,
        onChanged: (v) => setState(() => _trackStock = v),
        activeThumbColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
