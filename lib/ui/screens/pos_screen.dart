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
import '../widgets/pos/pos_product_card.dart';
import '../widgets/pos/pos_cart_item.dart';
import '../widgets/pos/pos_virtual_keyboard.dart';
import '../widgets/pos/pos_category_selector.dart';
import '../../core/constants/app_constants.dart';
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
          final isMobile = constraints.maxWidth < 800;
          final sidebarWidth = constraints.maxWidth < 1050 ? 300.0 : 380.0;

          return Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Row(
              children: [
                // Desktop Cart Sidebar
                if (!isMobile)
                  Row(
                    children: [
                      _buildCartSidebar(
                        sales,
                        inventory,
                        settings,
                        auth,
                        sidebarWidth,
                      ),
                      VerticalDivider(
                        width: 1, 
                        thickness: 1, 
                        color: Theme.of(context).dividerColor.withOpacity(0.5)
                      ),
                    ],
                  ),
                // Product Grid Area
                Expanded(
                  child: Column(
                    children: [
                      _buildTopBar(settings, inventory, isMobile),
                      POSCategorySelector(
                        categories: categories,
                        selectedCategory: selectedCategory,
                        onCategorySelected: (cat) {
                          setState(() {
                            selectedCategory = cat;
                            _currentPage = 1;
                          });
                        },
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Expanded(
                              child: _buildProductGrid(
                                paginatedProducts,
                                inventory,
                                sales,
                                settings,
                              ),
                            ),
                            if (filteredProducts.length > _pageSize)
                              _buildPagination((filteredProducts.length / _pageSize).ceil()),
                          ],
                        ),
                      ),
                      // Virtual Keyboard
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
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
            floatingActionButton: isMobile && sales.cart.isNotEmpty
                ? FloatingActionButton.extended(
                    onPressed: () => _showCartSheet(sales, inventory, settings, auth),
                    heroTag: 'mobile_cart_fab',
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    label: Text(
                      'Savat (${sales.cart.length})',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Qidirish...',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.withOpacity(0.7)),
                  border: InputBorder.none,
                  icon: const Icon(Icons.search, size: 18, color: Colors.grey),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (v) => setState(() => _currentPage = 1),
                onSubmitted: (v) {
                  _processBarcode(v);
                  _searchController.clear();
                  _searchFocusNode.requestFocus();
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildTopBarAction(
            icon: Icons.keyboard_hide_rounded,
            isActive: _showKeyboard,
            onTap: () => setState(() => _showKeyboard = !_showKeyboard),
            tooltip: 'Klaviatura',
          ),
          _buildTopBarAction(
            icon: settings.isBarcodeScanMode ? Icons.qr_code_scanner_rounded : Icons.barcode_reader,
            isActive: settings.isBarcodeScanMode,
            onTap: () => settings.toggleBarcodeScanMode(),
            tooltip: 'Scan rejimi',
          ),
          if (!isMobile) ...[
            const SizedBox(width: 8),
            _buildKassaInfo(settings, inventory),
          ],
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            color: Theme.of(context).colorScheme.primary,
            onPressed: widget.onMenuPressed,
            tooltip: 'Menyu',
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarAction({required IconData icon, required bool isActive, required VoidCallback onTap, required String tooltip}) {
    return IconButton(
      icon: Icon(icon, size: 20, color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey),
      onPressed: onTap,
      padding: const EdgeInsets.all(8),
      constraints: const BoxConstraints(),
      tooltip: tooltip,
    );
  }

  Widget _buildKassaInfo(SettingsProvider settings, InventoryProvider inventory) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).dividerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            settings.currentRegister?.name ?? 'Kassa',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          Text(
            'v${AppConstants.appVersion}',
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products, InventoryProvider inventory, SalesProvider sales, SettingsProvider settings) {
    if (products.isEmpty) {
      return Center(
        child: Text('Mahsulot yo\'q', style: TextStyle(color: Colors.grey.withOpacity(0.5))),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        mainAxisExtent: 105,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) => POSProductCard(
        product: products[index],
        sales: sales,
        settings: settings,
      ),
    );
  }

  Widget _buildPagination(int totalPages) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageBtn(Icons.chevron_left_rounded, _currentPage > 1 ? () => setState(() => _currentPage--) : null),
          const SizedBox(width: 16),
          Text('$_currentPage / $totalPages', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 16),
          _buildPageBtn(Icons.chevron_right_rounded, _currentPage < totalPages ? () => setState(() => _currentPage++) : null),
        ],
      ),
    );
  }

  Widget _buildPageBtn(IconData icon, VoidCallback? onTap) {
    return IconButton(
      icon: Icon(icon, size: 20),
      onPressed: onTap,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      style: IconButton.styleFrom(
        backgroundColor: Theme.of(context).dividerColor.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }

  Widget _buildCartSidebar(SalesProvider sales, InventoryProvider inventory, SettingsProvider settings, AuthProvider auth, double width) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
            child: Row(
              children: [
                const Expanded(child: Text('SAVAT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 0.5))),
                if (sales.cart.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 20),
                    onPressed: () => sales.clearCart(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
          ),
          Expanded(
            child: sales.cart.isEmpty
                ? Center(child: Text('Savat bo\'sh', style: TextStyle(color: Colors.grey.withOpacity(0.4), fontSize: 13)))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: sales.cart.length,
                    itemBuilder: (context, index) => POSCartItem(
                      item: sales.cart[index],
                      onShowQuantityDialog: (it) => _showQuantityDialog(context, inventory, sales, it),
                    ),
                  ),
          ),
          _buildCartFooter(sales),
        ],
      ),
    );
  }

  Widget _buildCartFooter(SalesProvider sales) {
    final total = sales.cartTotal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Jami:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey)),
              Text(
                '${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(total)}',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: sales.cart.isEmpty ? null : () => _handlePayment(sales),
              child: const Text('TO\'LOV', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _handlePayment(SalesProvider sales) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const CheckoutScreen()));
  }

  void _showCartSheet(SalesProvider sales, InventoryProvider inventory, SettingsProvider settings, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(margin: const EdgeInsets.symmetric(vertical: 8), width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Expanded(child: _buildCartSidebar(sales, inventory, settings, auth, double.infinity)),
          ],
        ),
      ),
    );
  }

  Widget _buildVirtualKeyboard() {
    return POSVirtualKeyboard(
      isCaps: _isCaps,
      onKeyTap: _onKeyTap,
      onHideKeyboard: () => setState(() => _showKeyboard = false),
    );
  }
}
