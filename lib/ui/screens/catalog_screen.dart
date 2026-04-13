import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/settings_provider.dart';
import '../../models/models.dart';
import 'product_form_screen.dart';
import '../../services/excel_import_service.dart';
import '../../services/starter_data_service.dart';

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
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 700;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              _buildHeader(isNarrow),
              TabBar(
                controller: _tabController,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Colors.grey.shade400,
                indicatorColor: Theme.of(context).colorScheme.primary,
                tabs: const [
                  Tab(text: 'Mahsulotlar'),
                  Tab(text: 'Kategoriyalar'),
                ],
              ),
              _buildSearchBar(),
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
        );
      },
    );
  }

  Widget _buildHeader(bool isNarrow) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/icon.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              if (!isNarrow) const SizedBox(width: 16),
              if (!isNarrow)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Katalog',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Kategoriyalar va mahsulotlar boshqaruvi',
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Row(
            children: [
              _buildActionButton(
                icon: Icons.download_rounded,
                label: isNarrow ? null : 'Shablon',
                onTap: () => ExcelImportService.downloadTemplate(context),
                color: Colors.blueGrey,
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.upload_file_rounded,
                label: isNarrow ? null : 'Excel Import',
                onTap: () => ExcelImportService.importFromExcel(context),
                color: Colors.green,
              ),
              if (!context.watch<SettingsProvider>().isStarterDataLoaded)
                _buildActionButton(
                  icon: Icons.auto_awesome_motion_rounded,
                  label: isNarrow ? null : '500 Mahsulot',
                  onTap: () => _loadStarterData(context),
                  color: Colors.orange,
                ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.add_circle_outline_rounded,
                label: isNarrow ? null : 'Yangi qo\'shish',
                onTap: () {
                  if (_tabController.index == 0) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProductFormScreen(),
                      ),
                    );
                  } else {
                    final inventory = context.read<InventoryProvider>();
                    _showCategoryDialog(inventory, null);
                  }
                },
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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      color: Theme.of(context).cardColor.withOpacity(0.5),
      child: TextField(
        controller: _searchController,
        onChanged: (val) => setState(() => _searchText = val.toLowerCase()),
        decoration: InputDecoration(
          hintText: _tabController.index == 0
              ? 'Mahsulot nomi yoki shtrix-kodi bo\'yicha qidirish...'
              : 'Kategoriya nomi bo\'yicha qidirish...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _searchText.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchText = '');
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
      icon: Icon(icon, size: 20),
      label: label != null ? Text(label) : const SizedBox.shrink(),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildProductsTab() {
    return Consumer<InventoryProvider>(
      builder: (context, inventory, child) {
        final products = inventory.activeProducts.where((p) {
          if (_searchText.isEmpty) return true;
          return p.name.toLowerCase().contains(_searchText) ||
              p.barcode.toLowerCase().contains(_searchText);
        }).toList();

        if (products.isEmpty) {
          return Center(
            child: Text(_searchText.isEmpty
                ? 'Mahsulotlar mavjud emas'
                : 'Qidiruv bo\'yicha mahsulot topilmadi'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final p = products[index];
            return _buildListItem(
              title: p.name,
              subtitle: 'Shtrix: ${p.barcode}',
              onEdit: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProductFormScreen(product: p),
                ),
              ),
              onDelete: () => _confirmDelete(
                context,
                'Mahsulotni o\'chirmoqchimisiz?',
                () => inventory.deleteProduct(p.id),
              ),
            );
          },
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
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

  void _loadStarterData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final count = await StarterDataService.seed1000Products();
      if (context.mounted) {
        Navigator.pop(context); // Close indicator
        await context.read<SettingsProvider>().markStarterDataAsLoaded();
        await context.read<InventoryProvider>().reloadData(skipRecalculate: true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count ta real mahsulot muvaffaqiyatli yuklandi!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Xatolik: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
