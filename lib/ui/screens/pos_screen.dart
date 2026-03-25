import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/sales_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../../providers/features/auth_provider.dart';
import '../../models/models.dart';
import 'checkout_screen.dart';

class POSScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const POSScreen({super.key, this.onMenuPressed});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  String selectedCategory = 'Barchasi';
  final FocusNode _focusNode = FocusNode();
  String _barcodeBuffer = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showKeyboard = false;
  final FocusNode _searchFocusNode = FocusNode();
  int _currentPage = 1;
  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    _searchFocusNode.addListener(() {
      if (!mounted) return;
      final settings = context.read<SettingsProvider>();
      if (settings.isBarcodeScanMode && !_searchFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          if (context.read<SettingsProvider>().isBarcodeScanMode) {
            _searchFocusNode.requestFocus();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _showQuantityDialog(
    BuildContext context,
    InventoryProvider inventory,
    SalesProvider sales,
    SaleItem item,
  ) {
    final product = inventory.products
        .where((p) => p.id == item.productId)
        .firstOrNull;
    final unit = product?.unit ?? 'dona';
    final initialValue = item.quantity % 1 == 0
        ? item.quantity.toInt().toString()
        : item.quantity.toString();
    final controller = TextEditingController(text: initialValue);

    void saveContent() {
      final text = controller.text.replaceAll(',', '.');
      final newQty = double.tryParse(text) ?? 0;
      try {
        sales.updateCartQuantity(item.productId, newQty, product: product, warehouseId: context.read<SettingsProvider>().currentRegister?.warehouseId);
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('${item.productName} - Miqdorni kiring ($unit)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onSubmitted: (_) => saveContent(),
              decoration: InputDecoration(
                labelText: 'Miqdor',
                suffixText: unit,
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
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
            onPressed: saveContent,
            child: Text('Saqlash'),
          ),
        ],
      ),
    );
  }


  /// Normalize text for case-insensitive, Uzbek-aware search
  String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll('\u02bb', "'")
        .replaceAll('\u02bc', "'")
        .replaceAll('\u2018', "'")
        .replaceAll('\u2019', "'");
  }

  bool _isCaps = true;

  void _onKeyTap(String key) {
    setState(() {
      if (key == 'back') {
        if (_searchController.text.isNotEmpty) {
          _searchController.text = _searchController.text.substring(
            0,
            _searchController.text.length - 1,
          );
        }
      } else if (key == 'space') {
        _searchController.text += ' ';
      } else if (key == 'caps') {
        _isCaps = !_isCaps;
      } else if (key == 'clear') {
        _searchController.clear();
      } else if (key == 'enter') {
        _showKeyboard = false;
        _focusNode.requestFocus(); // Return focus to physical scanner
      } else {
        _searchController.text += _isCaps
            ? key.toUpperCase()
            : key.toLowerCase();
      }
    });
  }

  DateTime? _lastBarcodeTime;
  String? _lastBarcode;

  DateTime? _lastKeyEventTime;

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;

    final now = DateTime.now();

    // If keys are coming in slowly (>50ms between keys), it's likely manual typing.
    // Scanners are much faster.
    if (_lastKeyEventTime != null &&
        now.difference(_lastKeyEventTime!).inMilliseconds > 100) {
      _barcodeBuffer = ''; // Clear buffer if it's too slow (likely human)
    }
    _lastKeyEventTime = now;

    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_barcodeBuffer.isNotEmpty) {
        _processBarcode(_barcodeBuffer.trim());
        _barcodeBuffer = '';
      }
    } else {
      final char = event.character;
      if (char != null &&
          char.isNotEmpty &&
          RegExp(r'[a-zA-Z0-9]').hasMatch(char)) {
        _barcodeBuffer += char;
      }
    }
  }

  void _processBarcode(String barcode) {
    if (barcode.isEmpty) return;

    // Prevent double processing within a short time (e.g. 300ms)
    final now = DateTime.now();
    if (_lastBarcode == barcode &&
        _lastBarcodeTime != null &&
        now.difference(_lastBarcodeTime!).inMilliseconds < 500) {
      return;
    }

    _lastBarcode = barcode;
    _lastBarcodeTime = now;

    try {
      final inventory = context.read<InventoryProvider>();
      final sales = context.read<SalesProvider>();
      final settings = context.read<SettingsProvider>();
      
      sales.addToCartByBarcode(barcode, inventory.products, warehouseId: settings.currentRegister?.warehouseId);

      final product = inventory.products.firstWhere(
        (p) => p.barcode == barcode || p.additionalBarcodes.contains(barcode),
        orElse: () => throw Exception('Mahsulot topilmadi'),
      );

      // Clear fields if we successfully added
      if (_searchController.text == barcode) {
        _searchController.clear();
      }
      _barcodeBuffer = '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} savatga qo\'shildi'),
          duration: const Duration(milliseconds: 700),
          backgroundColor: Theme.of(
            context,
          ).colorScheme.primary, // Using theme color
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
        ),
      );
    } catch (e) {
      // If it's not a barcode, just let it be (maybe a regular enter in search)
      debugPrint('Not a valid barcode: $barcode');
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final sales = context.watch<SalesProvider>();
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();

    final activeCategories = inventory.activeCategories;
    final categories = ['Barchasi', ...activeCategories.map((c) => c.name)];

    final searchQuery = _normalize(_searchController.text);
    final categoryMap = {for (var c in activeCategories) c.id: c.name};
    
    final filteredProducts = inventory.activeProducts.where((p) {
      final categoryName = categoryMap[p.categoryId];
      final matchesCategory =
          selectedCategory == 'Barchasi' ||
          (categoryName == selectedCategory);
      final matchesSearch = searchQuery.isEmpty ||
          _normalize(p.name ?? '').contains(searchQuery) ||
          _normalize(p.barcode ?? '').contains(searchQuery);
      return matchesCategory && matchesSearch;
    }).toList();

    // Reset page if it's out of bounds after filtering
    final totalPages = (filteredProducts.length / _pageSize).ceil();
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    } else if (totalPages == 0) {
      _currentPage = 1;
    }

    final startIndex = (_currentPage - 1) * _pageSize;
    final paginatedProducts = filteredProducts.skip(startIndex).take(_pageSize).toList();

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: false,
      onKeyEvent: _handleKeyEvent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Row(
              children: [
                if (!isMobile) _buildCartSidebar(sales, inventory, settings, auth, 400),
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(settings, inventory, isMobile),
                      _buildCategoryChips(categories),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: _buildProductGrid(
                                      paginatedProducts,
                                      inventory,
                                      sales,
                                      settings,
                                      constraints.maxWidth,
                                    ),
                                  ),
                                  if (filteredProducts.length > _pageSize)
                                    _buildPagination(filteredProducts.length),
                                ],
                              ),
                            ),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              switchInCurve: Curves.easeOutCubic,
                              switchOutCurve: Curves.easeInCubic,
                              transitionBuilder: (child, animation) {
                                return SlideTransition(
                                  position: Tween<Offset>(
                                    begin: const Offset(0, 1),
                                    end: Offset.zero,
                                  ).animate(animation),
                                  child: child,
                                );
                              },
                              child: _showKeyboard
                                  ? KeyedSubtree(
                                      key: const ValueKey('virtual_keyboard'),
                                      child: _buildVirtualKeyboard(),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            floatingActionButton: isMobile && sales.cart.isNotEmpty
                ? FloatingActionButton.extended(
                    onPressed: () => _showMobileCart(context, sales, inventory, settings, auth),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    label: Text(
                      'Savat (${sales.cart.length})',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildTopBar(SettingsProvider settings, InventoryProvider inventory, bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withAlpha(128), // ~0.5
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(20), // ~0.08
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.point_of_sale_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withAlpha(13) // ~0.05
                    : Colors.grey.withAlpha(13), // ~0.05
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withAlpha(77), // ~0.3
                ),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (v) => setState(() {
                  _currentPage = 1;
                }),
                onSubmitted: (v) {
                  _processBarcode(v);
                  _searchController.clear();
                  if (settings.isBarcodeScanMode) _searchFocusNode.requestFocus();
                },
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Qidirish yoki shtrix kodni o\'qing...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.5),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.7),
                    size: 20,
                  ),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTopBarAction(
                        icon: Icons.keyboard_hide_rounded,
                        isActive: _showKeyboard,
                        onTap: () => setState(() => _showKeyboard = !_showKeyboard),
                        tooltip: 'Virtual klaviatura',
                      ),
                      _buildTopBarAction(
                        icon: settings.isBarcodeScanMode
                            ? Icons.qr_code_scanner_rounded
                            : Icons.barcode_reader,
                        isActive: settings.isBarcodeScanMode,
                        onTap: () {
                          settings.toggleBarcodeScanMode();
                           final nowScanMode = context.read<SettingsProvider>().isBarcodeScanMode;
                          if (nowScanMode) {
                            setState(() => _showKeyboard = false);
                            Future.delayed(const Duration(milliseconds: 100), () {
                              if (mounted) _searchFocusNode.requestFocus();
                            });
                          } else {
                            _focusNode.requestFocus();
                          }
                        },
                        tooltip: 'Scan rejimi',
                      ),
                      _buildTopBarAction(
                        icon: settings.showProductImages
                            ? Icons.image_outlined
                            : Icons.image_not_supported_outlined,
                        isActive: settings.showProductImages,
                        onTap: () => settings.toggleShowProductImages(),
                        tooltip: settings.showProductImages ? 'Rasmlarni yashirish' : 'Rasmlarni ko\'rsatish',
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          if (!isMobile) const SizedBox(width: 16),
          if (!isMobile) _buildKassaInfo(settings, inventory),
          if (widget.onMenuPressed != null)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: _buildIconButton(
                icon: Icons.menu_rounded,
                onTap: widget.onMenuPressed!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBarAction({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isActive
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).textTheme.bodySmall?.color?.withOpacity(0.6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          ),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildKassaInfo(SettingsProvider settings, InventoryProvider inventory) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.storefront,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                settings.currentRegister?.name ?? 'Kassa tanlanmagan',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                'Ombor: ${settings.currentRegister == null ? "Tanlanmagan" : (inventory.warehouses.any((w) => w.id == settings.currentRegister?.warehouseId) ? inventory.warehouses.firstWhere((w) => w.id == settings.currentRegister?.warehouseId).name : (inventory.warehouses.isNotEmpty ? inventory.warehouses.first.name : "Noma'lum"))}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(List<String> categories) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selectedCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() {
                    selectedCategory = cat;
                    _currentPage = 1;
                  });
                }
              },
              backgroundColor: Theme.of(context).cardColor,
              selectedColor: Theme.of(context).colorScheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              elevation: isSelected ? 4 : 0,
              shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductGrid(
    List<Product> products,
    InventoryProvider inventory,
    SalesProvider sales,
    SettingsProvider settings,
    double width,
  ) {
    if (products.isEmpty) return _buildEmptyState();

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: width < 600 ? 180 : 220,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: settings.showProductImages ? 260 : 100,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) =>
          _buildProductCard(products[index], inventory, sales, settings),
    );
  }

  Widget _buildProductCard(Product product, InventoryProvider inventory, SalesProvider sales, SettingsProvider settings) {
    final stock = product.stocks[settings.currentRegister?.warehouseId] ?? 0;
    final isLowStock = stock <= 0;

    return InkWell(
      onTap: () {
        try {
          sales.addToCart(product, warehouseId: settings.currentRegister?.warehouseId);
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(settings.showProductImages ? 20 : 16),
          border: Border.all(
            color: Theme.of(context).dividerColor.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(settings.showProductImages ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (settings.showProductImages)
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                          image: product.imagePath != null
                              ? DecorationImage(
                                  image: FileImage(File(product.imagePath!)),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: product.imagePath == null
                            ? Center(
                                child: Icon(
                                  inventory.categories.any(
                                            (c) =>
                                                c.id == product.categoryId &&
                                                c.name == 'Ichimliklar',
                                          )
                                      ? Icons.local_drink_rounded
                                      : Icons.restaurant_rounded,
                                  size: 48,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.2),
                                ),
                              )
                            : null,
                      ),
                      PositionBagde(isLowStock: isLowStock, stock: stock, unit: product.unit),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(product.price)} s',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        if (!settings.showProductImages)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isLowStock
                                  ? Colors.red.withOpacity(0.1)
                                  : Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${stock % 1 == 0 ? stock.toInt() : stock.toStringAsFixed(1)} ${product.unit}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isLowStock ? Colors.redAccent : Colors.green,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPagination(int totalItems) {
    final totalPages = (totalItems / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageBtn(
            Icons.chevron_left_rounded,
            _currentPage > 1 ? () => setState(() => _currentPage--) : null,
          ),
          const SizedBox(width: 12),
          for (int i = 1; i <= totalPages; i++)
            if (i == 1 || i == totalPages || (i >= _currentPage - 1 && i <= _currentPage + 1))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _buildPageNumberBtn(i, i == _currentPage),
              )
            else if (i == 2 && _currentPage > 3 || i == totalPages - 1 && _currentPage < totalPages - 2)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
          const SizedBox(width: 12),
          _buildPageBtn(
            Icons.chevron_right_rounded,
            _currentPage < totalPages ? () => setState(() => _currentPage++) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPageBtn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
            color: onTap == null ? Colors.grey.withOpacity(0.05) : Theme.of(context).cardColor,
          ),
          child: Icon(
            icon,
            color: onTap == null ? Colors.grey.shade400 : Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildPageNumberBtn(int page, bool isSelected) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _currentPage = page),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Text(
            page.toString(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCartSidebar(SalesProvider sales, InventoryProvider inventory, SettingsProvider settings, AuthProvider auth, double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.02,
            ),
            blurRadius: 15,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildCartHeader(sales),
          Expanded(
            child: sales.cart.isEmpty
                ? _buildEmptyCart()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: sales.cart.length,
                    itemBuilder: (context, index) =>
                        _buildCartItem(sales.cart[index], inventory, sales, settings),
                  ),
          ),
          _buildCartFooter(sales),
        ],
      ),
    );
  }

  Widget _buildCartHeader(SalesProvider sales) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Savat',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          if (sales.cart.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined, color: Colors.redAccent),
              onPressed: () => sales.clearCart(),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItem(SaleItem item, InventoryProvider inventory, SalesProvider sales, SettingsProvider settings) {
    final product = inventory.products
        .where((p) => p.id == item.productId)
        .firstOrNull;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(color: Theme.of(context).dividerColor),
                  image: product?.imagePath != null
                      ? DecorationImage(
                          image: FileImage(File(product!.imagePath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: product?.imagePath == null
                    ? Icon(
                        Icons.inventory_2_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${item.price.toStringAsFixed(0)} so\'m',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(item.price * item.quantity).toStringAsFixed(0)} so\'m',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => sales.removeFromCart(item.productId),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.redAccent,
                  size: 22,
                ),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
              Row(
                children: [
                  _buildQtyBtn(
                    Icons.remove,
                    () {
                      sales.updateCartQuantity(item.productId, item.quantity - 1);
                    },
                    color: Colors.red.withOpacity(0.1),
                    iconColor: Colors.redAccent,
                  ),
                  InkWell(
                    onTap: () => _showQuantityDialog(context, inventory, sales, item),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 60,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.quantity % 1 == 0
                            ? item.quantity.toInt().toString()
                            : item.quantity.toStringAsFixed(3),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  _buildQtyBtn(
                    Icons.add,
                    () {
                      if (product != null) {
                        try {
                          sales.addToCart(product, warehouseId: context.read<SettingsProvider>().currentRegister?.warehouseId);
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                e.toString().replaceAll('Exception: ', ''),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    color: Colors.green.withOpacity(0.1),
                    iconColor: Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQtyBtn(
    IconData icon,
    VoidCallback onTap, {
    Color? color,
    Color? iconColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color:
              color ??
              (Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: iconColor ?? Theme.of(context).colorScheme.onSurface),
      ),
    );
  }

  Widget _buildCartFooter(SalesProvider sales) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05,
            ),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Jami:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(sales.cartTotal)} so\'m',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              onPressed: sales.cart.isEmpty
                  ? null
                  : () => _handlePayment(sales),
              child: const Text(
                'TO\'LOVNI YAKUNLASH',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMobileCart(BuildContext context, SalesProvider sales, InventoryProvider inventory, SettingsProvider settings, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Expanded(child: _buildCartSidebar(sales, inventory, settings, auth, double.infinity)),
          ],
        ),
      ),
    );
  }

  void _handlePayment(SalesProvider sales) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CheckoutScreen()),
    );
  }

  Widget _buildVirtualKeyboard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toolbar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => setState(() => _showKeyboard = false),
                      icon: const Icon(Icons.keyboard_hide_rounded, size: 18, color: Colors.grey),
                      label: const Text('Yashirish', style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                    TextButton.icon(
                      onPressed: () => _onKeyTap('clear'),
                      icon: const Icon(Icons.delete_sweep_outlined, size: 18, color: Colors.redAccent),
                      label: const Text('Tozalash', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              // Row 1: Numbers
              _buildKeyRow(
                ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0', 'back'],
                rowFlex: [1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5],
              ),
              const SizedBox(height: 4),
              // Row 2: QWERTY
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildKeyRow(['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p']),
              ),
              const SizedBox(height: 4),
              // Row 3: ASDF
              _buildKeyRow(
                ['caps', 'a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'enter'],
                rowFlex: [1.2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1.5],
              ),
              const SizedBox(height: 4),
              // Row 4: ZXCV
              _buildKeyRow(
                ['z', 'x', 'c', 'v', 'b', 'n', 'm', '.', ',', 'space'],
                rowFlex: [1, 1, 1, 1, 1, 1, 1, 1, 1, 3.5],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<String> keys, {List<double>? rowFlex}) {
    return Row(
      children: keys.asMap().entries.map((entry) {
        final idx = entry.key;
        final k = entry.value;
        final flex = rowFlex != null ? (rowFlex[idx] * 100).toInt() : 100;
        return Expanded(flex: flex, child: _buildVirtualKey(k));
      }).toList(),
    );
  }

  Widget _buildVirtualKey(String k) {
    final isBack = k == 'back';
    final isEnter = k == 'enter';
    final isSpace = k == 'space';
    final isCaps = k == 'caps';

    final Color bgColor;
    final Color textColor;
    Widget labelWidget;

    if (isEnter) {
      bgColor = Theme.of(context).colorScheme.primary;
      textColor = Colors.white;
      labelWidget = Icon(
        Icons.keyboard_return_rounded,
        color: Colors.white,
        size: 20,
      );
    } else if (isBack) {
      bgColor = Theme.of(context).dividerColor;
      textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
      labelWidget = Icon(Icons.backspace_outlined, size: 18, color: textColor);
    } else if (isCaps) {
      bgColor = _isCaps
          ? Theme.of(context).colorScheme.primary.withOpacity(0.8)
          : Theme.of(context).dividerColor;
      textColor = _isCaps ? Colors.white : (Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87);
      labelWidget = Text(
        'ABC',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: textColor,
        ),
      );
    } else if (isSpace) {
      bgColor = Theme.of(context).cardColor;
      textColor = Theme.of(context).textTheme.bodySmall?.color ?? Colors.black54;
      labelWidget = Text('Bo\'shliq', style: TextStyle(fontSize: 14, color: textColor));
    } else {
      bgColor = Theme.of(context).cardColor;
      textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black87;
      labelWidget = Text(
        _isCaps ? k.toUpperCase() : k.toLowerCase(),
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: SizedBox(
        height: 48,
        child: Material(
          color: bgColor,
          borderRadius: BorderRadius.circular(6),
          child: InkWell(
            onTap: () => _onKeyTap(k),
            borderRadius: BorderRadius.circular(6),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withOpacity(0.3),
                  width: 0.5,
                ),
              ),
              child: Center(child: labelWidget),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() => Center(
    child: Text('Mahsulot topilmadi', style: TextStyle(color: Colors.grey)),
  );
  Widget _buildEmptyCart() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.shopping_cart_outlined,
          size: 60,
          color: Theme.of(context).dividerColor,
        ),
        SizedBox(height: 16),
        Text('Savat bo\'sh', style: TextStyle(color: Colors.grey.shade400)),
      ],
    ),
  );
}

class PositionBagde extends StatelessWidget {
  final bool isLowStock;
  final double stock;
  final String unit;

  const PositionBagde({
    super.key,
    required this.isLowStock,
    required this.stock,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isLowStock ? Colors.red.withOpacity(0.9) : Colors.green.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          '${stock % 1 == 0 ? stock.toInt() : stock.toStringAsFixed(1)} $unit',
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
