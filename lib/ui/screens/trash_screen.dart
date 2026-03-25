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

class _TrashScreenState extends State<TrashScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: Column(
          children: [
            _buildHeader(),
            TabBar(
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey.shade400,
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'Mahsulotlar'),
                Tab(text: 'Kategoriyalar'),
                Tab(text: 'Hodimlar'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _buildDeletedProducts(),
                  _buildDeletedCategories(),
                  _buildDeletedUsers(),
                ],
              ),
            ),
          ],
        ),
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
                    'O\'chirilgan ma\'lumotlarni qayta tiklash',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (widget.onMenuPressed != null)
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
            return _buildTrashCard(
              title: p.name,
              subtitle: 'Barcode: ${p.barcode}',
              icon: Icons.inventory_2_outlined,
              onRestore: () => inventory.restoreProduct(p.id),
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
            return _buildTrashCard(
              title: c.name,
              subtitle:
                  'ID: ${c.id.substring(0, c.id.length < 8 ? c.id.length : 8)}${c.id.length > 8 ? "..." : ""}',
              icon: Icons.category_outlined,
              onRestore: () => inventory.restoreCategory(c.id),
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
            return _buildTrashCard(
              title: u.name,
              subtitle:
                  'Role: ${u.role == UserRole.admin ? "Admin" : "Kassir"}',
              icon: Icons.person_outline,
              onRestore: () => auth.restoreUser(u.id),
            );
          },
        );
      },
    );
  }

  Widget _buildTrashCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onRestore,
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
              Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.02,
            ),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.grey, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onRestore,
            icon: const Icon(Icons.restore, size: 18),
            label: const Text('Tiklash'),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
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
