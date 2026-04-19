import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../../models/models.dart';
import 'product_form_screen.dart';
import '../../services/excel_import_service.dart';
import '../../core/utils/responsive.dart';
import '../../providers/features/navigation_provider.dart';

class CatalogScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const CatalogScreen({super.key, this.onMenuPressed});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _selectedCategoryId; // null means "Barchasi"
  String _searchText = '';
  
  List<Product> _products = [];
  int _offset = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _isSearching = false;
  final int _limit = 50;
  
  final Set<String> _selectedProductIds = {};
  
  Timer? _debounce;

  InventoryProvider? _inventoryProvider;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index != 0) {
        setState(() {
          _selectedProductIds.clear();
        });
      } else {
        setState(() {});
      }
    });
    
    _scrollController.addListener(_onScroll);
    
    // Initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProducts(reset: true);
    });

    // Listen to DB changes to refresh
    _inventoryProvider = context.read<InventoryProvider>();
    _inventoryProvider?.addListener(_handleInventoryUpdate);
  }

  void _handleInventoryUpdate() {
    // Only auto-reload if the user is NOT actively searching
    if (mounted && _searchText.isEmpty) {
      _loadProducts(reset: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore && _tabController.index == 0) {
        _loadProducts();
      }
    }
  }

  Future<void> _loadProducts({bool reset = false}) async {
    if (_isLoadingMore) return;

    if (reset) {
      _offset = 0;
      _hasMore = true;
      // We don't clear _products here to avoid the "flicker"
    }

    if (!_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      if (reset) _isSearching = true;
    });

    try {
      final products = await context.read<InventoryProvider>().getProductsPaged(
        limit: _limit,
        offset: _offset,
        search: _searchText,
        categoryId: _selectedCategoryId,
      );

      if (mounted) {
        setState(() {
          if (reset) {
            _products = products;
          } else {
            _products.addAll(products);
          }
          _offset += _limit;
          _hasMore = products.length == _limit;
          _isLoadingMore = false;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _isLoadingMore = false;
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    _inventoryProvider?.removeListener(_handleInventoryUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              _buildHeader(constraints.maxWidth),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Theme.of(context).colorScheme.primary,
                indicatorWeight: 3.h,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                tabs: const [
                  Tab(text: 'Mahsulotlar'),
                  Tab(text: 'Kategoriyalar'),
                ],
              ),
              _buildSearchBar(),
               if (_tabController.index == 0) _buildSelectionBar(),
               if (_tabController.index == 0) _buildCategoryFilterBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProductsTab(),
                    _buildCategoriesTab(),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: (_selectedProductIds.isNotEmpty)
            ? FloatingActionButton.extended(
                onPressed: _deleteSelectedProducts,
                label: Text('${_selectedProductIds.length} tani o\'chirish'),
                icon: const Icon(Icons.delete_sweep_rounded),
                backgroundColor: Colors.redAccent,
              )
            : null,
        );
      },
    );
  }

  Widget _buildSelectionBar() {
    bool allVisibleSelected = _products.isNotEmpty && _products.every((p) => _selectedProductIds.contains(p.id));
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: allVisibleSelected,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedProductIds.addAll(_products.map((p) => p.id));
                } else {
                  for (var p in _products) {
                    _selectedProductIds.remove(p.id);
                  }
                }
              });
            },
          ),
          Text(
            'Barchasini belgilash (${_products.length})',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
          ),
          const Spacer(),
          if (_selectedProductIds.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _selectedProductIds.clear()),
              child: const Text('Tanlovni tozalash'),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedProducts() async {
    if (_selectedProductIds.isEmpty) return;
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tasdiqlash'),
        content: Text('${_selectedProductIds.length} ta mahsulotni o\'chirmoqchimisiz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Yo\'q')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Ha, o\'chirilsin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final inventory = context.read<InventoryProvider>();
      await inventory.deleteProductsBatch(_selectedProductIds.toList());
      setState(() {
        _selectedProductIds.clear();
      });
      _loadProducts(reset: true);
    }
  }

  Widget _buildHeader(double width) {
    final bool isShort = Responsive.isShort(context);
    final bool showLabels = width > 900;
    final bool showChips = width > 1000;
    final bool showTitle = width > 800;

    return Container(
      padding: EdgeInsets.all(isShort ? 12.sp : 24.sp),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context)) ...[
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
              ] else ...[
                IconButton(
                  onPressed: () => context.read<NavigationProvider>().openSessions(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/icon.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              if (showTitle) const SizedBox(width: 16),
              if (showTitle)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Katalog',
                      style: TextStyle(
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              if (showChips) ...[
                const SizedBox(width: 32),
                _buildCountChip(
                  label: 'Mahsulotlar:',
                  count: context.watch<InventoryProvider>().activeProducts.length,
                  color: Colors.blue,
                ),
                const SizedBox(width: 12),
                _buildCountChip(
                  label: 'Kategoriyalar:',
                  count: context.watch<InventoryProvider>().activeCategories.length,
                  color: Colors.purple,
                ),
              ],
            ],
          ),
          Row(
            children: [
              _buildActionButton(
                icon: Icons.add_circle_outline_rounded,
                label: showLabels ? 'Yangi qo\'shish' : null,
                onTap: () {
                  if (_tabController.index == 0) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProductFormScreen(),
                      ),
                    ).then((_) => _loadProducts(reset: true));
                  } else {
                    final inventory = context.read<InventoryProvider>();
                    _showCategoryDialog(inventory, null);
                  }
                },
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded),
                onSelected: (value) {
                  switch (value) {
                    case 'template': ExcelImportService.downloadTemplate(context); break;
                    case 'import': ExcelImportService.importFromExcel(context); break;
                    case 'dupes': _checkDuplicates(); break;
                    case 'missing': _checkMissingBarcodes(); break;
                    case 'scale_export': 
                      ExcelImportService.exportForScale(context, inventory.products); 
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'import',
                    child: ListTile(
                      leading: Icon(Icons.upload_file_rounded, color: Colors.green),
                      title: Text('Excel Import'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'template',
                    child: ListTile(
                      leading: Icon(Icons.download_rounded, color: Colors.blueGrey),
                      title: Text('Shablonni yuklash'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'scale_export',
                    child: ListTile(
                      leading: Icon(Icons.scale_rounded, color: Colors.indigo),
                      title: Text('Taroziga eksport'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'dupes',
                    child: ListTile(
                      leading: Icon(Icons.copy_all_rounded, color: Colors.orange),
                      title: Text('Dublikatlarni aniqlash'),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'missing',
                    child: ListTile(
                      leading: Icon(Icons.barcode_reader, color: Colors.redAccent),
                      title: Text('Shtrix-kodsiz mahsulotlar'),
                      dense: true,
                    ),
                  ),
                ],
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.menu_rounded, size: 28),
            onPressed: widget.onMenuPressed,
            color: Theme.of(context).colorScheme.primary,
            tooltip: 'Menyu',
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(24.sp, 16.sp, 24.sp, 0),
          color: Theme.of(context).cardColor.withOpacity(0.5),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              if (_debounce?.isActive ?? false) _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 500), () {
                if (mounted) {
                  setState(() => _searchText = val.toLowerCase());
                  if (_tabController.index == 0) _loadProducts(reset: true);
                }
              });
            },
            decoration: InputDecoration(
              hintText: _tabController.index == 0
                  ? 'Mahsulot nomi yoki shtrix-kodi...'
                  : 'Kategoriya nomi...',
              prefixIcon: Icon(Icons.search_rounded, size: 20.sp),
              suffixIcon: _searchText.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchText = '');
                        if (_tabController.index == 0) _loadProducts(reset: true);
                      },
                    )
                  : null,
              filled: true,
              fillColor: Theme.of(context).scaffoldBackgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Theme.of(context).dividerColor),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        if (_isSearching)
          const LinearProgressIndicator(minHeight: 2),
      ],
    );
  }

  Widget _buildCategoryFilterBar() {
    final inventory = context.watch<InventoryProvider>();
    final categories = inventory.activeCategories;

    return Container(
      height: 50.h,
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          _buildCategoryChip(
            id: null,
            name: 'Barchasi',
            isSelected: _selectedCategoryId == null,
            onTap: () {
              setState(() => _selectedCategoryId = null);
              _loadProducts(reset: true);
            },
          ),
          ...categories.map((c) => _buildCategoryChip(
                id: c.id,
                name: c.name,
                isSelected: _selectedCategoryId == c.id,
                onTap: () {
                  setState(() => _selectedCategoryId = c.id);
                  _loadProducts(reset: true);
                },
              )),
        ],
      ),
    );
  }

  Widget _buildCategoryChip({
    required String? id,
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(name),
        selected: isSelected,
        onSelected: (_) => onTap(),
        backgroundColor: Theme.of(context).cardColor,
        selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).colorScheme.primary : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  Widget _buildCountChip({
    required String label,
    required int count,
    required Color color,
  }) {
    final bool isShort = Responsive.isShort(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.sp, vertical: isShort ? 6.h : 10.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.sp,
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 14.sp,
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    String? label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20.sp),
      label: label != null 
        ? Text(label, style: TextStyle(fontSize: 14.sp)) 
        : const SizedBox.shrink(),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.borderRadius)),
      ),
    );
  }

  Widget _buildProductsTab() {
    if (_products.isEmpty && _isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_products.isEmpty) {
      return Center(
        child: Text(_searchText.isEmpty
            ? 'Mahsulotlar mavjud emas'
            : 'Qidiruv bo\'yicha mahsulot topilmadi'),
      );
    }

    final inventory = context.read<InventoryProvider>();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(24),
      itemCount: _products.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _products.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final p = _products[index];
        final isSelected = _selectedProductIds.contains(p.id);
        
        return _buildListItem(
          title: p.name,
          subtitle: 'Shtrix: ${p.barcode}',
          isSelected: isSelected,
          onTap: () {
            setState(() {
              if (isSelected) {
                _selectedProductIds.remove(p.id);
              } else {
                _selectedProductIds.add(p.id);
              }
            });
          },
          onEdit: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProductFormScreen(product: p),
            ),
          ).then((_) => _loadProducts(reset: true)),
          onDelete: () => _confirmDelete(
            context,
            'Mahsulotni o\'chirmoqchimisiz?',
            () async {
              await inventory.deleteProduct(p.id);
              _loadProducts(reset: true);
            },
          ),
        );
      },
    );
  }

  Widget _buildCategoriesTab() {
    return Consumer<InventoryProvider>(
      builder: (context, inventory, child) {
        final categories = inventory.activeCategories.where((c) {
          if (_searchText.isEmpty) return true;
          return c.name.toLowerCase().contains(_searchText);
        }).toList();

        if (categories.isEmpty) {
          return Center(
            child: Text(_searchText.isEmpty
                ? 'Kategoriyalar mavjud emas'
                : 'Qidiruv bo\'yicha kategoriya topilmadi'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final c = categories[index];
            return _buildListItem(
              title: c.name,
              subtitle: 'ID: ${c.id.length > 8 ? c.id.substring(0, 8) : c.id}',
              onEdit: () => _showCategoryDialog(inventory, c),
              onDelete: () => _confirmDelete(
                context,
                'Kategoriyani o\'chirmoqchimisiz?',
                () => inventory.deleteCategory(c.id),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildListItem({
    required String title,
    required String subtitle,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected 
          ? Theme.of(context).colorScheme.primary.withOpacity(0.05) 
          : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(Responsive.borderRadius),
        border: Border.all(
          color: isSelected 
            ? Theme.of(context).colorScheme.primary 
            : Theme.of(context).dividerColor,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Checkbox(
          value: isSelected,
          activeColor: Theme.of(context).colorScheme.primary,
          onChanged: (_) => onTap?.call(),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12.sp)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tasdiqlash'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Yo\'q'),
          ),
          ElevatedButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(context);
            },
            child: const Text('Ha, o\'chirilsin'),
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog(InventoryProvider inventory, Category? category) {
    final controller = TextEditingController(text: category?.name ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category == null ? 'Yangi kategoriya' : 'Kategoriyani tahrirlash'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Kategoriya nomi'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                if (category == null) {
                  inventory.saveCategory(Category(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    name: controller.text,
                  ));
                } else {
                  inventory.saveCategory(category.copyWith(name: controller.text));
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Saqlash'),
          ),
        ],
      ),
    );
  }

  void _checkDuplicates() {
    final inventory = context.read<InventoryProvider>();
    final products = inventory.activeProducts;

    Map<String, List<Product>> barcodeDupes = {};
    Map<String, List<Product>> nameDupes = {};

    for (var p in products) {
      // Collect all barcodes for this product to check uniqueness
      final allBarcodes = [p.barcode, ...p.additionalBarcodes, p.boxBarcode ?? '', ...p.additionalBoxBarcodes]
          .where((b) => b.isNotEmpty).toSet();
      
      for (var b in allBarcodes) {
        barcodeDupes.putIfAbsent(b, () => []).add(p);
      }

      String normalizedName = p.name.toLowerCase().trim();
      if (normalizedName.isNotEmpty) {
        nameDupes.putIfAbsent(normalizedName, () => []).add(p);
      }
    }

    // Filter only those that have 2 or more products
    barcodeDupes.removeWhere((key, list) => list.length < 2);
    nameDupes.removeWhere((key, list) => list.length < 2);

    if (barcodeDupes.isEmpty && nameDupes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dublikatlar topilmadi'), backgroundColor: Colors.green),
      );
      return;
    }

    _showDuplicatesDialog(barcodeDupes, nameDupes);
  }

  void _showDuplicatesDialog(Map<String, List<Product>> barcodeDupes, Map<String, List<Product>> nameDupes) {
    Set<String> selectedIds = {};
    
    // Collect all unique IDs present in the dialog to handle "Select All"
    Set<String> allDupeIds = {};
    for (var list in barcodeDupes.values) {
      for (var p in list) allDupeIds.add(p.id);
    }
    for (var list in nameDupes.values) {
      for (var p in list) allDupeIds.add(p.id);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Topilgan dublikatlar'),
            content: SizedBox(
              width: 600,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Barchasini belgilash', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: selectedIds.length == allDupeIds.length && allDupeIds.isNotEmpty,
                      onChanged: (val) => setDialogState(() {
                        if (val == true) {
                          selectedIds.addAll(allDupeIds);
                        } else {
                          selectedIds.clear();
                        }
                      }),
                    ),
                    const Divider(),
                    if (barcodeDupes.isNotEmpty) ...[
                      const Text('Bir xil shtrix-kodli mahsulotlar:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                      const SizedBox(height: 10),
                      ...barcodeDupes.entries.map((entry) => _buildDupeEntry(
                            entry.key,
                            entry.value,
                            selectedIds,
                            (id, val) => setDialogState(() {
                              if (val) selectedIds.add(id);
                              else selectedIds.remove(id);
                            }),
                          )),
                    ],
                    if (nameDupes.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text('Bir xil nomli mahsulotlar:',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      const SizedBox(height: 10),
                      ...nameDupes.entries.map((entry) => _buildDupeEntry(
                            entry.key,
                            entry.value,
                            selectedIds,
                            (id, val) => setDialogState(() {
                              if (val) selectedIds.add(id);
                              else selectedIds.remove(id);
                            }),
                          )),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              if (selectedIds.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Tasdiqlash'),
                        content: Text('${selectedIds.length} ta mahsulotni o\'chirmoqchimisiz?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Yo\'q')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Ha, o\'chirilsin', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true) {
                      await context.read<InventoryProvider>().deleteProductsBatch(selectedIds.toList());
                      if (context.mounted) {
                        Navigator.pop(context); // Close dupe dialog
                        _loadProducts(reset: true);
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_sweep, size: 18),
                  label: Text('${selectedIds.length} tani o\'chirish'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Yopish')),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDupeEntry(String key, List<Product> list, Set<String> selectedIds, Function(String, bool) onSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(key, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Divider(),
          ...list.map((p) {
            final isSelected = selectedIds.contains(p.id);
            return ListTile(
              dense: true,
              leading: Checkbox(
                value: isSelected,
                onChanged: (val) => onSelected(p.id, val ?? false),
              ),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Shtrix: ${p.barcode}'),
              onTap: () => onSelected(p.id, !isSelected),
              trailing: IconButton(
                icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)),
                  ).then((_) => _loadProducts(reset: true));
                },
              ),
            );
          }),
        ],
      ),
    );
  }
  void _checkMissingBarcodes() {
    final inventory = context.read<InventoryProvider>();
    final missing = inventory.activeProducts.where((p) {
      final b = p.barcode.trim().toLowerCase();
      return b.isEmpty || b == '0' || b == 'yo\'q' || b == 'yoq' || b == 'bo\'sh' || b == 'bosh' || b == 'kelmagan';
    }).toList();

    if (missing.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shtrix-kodi yo\'q mahsulotlar topilmadi'), backgroundColor: Colors.green),
      );
      return;
    }

    _showMissingBarcodesDialog(missing);
  }

  void _showMissingBarcodesDialog(List<Product> missing) {
    Set<String> selectedIds = {};
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('Shtrix-kodsiz mahsulotlar (${missing.length})'),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Ushbu mahsulotlarda shtrix-kod mavjud emas. Ularni tanlab, avtomatik kod berishingiz mumkin.'),
                    const SizedBox(height: 16),
                    CheckboxListTile(
                      controlAffinity: ListTileControlAffinity.leading,
                      title: const Text('Barchasini belgilash', style: TextStyle(fontWeight: FontWeight.bold)),
                      value: selectedIds.length == missing.length,
                      onChanged: (val) => setDialogState(() {
                        if (val == true) {
                          selectedIds.addAll(missing.map((p) => p.id));
                        } else {
                          selectedIds.clear();
                        }
                      }),
                    ),
                    const Divider(),
                    ...missing.map((p) {
                      final isSelected = selectedIds.contains(p.id);
                      return ListTile(
                        dense: true,
                        leading: Checkbox(
                          value: isSelected,
                          onChanged: (val) => setDialogState(() {
                            if (val == true) selectedIds.add(p.id);
                            else selectedIds.remove(p.id);
                          }),
                        ),
                        title: Text(p.name),
                        onTap: () => setDialogState(() {
                          if (isSelected) selectedIds.remove(p.id);
                          else selectedIds.add(p.id);
                        }),
                        trailing: IconButton(
                          icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => ProductFormScreen(product: p)),
                            ).then((_) => _loadProducts(reset: true));
                          },
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
            actions: [
              if (selectedIds.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: () async {
                    final inventory = context.read<InventoryProvider>();
                    List<Product> updated = [];
                    for (var id in selectedIds) {
                      final p = missing.firstWhere((p) => p.id == id);
                      updated.add(p.copyWith(barcode: inventory.generateBarcode()));
                    }
                    await inventory.saveProductsBatch(updated);
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${updated.length} ta mahsulotga avtomatik kod berildi')),
                      );
                      _loadProducts(reset: true);
                    }
                  },
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: Text('${selectedIds.length} taga kod berish'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                ),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Yopish')),
            ],
          );
        },
      ),
    );
  }
}
