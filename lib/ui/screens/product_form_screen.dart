import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import '../../models/models.dart';
import '../../providers/app_state.dart';
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
  String? _selectedCategoryId;
  String? _imagePath;
  bool _trackStock = true;
  List<TextEditingController> _additionalBarcodeControllers = [];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _priceController = TextEditingController(
      text: widget.product?.price.toStringAsFixed(0) ?? '',
    );
    _costPriceController = TextEditingController(
      text: widget.product?.costPrice.toStringAsFixed(0) ?? '',
    );
    _barcodeController = TextEditingController(
      text: widget.product?.barcode ?? '',
    );
    _selectedCategoryId = widget.product?.categoryId;
    _imagePath = widget.product?.imagePath;
    _trackStock = widget.product?.trackStock ?? true;
    _additionalBarcodeControllers = (widget.product?.additionalBarcodes ?? [])
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
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory(path.join(appDir.path, 'product_images'));
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}${path.extension(pickedFile.path)}';
      final savedImage = await File(
        pickedFile.path,
      ).copy(path.join(imagesDir.path, fileName));

      setState(() {
        _imagePath = savedImage.path;
      });
    }
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      final state = context.read<AppState>();

      if (_selectedCategoryId == null && state.categories.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Avval kategoriya yarating')),
        );
        return;
      }

      if (_selectedCategoryId == null && state.categories.isNotEmpty) {
        _selectedCategoryId = state.categories.first.id;
      }

      final name = _nameController.text;
      final price = double.tryParse(_priceController.text) ?? 0.0;
      final costPrice = double.tryParse(_costPriceController.text) ?? 0.0;
      final barcode = _barcodeController.text;
      final additionalBarcodes = _additionalBarcodeControllers
          .map((c) => c.text)
          .where((t) => t.isNotEmpty)
          .toList();

      if (widget.product == null) {
        final product = Product.create(
          name,
          price,
          _selectedCategoryId!,
          barcode,
          costPrice: costPrice,
          imagePath: _imagePath,
          trackStock: _trackStock,
        ).copyWith(additionalBarcodes: additionalBarcodes);
        await state.addProduct(product);
      } else {
        final updatedProduct = widget.product!.copyWith(
          name: name,
          price: price,
          costPrice: costPrice,
          categoryId: _selectedCategoryId,
          barcode: barcode,
          additionalBarcodes: additionalBarcodes,
          imagePath: _imagePath,
          trackStock: _trackStock,
        );
        await state.updateProduct(updatedProduct);
      }

      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
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
            SizedBox(width: 12),
            Text(widget.product == null ? 'Yangi Mahsulot' : 'Tahrirlash'),
          ],
        ),
        elevation: 0,
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        centerTitle: true,
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
                  _buildImagePicker(),
                  SizedBox(height: 32),
                  _buildTextField(
                    'Mahsulot nomi',
                    _nameController,
                    Icons.inventory_2_outlined,
                  ),
                  SizedBox(height: 20),
                  _buildCategoryDropdown(state),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Tannarxi (so\'m)',
                          _costPriceController,
                          Icons.shopping_bag_outlined,
                          isNumber: true,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: _buildTextField(
                          'Narxi (so\'m)',
                          _priceController,
                          Icons.payments_outlined,
                          isNumber: true,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTextField(
                          'Shtrix-kod',
                          _barcodeController,
                          Icons.qr_code_scanner_outlined,
                          suffix: IconButton(
                            icon: Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary),
                            tooltip: 'Generatsiya qilish',
                            onPressed: () {
                              setState(() {
                                _barcodeController.text = state.generateBarcode();
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
                  if (widget.product != null) ...[
                    SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: OutlinedButton.icon(
                        onPressed: () => PrintService.printBarcodeLabel(
                          product: widget.product!,
                          printerName: state.barcodePrinterName,
                          ipAddress: state.networkBarcodePrinterIp,
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
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'SAQLASH',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
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

  Widget _buildImagePicker() {
    return Center(
      child: InkWell(
        onTap: _pickImage,
        borderRadius: BorderRadius.circular(30),
        child: Stack(
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      Theme.of(context).brightness == Brightness.dark
                          ? 0.3
                          : 0.05,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
                image: _imagePath != null
                    ? DecorationImage(
                        image: FileImage(File(_imagePath!)),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _imagePath == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_outlined,
                          size: 48,
                          color: Theme.of(context).hintColor,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Rasm yuklash',
                          style: TextStyle(
                            color: Theme.of(context).hintColor,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
            if (_imagePath != null)
              Positioned(
                top: 8,
                right: 8,
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.black.withOpacity(0.5),
                  child: IconButton(
                    icon: Icon(Icons.close, size: 18, color: Colors.white),
                    onPressed: () => setState(() => _imagePath = null),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon, {
    bool isNumber = false,
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
            validator: (v) =>
                v == null || v.isEmpty ? 'Maydonni to\'ldiring' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Kategoriya',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
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
              items: state.categories
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
