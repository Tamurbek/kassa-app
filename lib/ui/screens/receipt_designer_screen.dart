import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import '../../providers/app_state.dart';
import '../../providers/features/settings_provider.dart';
import '../../providers/features/auth_provider.dart';
import '../widgets/app_status_bar.dart';

class ReceiptDesignerScreen extends StatefulWidget {
  const ReceiptDesignerScreen({super.key});

  @override
  State<ReceiptDesignerScreen> createState() => _ReceiptDesignerScreenState();
}

class _ReceiptDesignerScreenState extends State<ReceiptDesignerScreen> {
  late TextEditingController _footerController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _footerController = TextEditingController(text: settings.receiptFooterText);
  }

  @override
  void dispose() {
    _footerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = context.watch<SettingsProvider>();

    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Chek Dizayner', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Settings Side
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('Chek Mazmuni'),
                        const SizedBox(height: 16),
                        _buildSettingCard([
                          _buildToggleTile(
                            'Instagram / QR kod',
                            settings.showInstagramOnReceipt,
                            (val) => settings.updateReceiptSettings(showInstagram: val),
                          ),
                        ]),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Pastki Matn (Footer)'),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _footerController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Theme.of(context).dividerColor),
                            ),
                            hintText: 'Masalan: Xaridingiz uchun rahmat!',
                          ),
                          onChanged: (val) => settings.updateReceiptSettings(footer: val),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Saqlash va Chiqish'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(56),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Preview Side
                Expanded(
                  flex: 1,
                  child: Container(
                    color: Colors.grey.withOpacity(0.1),
                    child: Center(
                      child: SingleChildScrollView(
                        child: _buildReceiptPreview(state, settings),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        color: Theme.of(context).textTheme.bodySmall?.color,
      ),
    );
  }

  Widget _buildSettingCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleTile(String title, bool value, Function(bool) onChanged) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildReceiptPreview(AppState state, SettingsProvider settings) {
    final width = settings.receiptWidth == 58 ? 250.0 : 350.0;
    
    return Container(
      width: width,
      margin: const EdgeInsets.all(40),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.black, fontFamily: 'monospace'),
        child: Column(
          children: [
            Text(
              (state.organizationName ?? 'SIMPLE SALE').toUpperCase(),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            if (state.organizationAddress != null)
              Text(
                state.organizationAddress!,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 12),
            const Divider(color: Colors.black, thickness: 1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kassa: Bosh Kassa', style: TextStyle(fontSize: 11)),
                Text(
                  DateFormat('dd.MM.yyyy').format(DateTime.now()),
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
            const Divider(color: Colors.black, thickness: 1),
            _buildPreviewItem('MAHSULOT 1', 2, 15000),
            _buildPreviewItem('MAHSULOT 2', 1, 45000),
            const Divider(color: Colors.black, thickness: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('JAMI:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(
                  '75 000 so\'m',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              settings.receiptFooterText,
              style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (settings.showInstagramOnReceipt && settings.instagramUsername != null && settings.instagramUsername!.isNotEmpty) ...[
              const Divider(color: Colors.black, thickness: 0.5, height: 20),
              Text('Instagram: @${state.instagramUsername}', style: const TextStyle(fontSize: 11)),
              const SizedBox(height: 8),
              Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade300,
                child: const Icon(Icons.qr_code_2, color: Colors.black, size: 40),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewItem(String name, double qty, double price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${qty.toInt()} x ${price.toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
              Text('${(qty * price).toStringAsFixed(0)}', style: const TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}
