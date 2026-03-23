import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../models/models.dart';
import 'package:uuid/uuid.dart';

class EmployeeScreen extends StatelessWidget {
  final VoidCallback? onMenuPressed;
  const EmployeeScreen({super.key, this.onMenuPressed});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          _buildHeader(context, state),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: state.activeUsers.length,
              itemBuilder: (context, index) {
                final user = state.activeUsers[index];
                return _buildUserCard(context, state, user);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState state) {
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
              SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hodimlar',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'Tizim foydalanuvchilarini boshqarish',
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
              ElevatedButton.icon(
                onPressed: () => _showAddUserDialog(context, state),
                icon: Icon(Icons.person_add_alt_1_rounded),
                label: Text('Yangi hodim'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              if (onMenuPressed != null) ...[
                SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    Icons.menu_rounded,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  onPressed: onMenuPressed,
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
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, AppState state, User user) {
    final isAdmin = user.role == UserRole.admin;
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
          CircleAvatar(
            radius: 24,
            backgroundColor: (isAdmin ? Colors.amber : Colors.blue).withOpacity(
              0.15,
            ),
            child: Icon(
              isAdmin ? Icons.admin_panel_settings : Icons.person,
              color: isAdmin ? Colors.amber : Colors.blue,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  isAdmin ? 'Administrator' : 'Sotuvchi',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PIN: ${user.pin}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (user.id != 'admin')
                TextButton(
                  onPressed: () => state.deleteUser(user.id),
                  child: Text(
                    'O\'chirish',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAddUserDialog(BuildContext context, AppState state) {
    final nameCtrl = TextEditingController();
    final pinCtrl = TextEditingController();
    UserRole selectedRole = UserRole.seller;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Yangi Hodim Qo\'shish'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Ism sharif'),
              ),
              TextField(
                controller: pinCtrl,
                decoration: const InputDecoration(labelText: 'PIN kod'),
                keyboardType: TextInputType.number,
                maxLength: 4,
              ),
              SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Huquqi'),
                items: const [
                  DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
                  DropdownMenuItem(
                    value: UserRole.seller,
                    child: Text('Sotuvchi'),
                  ),
                ],
                onChanged: (val) => setDialogState(() => selectedRole = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Bekor qilish'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.isNotEmpty && pinCtrl.text.length == 4) {
                  state.addUser(
                    User(
                      id: Uuid().v4(),
                      name: nameCtrl.text,
                      pin: pinCtrl.text,
                      role: selectedRole,
                    ),
                  );
                  Navigator.pop(context);
                }
              },
              child: Text('Saqlash'),
            ),
          ],
        ),
      ),
    );
  }
}
