import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/features/inventory_provider.dart';
import '../../providers/features/auth_provider.dart';
import '../../models/models.dart';

class TrashScreen extends StatefulWidget {
  final VoidCallback? onMenuPressed;
  const TrashScreen({super.key, this.onMenuPressed});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _selectedIds.clear());
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          _buildHeader(),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Colors.grey.shade400,
            indicatorColor: Theme.of(context).colorScheme.primary,
            tabs: const [
              Tab(text: 'Mahsulotlar'),
              Tab(text: 'Kategoriyalar'),
              Tab(text: 'Hodimlar'),
              Tab(text: 'Omborlar'),
              Tab(text: 'Kassalar'),
            ],
          ),
          _buildSelectionBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDeletedProducts(),
                _buildDeletedCategories(),
                _buildDeletedUsers(),
                _buildDeletedWarehouses(),
                _buildDeletedRegisters(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBar() {
    final inventory = context.watch<InventoryProvider>();
    final auth = context.watch<AuthProvider>();
    
    List<dynamic> currentList = [];
    switch (_tabController.index) {
      case 0: currentList = inventory.deletedProducts; break;
      case 1: currentList = inventory.deletedCategories; break;
      case 2: currentList = auth.deletedUsers; break;
      case 3: currentList = inventory.deletedWarehouses; break;
      case 4: currentList = inventory.deletedRegisters; break;
    }

    if (currentList.isEmpty) return const SizedBox.shrink();

    bool allSelected = currentList.isNotEmpty && currentList.every((item) => _selectedIds.contains(item.id));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: (val) {
              setState(() {
                if (val == true) {
                  _selectedIds.addAll(currentList.map((e) => e.id as String));
                } else {
                  for (var e in currentList) { _selectedIds.remove(e.id); }
                }
              });
            },
          ),
          Text(
            'Barchasini belgilash (${currentList.length})',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (_selectedIds.isNotEmpty) ...[
            TextButton.icon(
              onPressed: () => _handleBatchRestore(inventory, auth),
              icon: const Icon(Icons.restore, size: 18),
              label: const Text('Tiklash'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => _handleBatchHardDelete(inventory, auth),
              icon: const Icon(Icons.delete_forever_rounded, size: 18, color: Colors.red),
              label: const Text('Tozalash', style: TextStyle(color: Colors.red)),
            ),
          ] else
            TextButton.icon(
              onPressed: () => _handleEmptyTrash(currentList.map((e) => e.id as String).toList(), inventory, auth),
              icon: const Icon(Icons.delete_sweep_rounded, size: 18, color: Colors.grey),
              label: const Text('Savatni bo\'shatish', style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    );
  }

  Future<void> _handleBatchRestore(InventoryProvider inventory, AuthProvider auth) async {
    final ids = _selectedIds.toList();
    switch (_tabController.index) {
      case 0: await inventory.restoreProductsBatch(ids); break;
      case 1: await inventory.restoreCategoriesBatch(ids); break;
      case 2: await auth.restoreUsersBatch(ids); break;
      case 3: await inventory.restoreWarehousesBatch(ids); break;
      case 4: await inventory.restoreRegistersBatch(ids); break;
    }
    setState(() => _selectedIds.clear());
  }

  Future<void> _handleBatchHardDelete(InventoryProvider inventory, AuthProvider auth) async {
    final confirmed = await _showConfirmDialog('Tanlanganlarni butunlay o\'chirmoqchimisiz?');
    if (confirmed != true) return;

    final ids = _selectedIds.toList();
    await _performHardDelete(ids, inventory, auth);
    setState(() => _selectedIds.clear());
  }

  Future<void> _handleEmptyTrash(List<String> ids, InventoryProvider inventory, AuthProvider auth) async {
    final confirmed = await _showConfirmDialog('Ushbu bo\'limdagi barcha ma\'lumotlarni butunlay o\'chirmoqchimisiz?');
    if (confirmed != true) return;

    await _performHardDelete(ids, inventory, auth);
  }

  Future<void> _performHardDelete(List<String> ids, InventoryProvider inventory, AuthProvider auth) async {
    switch (_tabController.index) {
      case 0: await inventory.hardDeleteProductsBatch(ids); break;
      case 1: await inventory.hardDeleteCategoriesBatch(ids); break;
      case 2: await auth.hardDeleteUsersBatch(ids); break;
      case 3: await inventory.hardDeleteWarehousesBatch(ids); break;
      case 4: await inventory.hardDeleteRegistersBatch(ids); break;
    }
  }

  Future<bool?> _showConfirmDialog(String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tasdiqlash'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Yo\'q')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Ha, o\'chirilsin', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (Navigator.canPop(context))
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/icon.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Savat (O\'chirilganlar)',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'O\'chirilgan ma\'lumotlarni qayta tiklash yoki tozalash',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
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

  Widget _buildDeletedProducts() {
    return Consumer<InventoryProvider>(
      builder: (context, inventory, child) {
        final products = inventory.deletedProducts;
        if (products.isEmpty) {
          return _buildEmptyState('O\'chirilgan mahsulotlar yo\'q');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final p = products[index];
            final isSelected = _selectedIds.contains(p.id);
            return _buildTrashCard(
              id: p.id,
              title: p.name,
              subtitle: 'Barcode: ${p.barcode}',
              icon: Icons.inventory_2_outlined,
              isSelected: isSelected,
              onRestore: () => inventory.restoreProduct(p.id),
              onToggle: () {
                setState(() {
                  if (isSelected) { _selectedIds.remove(p.id); }
                  else { _selectedIds.add(p.id); }
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDeletedCategories() {
    return Consumer<InventoryProvider>(
      builder: (context, inventory, child) {
        final categories = inventory.deletedCategories;
        if (categories.isEmpty) {
          return _buildEmptyState('O\'chirilgan kategoriyalar yo\'q');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final c = categories[index];
            final isSelected = _selectedIds.contains(c.id);
            return _buildTrashCard(
              id: c.id,
              title: c.name,
              subtitle: 'ID: ${c.id.substring(0, c.id.length < 8 ? c.id.length : 8)}',
              icon: Icons.category_outlined,
              isSelected: isSelected,
              onRestore: () => inventory.restoreCategory(c.id),
              onToggle: () {
                setState(() {
                  if (isSelected) { _selectedIds.remove(c.id); }
                  else { _selectedIds.add(c.id); }
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDeletedUsers() {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        final users = auth.deletedUsers;
        if (users.isEmpty) {
          return _buildEmptyState('O\'chirilgan hodimlar yo\'q');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final u = users[index];
            final isSelected = _selectedIds.contains(u.id);
            return _buildTrashCard(
              id: u.id,
              title: u.name,
              subtitle: 'Role: ${u.role == UserRole.admin ? "Admin" : "Kassir"}',
              icon: Icons.person_outline,
              isSelected: isSelected,
              onRestore: () => auth.restoreUser(u.id),
              onToggle: () {
                setState(() {
                  if (isSelected) { _selectedIds.remove(u.id); }
                  else { _selectedIds.add(u.id); }
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDeletedWarehouses() {
    return Consumer<InventoryProvider>(
      builder: (context, inventory, child) {
        final items = inventory.deletedWarehouses;
        if (items.isEmpty) {
          return _buildEmptyState('O\'chirilgan omborlar yo\'q');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final w = items[index];
            final isSelected = _selectedIds.contains(w.id);
            return _buildTrashCard(
              id: w.id,
              title: w.name,
              subtitle: 'ID: ${w.id.substring(0, 8)}',
              icon: Icons.warehouse_rounded,
              isSelected: isSelected,
              onRestore: () => inventory.restoreWarehouse(w.id),
              onToggle: () {
                setState(() {
                  if (isSelected) { _selectedIds.remove(w.id); }
                  else { _selectedIds.add(w.id); }
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildDeletedRegisters() {
    return Consumer<InventoryProvider>(
      builder: (context, inventory, child) {
        final items = inventory.deletedRegisters;
        if (items.isEmpty) {
          return _buildEmptyState('O\'chirilgan kassalar yo\'q');
        }

        return ListView.builder(
          padding: const EdgeInsets.all(24),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final r = items[index];
            final isSelected = _selectedIds.contains(r.id);
            return _buildTrashCard(
              id: r.id,
              title: r.name,
              subtitle: 'ID: ${r.id.substring(0, 8)}',
              icon: Icons.storefront_rounded,
              isSelected: isSelected,
              onRestore: () => inventory.restoreRegister(r.id),
              onToggle: () {
                setState(() {
                  if (isSelected) { _selectedIds.remove(r.id); }
                  else { _selectedIds.add(r.id); }
                });
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTrashCard({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onRestore,
    required VoidCallback onToggle,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? Theme.of(context).colorScheme.primary.withOpacity(0.05) : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor),
      ),
      child: ListTile(
        onTap: onToggle,
        leading: Checkbox(
          value: isSelected,
          activeColor: Theme.of(context).colorScheme.primary,
          onChanged: (_) => onToggle(),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: TextButton.icon(
          onPressed: onRestore,
          icon: const Icon(Icons.restore, size: 18),
          label: const Text('Tiklash'),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
