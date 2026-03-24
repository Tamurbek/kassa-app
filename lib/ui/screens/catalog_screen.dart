import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import 'product_form_screen.dart';
import 'barcode_print_screen.dart';
import '../../services/print_service.dart';
import 'dart:io';
import '../../services/excel_import_service.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildProductList(isNarrow),
                    _buildCategoryList(isNarrow),
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
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Katalog',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              Text(
                'Mahsulotlar va turlarni boshqarish',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () {
              if (_tabController.index == 0) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProductFormScreen(),
                  ),
                );
              } else {
                _showCategoryDialog(null);
              }
            },
            icon: Icon(Icons.add),
            label: isNarrow
                ? Text('Qo\'shish')
                : Text(
                    _tabController.index == 0 ? 'Yangi mahsulot' : 'Yangi tur',
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 16 : 24,
                vertical: 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          SizedBox(width: 12),
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BarcodePrintScreen()),
            ),
            icon: const Icon(Icons.qr_code_2_rounded),
            tooltip: 'Shtrix-kodlarni chop etish',
            style: IconButton.styleFrom(
              backgroundColor: Colors.teal.withOpacity(0.1),
              foregroundColor: Colors.teal,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          SizedBox(width: 12),
          IconButton(
            onPressed: () => ExcelImportService.downloadTemplate(context),
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Excel shablonini yuklab olish',
            style: IconButton.styleFrom(
              backgroundColor: Colors.amber.withOpacity(0.1),
              foregroundColor: Colors.amber.shade800,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          SizedBox(width: 12),
          IconButton(
            onPressed: () => ExcelImportService.importProducts(context),
            icon: const Icon(Icons.file_upload_outlined),
            tooltip: 'Exceldan import qilish',
            style: IconButton.styleFrom(
              backgroundColor: Colors.indigo.withOpacity(0.1),
              foregroundColor: Colors.indigo,
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (widget.onMenuPressed != null) ...[
            SizedBox(width: 16),
            IconButton(
              icon: Icon(
                Icons.menu_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 28,
              ),
              onPressed: widget.onMenuPressed,
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: Theme.of(context).cardColor,
      child: TabBar(
        controller: _tabController,
        onTap: (index) => setState(() {}),
        labelColor: Theme.of(context).colorScheme.primary,
        unselectedLabelColor: Colors.grey,
        indicatorColor: Theme.of(context).colorScheme.primary,
        tabs: const [
          Tab(text: 'Mahsulotlar'),
          Tab(text: 'Kategoriyalar'),
        ],
      ),
    );
  }

  Widget _buildProductList(bool isNarrow) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final query = _searchController.text.toLowerCase();
        final filtered = state.activeProducts
            .where(
              (p) =>
                  p.name.toLowerCase().contains(query) ||
                  p.barcode.contains(query),
            )
            .toList();
        final fmt = NumberFormat.currency(
          locale: 'uz_UZ',
          symbol: '',
          decimalDigits: 0,
        );

        return Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Mahsulotlarni qidirish...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  filled: true,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(24),
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final product = filtered[index];
                  final category = state.activeCategories.firstWhere(
                    (c) => c.id == product.categoryId,
                    orElse: () => Category(id: '', name: ''),
                  );
                  return _buildItemCard(
                    title: product.name,
                    subtitle: '${category.name} • ${product.barcode}',
                    trailing: '${fmt.format(product.price)} s',
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductFormScreen(product: product),
                      ),
                    ),
                    onDelete: () => state.deleteProduct(product.id),
                    onPrint: () => PrintService.printBarcodeLabel(
                      product: product,
                      printerName: state.barcodePrinterName,
                    ),
                    isNarrow: isNarrow,
                    imagePath: product.imagePath,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryList(bool isNarrow) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        final activeCategories = state.activeCategories;
        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: activeCategories.length,
          itemBuilder: (context, index) {
            final category = activeCategories[index];
            final count = state.activeProducts
                .where((p) => p.categoryId == category.id)
                .length;
            return _buildItemCard(
              title: category.name,
              subtitle: '$count ta mahsulot',
              trailing: '',
              onEdit: () => _showCategoryDialog(category),
              onDelete: () => state.deleteCategory(category.id),
              onPrint: null,
              isNarrow: isNarrow,
            );
          },
        );
      },
    );
  }

  Widget _buildItemCard({
    required String title,
    required String subtitle,
    required String trailing,
    required VoidCallback onEdit,
    required VoidCallback onDelete,
    VoidCallback? onPrint,
    required bool isNarrow,
    String? imagePath,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.02,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              image: imagePath != null
                  ? DecorationImage(
                      image: FileImage(File(imagePath)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: imagePath == null
                ? Icon(
                    Icons.inventory_2_outlined,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  )
                : null,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!isNarrow && trailing.isNotEmpty)
            Text(
              trailing,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          SizedBox(width: 8),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
            onPressed: onEdit,
          ),
          if (onPrint != null)
            IconButton(
              icon: Icon(Icons.print_outlined, size: 20, color: Colors.teal),
              onPressed: onPrint,
            ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  void _showCategoryDialog(Category? category) {
    final controller = TextEditingController(text: category?.name ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          category == null ? 'Yangi kategoriya' : 'Kategoriyani tahrirlash',
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Kategoriya nomi'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Bekor qilish'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                if (category == null) {
                  context.read<AppState>().addCategory(controller.text);
                } else {
                  context.read<AppState>().updateCategory(
                    category.id,
                    controller.text,
                  );
                }
                Navigator.pop(context);
              }
            },
            child: Text('Saqlash'),
          ),
        ],
      ),
    );
  }
}
