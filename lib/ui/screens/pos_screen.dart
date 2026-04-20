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
import '../widgets/app_status_bar.dart';
import '../../providers/features/sync_provider.dart';
import '../widgets/pos/pos_category_selector.dart';
import '../../core/constants/app_constants.dart';
import 'checkout_screen.dart';
import '../../services/scale_service.dart';
import '../widgets/app_end_drawer.dart';
import '../../providers/features/navigation_provider.dart';
import '../../core/utils/responsive.dart';
import '../../core/utils/formatter.dart';

class POSScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  final bool isStandalone;
  const POSScreen({super.key, this.onMenuPressed, this.isStandalone = false});

  @override
  State<POSScreen> createState() => _POSScreenState();
}

class _POSScreenState extends State<POSScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String selectedCategory = 'Barchasi';
  final FocusNode _focusNode = FocusNode();
  String _barcodeBuffer = '';
  final TextEditingController _searchController = TextEditingController();
  bool _showKeyboard = false;
  final FocusNode _searchFocusNode = FocusNode();
  int _currentPage = 1;
  static const int _pageSize = 20;

  List<Product> _filteredProductsCache = [];
  String _lastSearchText = '';
  String _lastCategory = 'Barchasi';
  int _lastInventoryVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });

    _searchFocusNode.addListener(() {
      if (!mounted) return;
      final settings = context.read<SettingsProvider>();
      final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? true;
      
      if (settings.isBarcodeScanMode && !_searchFocusNode.hasFocus && isCurrentRoute) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (!mounted) return;
          final currentIsCurrent = ModalRoute.of(context)?.isCurrent ?? true;
          if (context.read<SettingsProvider>().isBarcodeScanMode && currentIsCurrent) {
            _searchFocusNode.requestFocus();
          }
        });
      }
    });

    _searchController.addListener(() {
       if (mounted) setState(() {}); 
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
    final product = inventory.products.where((p) => p.id == item.productId).firstOrNull;
    final unit = item.isBox ? 'blok' : (product?.unit ?? 'dona');
    final double displayQty = item.isBox && product != null ? item.quantity / product.quantityInBox : item.quantity;
    
    final initialValue = displayQty == 0 ? '' : AppFormatter.formatDouble(displayQty);
    final controller = TextEditingController(text: initialValue);

    void saveContent() {
      final text = controller.text.replaceAll(',', '.');
      double inputQty = double.tryParse(text) ?? 0;
      
      double finalQty = inputQty;
      if (item.isBox && product != null) {
        finalQty = inputQty * product.quantityInBox;
      }

      try {
        sales.updateCartQuantity(item.productId, finalQty, product: product, warehouseId: context.read<SettingsProvider>().currentRegister?.warehouseId, isBox: item.isBox);
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
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void onNumPressed(String val) {
            setDialogState(() {
              if (val == 'C') {
                controller.clear();
              } else if (val == 'back') {
                if (controller.text.isNotEmpty) {
                  controller.text = controller.text.substring(0, controller.text.length - 1);
                }
              } else if (val == '.') {
                if (!controller.text.contains('.')) {
                  controller.text += '.';
                }
              } else {
                controller.text += val;
              }
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                const Icon(Icons.add_shopping_cart_rounded, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(child: Text('${item.productName} ($unit)')),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              controller.text.isEmpty ? '0' : controller.text,
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.blue),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(unit, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.6,
                      children: [
                        for (var i = 1; i <= 9; i++) _buildDialogNumBtn(i.toString(), onNumPressed),
                        _buildDialogNumBtn('.', onNumPressed, color: Colors.blue.shade50, textColor: Colors.blue),
                        _buildDialogNumBtn('0', onNumPressed),
                        _buildDialogNumBtn('back', onNumPressed, icon: Icons.backspace_outlined, color: Colors.grey.shade100),
                      ],
                    ),
                    if (unit == 'kg') ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final settings = context.read<SettingsProvider>();
                              final weight = await ScaleService().readWeight(
                                port: settings.scalePort,
                                baudRate: settings.scaleBaudRate,
                                protocol: settings.scaleProtocol,
                              );
                              setDialogState(() {
                                controller.text = weight.toStringAsFixed(3);
                              });
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Tarozidan o\'qib bo\'lmadi: $e')),
                              );
                            }
                          },
                          icon: const Icon(Icons.scale_rounded, size: 20),
                          label: const Text('TAROZIDAN OLISH', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.shade700,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('Bekor qilish')
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: saveContent,
                child: const Text('SAQLASH', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
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

    // Prevent double processing within a short time (e.g. 500ms)
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
      
      final product = sales.addToCartByBarcode(barcode, inventory.activeProducts, warehouseId: settings.currentRegister?.warehouseId);

      if (product == null) {
        throw Exception('Mahsulot topilmadi');
      }

      // Clear fields if we successfully added
      if (_searchController.text == barcode) {
        _searchController.clear();
      }
      _barcodeBuffer = '';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} savatga qo\'shildi'),
          duration: const Duration(milliseconds: 700),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(20),
        ),
      );
    } catch (e) {
      debugPrint('Barcode processing error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final sales = context.watch<SalesProvider>();
    final settings = context.watch<SettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final sync = context.watch<SyncProvider>();

    final activeCategories = inventory.activeCategories;
    final categoriesList = ['Barchasi', ...activeCategories.map((c) => c.name)];

    final categoryMap = {for (var c in activeCategories) c.id: c.name};
    
    final currentSearch = _searchController.text.trim().toLowerCase();
    // We use a simple hash-like check to see if we need to re-filter
    final inventoryVersion = inventory.activeProducts.length + inventory.categories.length; 
    
    if (_lastSearchText != currentSearch || _lastCategory != selectedCategory || _lastInventoryVersion != inventoryVersion) {
      _filteredProductsCache = inventory.activeProducts.where((p) {
        final categoryName = categoryMap[p.categoryId];
        final matchesCategory =
            selectedCategory == 'Barchasi' ||
            (categoryName == selectedCategory);
        final matchesSearch = p.matchesSearch(currentSearch);
        return matchesCategory && matchesSearch;
      }).toList();
      _lastSearchText = currentSearch;
      _lastCategory = selectedCategory;
      _lastInventoryVersion = inventoryVersion;
    }

    final filteredProducts = _filteredProductsCache;

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
          final isMobile = constraints.maxWidth < 600;
          final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1100;
          
          final actionWidth = isMobile ? 0.0 : (isTablet ? 120.w : 140.w);
          final cartFlex = isTablet ? 5 : 4;
          final productsFlex = isTablet ? 5 : 6;

          return Scaffold(
            key: _scaffoldKey,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            endDrawer: Drawer(
              width: 280,
              child: AppEndDrawer(
                selectedIndex: 0, // POS is index 0
                onIndexChanged: (index) {
                  Navigator.pop(context); // close drawer
                  if (index != 1) { // 1 is POS in global provider
                    context.read<NavigationProvider>().setIndex(index);
                  }
                },
              ),
            ),
            body: Column(
              children: [
                _buildTopBar(settings, inventory, sales, isMobile),
                Expanded(
                  child: Row(
                    children: [
                      // Left: Products Filter & Grid
                      Expanded(
                        flex: 6,
                        child: Column(
                          children: [
                            _buildProductSearchSection(settings),
                            _buildHorizontalCategoryBar(categoriesList),
                            Expanded(
                              child: _buildProductGrid(
                                paginatedProducts,
                                inventory,
                                sales,
                                settings,
                                isTablet,
                                Responsive.isShort(context),
                                constraints,
                              ),
                            ),
                            if (filteredProducts.length > _pageSize)
                              _buildPagination((filteredProducts.length / _pageSize).ceil()),
                            
                            // Virtual Keyboard inside Products Section
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
                      
                      const VerticalDivider(width: 1, thickness: 1),

                      // Center: Cart View
                      Expanded(
                        flex: 4,
                        child: _buildVerticalCartView(sales, inventory),
                      ),

                      const VerticalDivider(width: 1, thickness: 1),

                      // Right: Action Sidebar (Now includes Payment and Save)
                      _buildActionSidebar(sales, inventory, settings, auth, actionWidth, isTablet),
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

  Widget _buildTopBar(SettingsProvider settings, InventoryProvider inventory, SalesProvider sales, bool isMobile) {
    final bool isShort = Responsive.isShort(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.sp, vertical: isShort ? 2.h : 6.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          _buildTopBarAction(
            icon: Icons.arrow_back_ios_new_rounded,
            isActive: false,
            onTap: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                final nav = context.read<NavigationProvider>();
                if (nav.canGoBack) {
                  nav.goBack();
                } else {
                  nav.openSessions();
                }
              }
            },
            tooltip: 'Ortga qaytish',
          ),
          const Spacer(),
          if (!isMobile) ...[
            _buildKassaInfo(settings, inventory),
            const SizedBox(width: 8),
          ],
          IconButton(
            icon: const Icon(Icons.menu_rounded),
            color: Theme.of(context).colorScheme.primary,
            onPressed: widget.onMenuPressed ?? () => _scaffoldKey.currentState?.openEndDrawer(),
            tooltip: 'Menyu',
          ),
        ],
      ),
    );
  }

  Widget _buildProductSearchSection(SettingsProvider settings) {
    final bool isShort = Responsive.isShort(context);
    return Container(
      padding: EdgeInsets.all(isShort ? 6.sp : 12.sp),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: isShort ? 38.h : 48.h,
              padding: EdgeInsets.symmetric(horizontal: 16.sp),
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(Responsive.borderRadius),
              ),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Qidirish...',
                  hintStyle: TextStyle(fontSize: 14.sp, color: Colors.grey.withOpacity(0.7)),
                  border: InputBorder.none,
                  icon: Icon(Icons.search, size: 20.sp, color: Colors.grey),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 14.h),
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
          const SizedBox(width: 12),
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
            'v${settings.appVersion}',
            style: const TextStyle(fontSize: 9, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products, InventoryProvider inventory, SalesProvider sales, SettingsProvider settings, bool isTablet, bool isShort, BoxConstraints constraints) {
    if (products.isEmpty) {
      return Center(
        child: Text('Mahsulot yo\'q', style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 16.sp)),
      );
    }
    
    int crossAxisCount = isTablet ? 4 : (constraints.maxWidth < 600 ? 2 : 5);
    double mainAxisExtent = isShort ? 100.h : (isTablet ? 110.h : 120.h);

    return GridView.builder(
      padding: EdgeInsets.all(isShort ? 6.sp : 10.sp),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisExtent: mainAxisExtent,
        crossAxisSpacing: isShort ? 6.sp : 10.sp,
        mainAxisSpacing: isShort ? 6.sp : 10.sp,
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
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildPageBtn(Icons.chevron_left_rounded, _currentPage > 1 ? () => setState(() => _currentPage--) : null),
          SizedBox(width: 16.w),
          Text('$_currentPage / $totalPages', style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold)),
          SizedBox(width: 16.w),
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

  Widget _buildVerticalCartView(SalesProvider sales, InventoryProvider inventory) {
    final bool isShort = Responsive.isShort(context);
    return Container(
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.sp, vertical: isShort ? 10.h : 16.h),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2))),
            ),
            child: Row(
              children: [
                Icon(Icons.shopping_basket_rounded, size: isShort ? 18.sp : 20.sp, color: Theme.of(context).colorScheme.primary),
                SizedBox(width: 10.w),
                Text('SAVATDAGI MAHSULOTLAR', style: TextStyle(fontWeight: FontWeight.w900, fontSize: isShort ? 12.sp : 13.sp, letterSpacing: 0.5)),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.sp, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.sp),
                  ),
                  child: Text(
                    '${sales.cart.length} turlar',
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: sales.cart.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.shopping_bag_outlined, size: 80.sp, color: Theme.of(context).dividerColor.withOpacity(0.2)),
                        SizedBox(height: 24.h),
                        Text('Savat bo\'sh', style: TextStyle(color: Colors.grey, fontSize: 16.sp, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        SizedBox(height: 8.h),
                        Text('Mahsulot tanlang', style: TextStyle(color: Colors.grey.withOpacity(0.5), fontSize: 13.sp)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    itemCount: sales.cart.length,
                    itemBuilder: (context, index) => POSCartItem(
                      item: sales.cart[index],
                      onShowQuantityDialog: (it) => _showQuantityDialog(context, inventory, sales, it),
                    ),
                  ),
          ),
          // Moved Summary to Cart Footer
          _buildCartInlineSummary(sales),
        ],
      ),
    );
  }

  Widget _buildCartInlineSummary(SalesProvider sales) {
    final total = sales.cartTotal;
    final bool isShort = Responsive.isShort(context);
    
    return Container(
      padding: EdgeInsets.all(isShort ? 12.sp : 20.sp),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.02),
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.3))),
      ),
      child: Column(
        children: [
          if (!isShort) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Mahsulotlar soni:', style: TextStyle(color: Colors.grey, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                Text('${sales.cart.fold(0, (sum, i) => sum + i.quantity.toInt())} ta', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp)),
              ],
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Foyda (taxm.):', style: TextStyle(color: Colors.grey, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                Text('${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(sales.cartProfit)} UZS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.green)),
              ],
            ),
          ],
          if (sales.cartDiscount > 0) ...[
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Chegirma:', style: TextStyle(color: Colors.red, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                Text('-${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(sales.cartDiscount)} UZS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.sp, color: Colors.red)),
              ],
            ),
          ],
          if (!isShort) Divider(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isShort ? 'SUMMA:' : 'JAMI TO\'LOV:', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              Text(
                '${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(total)} UZS',
                style: TextStyle(fontSize: isShort ? 18.sp : 20.sp, fontWeight: FontWeight.w900, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStatusBar(SettingsProvider settings, AuthProvider auth, SyncProvider sync) {
    return AppStatusBar(
      settings: settings,
      auth: auth,
      sync: sync,
      onExit: () => Navigator.pop(context),
    );
  }

  void _handlePayment(SalesProvider sales) async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const CheckoutScreen()));
    // If checkout was successful, return to Sessions tab
    if (result == true && mounted) {
      context.read<NavigationProvider>().setIndex(0);
    }
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
            Expanded(child: _buildVerticalCartView(sales, inventory)),
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

  void _showSuspendNoteDialog(BuildContext context, SalesProvider sales) {
    final controller = TextEditingController();
    bool dialogCaps = true;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) => StatefulBuilder(
        builder: (context, setDialogState) {
          void onKeyTap(String key) {
            setDialogState(() {
              if (key == 'back') {
                if (controller.text.isNotEmpty) {
                  controller.text = controller.text.substring(0, controller.text.length - 1);
                }
              } else if (key == 'space') {
                controller.text += ' ';
              } else if (key == 'caps') {
                dialogCaps = !dialogCaps;
              } else if (key == 'clear') {
                controller.text = '';
              } else if (key == 'enter') {
                // Submit logic can be added here if needed
              } else {
                controller.text += dialogCaps ? key.toUpperCase() : key.toLowerCase();
              }
            });
          }

          return Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                // Background Tap to Dismiss
                Positioned.fill(
                  child: GestureDetector(onTap: () => Navigator.pop(context)),
                ),
                
                // Central Input Dialog
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 350), // Lift it above keyboard
                    child: Container(
                      width: 500,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                const Text(
                                  'SAVDONI KUTISHGA QO\'YISH',
                                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 0.5),
                                ),
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).dividerColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                                  ),
                                  child: TextField(
                                    controller: controller,
                                    decoration: const InputDecoration(
                                      labelText: 'Mijoz ismi yoki tel raqami',
                                      hintText: 'Ixtiyoriy...',
                                      border: InputBorder.none,
                                    ),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                    autofocus: true,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    child: const Text('BEKOR QILISH'),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await sales.suspendCurrentCart(note: controller.text);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                        context.read<NavigationProvider>().setIndex(0);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Theme.of(context).colorScheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    child: const Text('SAQLASH', style: TextStyle(fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Bottom Fixed Keyboard
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: POSVirtualKeyboard(
                    isCaps: dialogCaps,
                    onKeyTap: onKeyTap,
                    onHideKeyboard: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showSuspendedSalesDialog(BuildContext context, SalesProvider sales) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kutayotgan savdolar'),
        content: SizedBox(
          width: 400,
          child: sales.suspendedSales.where((s) => s.id != sales.resumedSuspendedId).isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Kutayotgan savdolar yo\'q')))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: sales.suspendedSales.where((s) => s.id != sales.resumedSuspendedId).length,
                  itemBuilder: (context, index) {
                    final s = sales.suspendedSales.where((s) => s.id != sales.resumedSuspendedId).toList()[index];
                    return ListTile(
                      title: Text(s.note != null && s.note!.isNotEmpty ? s.note! : 'Nomsiz savdo #${s.id.substring(s.id.length - 4)}'),
                      subtitle: Text('${DateFormat('HH:mm').format(s.date)} • ${s.items.length} ta mahsulot • ${NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0).format(s.total)}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () => sales.deleteSuspendedSale(s.id),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              sales.resumeSuspendedSale(s);
                              Navigator.pop(context);
                            },
                            child: const Text('Tiklash'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Yopish')),
        ],
      ),
    );
  }

  Widget _buildActionSidebar(SalesProvider sales, InventoryProvider inventory, SettingsProvider settings, AuthProvider auth, double width, bool isTablet) {
    return Container(
      width: width,
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          const SizedBox(height: 8),
          _buildActionBtn(
            icon: Icons.percent_rounded,
            label: 'Chegirma',
            onTap: () => _showDiscountDialog(sales),
            color: Colors.purple,
          ),
          _buildActionBtn(
            icon: Icons.assignment_return_rounded,
            label: 'Qaytarish',
            onTap: () => _showReturnsDialog(sales),
            color: Colors.redAccent,
          ),

          const Spacer(),
          _buildActionBtn(
            icon: Icons.pause_circle_filled_rounded,
            label: 'SAQLASH',
            onTap: sales.cart.isEmpty ? () {} : () => _showSuspendNoteDialog(context, sales),
            color: Colors.orange.shade700,
            isBig: true,
          ),
          _buildActionBtn(
            icon: Icons.payments_rounded,
            label: 'TO\'LOV',
            onTap: sales.cart.isEmpty ? () {} : () => _handlePayment(sales),
            color: Colors.green.shade600,
            isBig: true,
          ),
          const Divider(indent: 12, endIndent: 12),
          _buildActionBtn(
            icon: settings.themeMode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            label: settings.themeMode == ThemeMode.dark ? 'KUN' : 'TUN',
            onTap: () {
              settings.setThemeMode(settings.themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
            },
            color: settings.themeMode == ThemeMode.dark ? Colors.amber : Colors.blueGrey,
          ),
          const Divider(indent: 12, endIndent: 12),
          _buildActionBtn(
            icon: Icons.logout_rounded,
            label: 'Chiqish',
            onTap: () {
              context.read<NavigationProvider>().setIndex(0);
            },
            color: Colors.blueGrey,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isBig = false,
  }) {
    final bool isShort = Responsive.isShort(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isShort ? 2.h : 4.h, horizontal: 8.sp),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Responsive.borderRadius),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: isShort ? (isBig ? 10.h : 4.h) : (isBig ? 16.h : 8.h)),
          decoration: BoxDecoration(
            color: isBig ? color : color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(Responsive.borderRadius),
            border: isBig ? null : Border.all(color: color.withOpacity(0.2), width: 1.5),
            boxShadow: isBig ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8.sp, offset: Offset(0, 4.h))] : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isBig ? Colors.white : color, size: isBig ? 24.sp : 20.sp),
              SizedBox(height: isBig ? 8.h : 4.h),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isBig ? Colors.white : color,
                  fontWeight: FontWeight.w900,
                  fontSize: isBig ? 12.sp : 10.sp,
                  letterSpacing: isBig ? 0.5 : 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalCategoryBar(List<String> categories) {
    final bool isShort = Responsive.isShort(context);
    return Container(
      height: isShort ? 50.h : 60.h,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.2))),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 12.sp, vertical: 8.h),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = selectedCategory == cat;
          return Padding(
            padding: EdgeInsets.only(right: 12.sp),
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedCategory = cat;
                  _currentPage = 1;
                });
              },
              borderRadius: BorderRadius.circular(Responsive.borderRadius),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 20.sp),
                decoration: BoxDecoration(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(Responsive.borderRadius),
                  boxShadow: isSelected ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withOpacity(0.3), blurRadius: 8.sp, offset: Offset(0, 4.h))] : [],
                ),
                alignment: Alignment.center,
                child: Text(
                  cat,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.8),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showDiscountDialog(SalesProvider sales) {
    if (sales.cart.isEmpty) return;
    
    final controller = TextEditingController(
      text: sales.cartDiscount == 0 ? '' : sales.cartDiscount.toStringAsFixed(0)
    );
    final fmt = NumberFormat.currency(locale: 'uz_UZ', symbol: '', decimalDigits: 0);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void onNumPressed(String val) {
            setDialogState(() {
              if (val == 'C') {
                controller.clear();
              } else if (val == 'back') {
                if (controller.text.isNotEmpty) {
                  controller.text = controller.text.substring(0, controller.text.length - 1);
                }
              } else {
                controller.text += val;
              }
            });
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Row(
              children: [
                Icon(Icons.percent_rounded, color: Colors.purple),
                SizedBox(width: 12),
                Text('Chegirma qo\'llash'),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                     Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.purple.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              controller.text.isEmpty ? '0' : fmt.format(double.tryParse(controller.text) ?? 0),
                              textAlign: TextAlign.right,
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.purple),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('UZS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.6,
                      children: [
                        for (var i = 1; i <= 9; i++) _buildDialogNumBtn(i.toString(), onNumPressed),
                        _buildDialogNumBtn('C', onNumPressed, color: Colors.red.shade50, textColor: Colors.red),
                        _buildDialogNumBtn('0', onNumPressed),
                        _buildDialogNumBtn('back', onNumPressed, icon: Icons.backspace_outlined, color: Colors.grey.shade100),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Eslatma: Chegirma umumiy savat summasidan ayriladi.', 
                      style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('Bekor qilish')
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(120, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  final discount = double.tryParse(controller.text) ?? 0.0;
                  sales.setCartDiscount(discount);
                  Navigator.pop(context);
                },
                child: const Text('QO\'LLASH', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }

  Widget _buildDialogNumBtn(String val, Function(String) onTap, {Color? color, Color? textColor, IconData? icon}) {
    return Material(
      color: color ?? Theme.of(context).dividerColor.withOpacity(0.05),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => onTap(val),
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.grey.shade700, size: 22)
              : Text(
                  val,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor ?? Theme.of(context).colorScheme.onSurface,
                  ),
                ),
        ),
      ),
    );
  }

  void _showCustomerDialog(SalesProvider sales) {
    final controller = TextEditingController(text: sales.cartCustomerName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mijoz biriktirish'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Mijoz ismi',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.person),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              sales.setCartCustomer(null, null);
              Navigator.pop(context);
            },
            child: const Text('Tozalash', style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                sales.setCartCustomer(DateTime.now().millisecondsSinceEpoch.toString(), controller.text);
              }
              Navigator.pop(context);
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  void _showReturnsDialog(SalesProvider sales) {
    if (sales.cart.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.assignment_return_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text('Qaytarishni Tasdiqlash'),
            ],
          ),
          content: Text('Savatdagi ${sales.cart.length} ta mahsulotni qaytarishni (vazvrat) tasdiqlaysizmi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final settings = context.read<SettingsProvider>();
                  await sales.processReturn(
                    registerId: settings.currentRegister?.id,
                    warehouseId: settings.currentRegister?.warehouseId,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mahsulotlar muvaffaqiyatli qaytarildi', style: TextStyle(fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('TASDIQLASH'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oxirgi sotuvlar (Qaytarish uchun)'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: sales.sales.isEmpty 
            ? const Center(child: Text('Sotuvlar mavjud emas'))
            : ListView.builder(
                itemCount: sales.sales.length,
                itemBuilder: (context, index) {
                  final sale = sales.sales[index];
                  return ListTile(
                    title: Text('Chek #${sale.id.substring(sale.id.length - 4)}'),
                    subtitle: Text('${DateFormat('dd.MM.yyyy HH:mm').format(sale.date)} - ${NumberFormat.currency(locale: 'uz_UZ', symbol: '').format(sale.total)} UZS'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Qaytarish funksiyasi keyingi versiyada...')));
                       Navigator.pop(context);
                    },
                  );
                },
              ),
        ),
      ),
    );
  }

  void _reprintLastReceipt(SalesProvider sales) {
    if (sales.sales.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chop etish uchun sotuv topilmadi')));
      return;
    }
    final lastSale = sales.sales.first;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chek #${lastSale.id.substring(lastSale.id.length-4)} chop etilmoqda...')));
  }
}
