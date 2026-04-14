import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_state.dart';
import '../../providers/features/settings_provider.dart';

class ReceiptDesignerScreen extends StatefulWidget {
  const ReceiptDesignerScreen({super.key});

  @override
  State<ReceiptDesignerScreen> createState() => _ReceiptDesignerScreenState();
}

class _ReceiptDesignerScreenState extends State<ReceiptDesignerScreen> {
  late TextEditingController _footerController;
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _instaController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _footerController = TextEditingController(text: settings.receiptFooterText);
    _nameController = TextEditingController(text: settings.organizationName);
    _addressController = TextEditingController(text: settings.organizationAddress);
    _instaController = TextEditingController(text: settings.instagramUsername);
  }

  @override
  void dispose() {
    _footerController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _instaController.dispose();
    super.dispose();
  }

  void _saveAll(SettingsProvider settings) {
    settings.updateReceiptSettings(
      footer: _footerController.text,
    );
    settings.updateOrganizationInfo(
      name: _nameController.text,
      address: _addressController.text,
      instagram: _instaController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Chek Dizayner', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        elevation: 0,
        backgroundColor: theme.cardColor,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: TextButton.icon(
              onPressed: () {
                _saveAll(settings);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('O\'zgarishlar saqlandi'), behavior: SnackBarBehavior.floating),
                );
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('Saqlash'),
              style: TextButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // Left: Editor Panel
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: theme.dividerColor, width: 0.5)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('ASOSIY MA\'LUMOTLAR', Icons.business_rounded),
                    const SizedBox(height: 16),
                    _buildSettingsCard([
                      _buildTextField(
                        controller: _nameController,
                        label: 'Tashkilot nomi',
                        hint: 'Mening Do\'konim',
                        onChanged: (val) => settings.updateOrganizationInfo(name: val),
                      ),
                      const Divider(height: 32),
                      _buildTextField(
                        controller: _addressController,
                        label: 'Manzil',
                        hint: 'Toshkent sh., Yunusobod...',
                        onChanged: (val) => settings.updateOrganizationInfo(address: val),
                      ),
                    ]),
                    
                    const SizedBox(height: 32),
                    _buildSectionHeader('STYLE & FORMAT', Icons.straighten_rounded),
                    const SizedBox(height: 16),
                    _buildSettingsCard([
                      _buildWidthSelector(settings),
                    ]),

                    const SizedBox(height: 32),
                    _buildSectionHeader('FOOTER (PASTKI QISM)', Icons.subtitles_rounded),
                    const SizedBox(height: 16),
                    _buildSettingsCard([
                      _buildTextField(
                        controller: _footerController,
                        label: 'Xayrlashuv matni',
                        hint: 'Xaridingiz uchun rahmat!',
                        maxLines: 3,
                        onChanged: (val) => settings.updateReceiptSettings(footer: val),
                      ),
                      const SizedBox(height: 16),
                      _buildToggleTile(
                        icon: Icons.qr_code_2_rounded,
                        title: 'Instagram QR kod',
                        subtitle: 'Ijtimoiy tarmoqni chekda ko\'rsatish',
                        value: settings.showInstagramOnReceipt,
                        onChanged: (val) => settings.updateReceiptSettings(showInstagram: val),
                      ),
                      if (settings.showInstagramOnReceipt) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Divider(),
                        ),
                        _buildTextField(
                          controller: _instaController,
                          label: 'Instagram username',
                          hint: '@simplesale',
                          onChanged: (val) => settings.updateOrganizationInfo(instagram: val),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
            ),
          ),

          // Right: Preview Panel
          Expanded(
            flex: 6,
            child: Container(
              color: theme.brightness == Brightness.light ? Colors.grey[100] : Colors.black26,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Text(
                          'PREVIEW',
                          style: TextStyle(
                            letterSpacing: 4,
                            fontWeight: FontWeight.bold,
                            color: theme.disabledColor,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      _buildModernReceiptPreview(settings),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    required Function(String) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      activeColor: Theme.of(context).colorScheme.primary,
    );
  }

  Widget _buildWidthSelector(SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chek eni (Qog\'oz o\'lchami)',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildWidthOption(58, '58mm', settings.receiptWidth == 58, (val) => settings.updateReceiptSettings(width: val)),
            const SizedBox(width: 12),
            _buildWidthOption(80, '80mm', settings.receiptWidth == 80, (val) => settings.updateReceiptSettings(width: val)),
          ],
        ),
      ],
    );
  }

  Widget _buildWidthOption(int width, String label, bool isSelected, Function(int) onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(width),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? colorScheme.primary : Theme.of(context).dividerColor.withOpacity(0.2),
              width: 2,
            ),
            color: isSelected ? colorScheme.primary.withOpacity(0.05) : Colors.transparent,
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colorScheme.primary : Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernReceiptPreview(SettingsProvider settings) {
    final width = settings.receiptWidth == 58 ? 300.0 : 400.0;
    
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          // Receipt Content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Header
                Text(
                  (_nameController.text.isNotEmpty ? _nameController.text : 'BIZNES NOMI').toUpperCase(),
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 20, fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
                if (_addressController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      _addressController.text,
                      style: const TextStyle(color: Colors.black, fontSize: 13, fontFamily: 'monospace'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 16),
                _buildReceiptDivider(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kassa: Bosh Kassa', style: TextStyle(color: Colors.black, fontSize: 12, fontFamily: 'monospace')),
                    Text(
                      DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()),
                      style: const TextStyle(color: Colors.black, fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Chek #: 000123', style: TextStyle(color: Colors.black, fontSize: 12, fontFamily: 'monospace')),
                    Text('Sotuvchi: Admin', style: TextStyle(color: Colors.black, fontSize: 12, fontFamily: 'monospace')),
                  ],
                ),
                const SizedBox(height: 8),
                _buildReceiptDivider(),
                const SizedBox(height: 12),

                // Items
                _buildModernPreviewItem('MAHSULOT 1', 2, 15000),
                _buildModernPreviewItem('MAHSULOT 2', 1, 45000),
                
                const SizedBox(height: 12),
                _buildReceiptDivider(thick: true),
                const SizedBox(height: 12),

                // Totals
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('JAMI:', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'monospace')),
                    Text(
                      '75 000 so\'m',
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18, fontFamily: 'monospace'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Footer
                if (_footerController.text.isNotEmpty)
                  Text(
                    _footerController.text,
                    style: const TextStyle(color: Colors.black, fontSize: 14, fontFamily: 'monospace'),
                    textAlign: TextAlign.center,
                  ),
                
                if (settings.showInstagramOnReceipt && _instaController.text.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildReceiptDivider(dotted: true),
                  const SizedBox(height: 16),
                  Text('Instagram: ${_instaController.text}', style: const TextStyle(color: Colors.black, fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
                  const SizedBox(height: 8),
                  Container(
                    width: 70,
                    height: 70,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: const Icon(Icons.qr_code_2, color: Colors.black, size: 50),
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
          ),
          
          // Technical bottom edge
          ClipPath(
            clipper: ReceiptEdgeClipper(),
            child: Container(
              height: 10,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildReceiptDivider({bool thick = false, bool dotted = false}) {
    if (dotted) {
      return Row(
        children: List.generate(30, (index) => Expanded(
          child: Container(
            color: index % 2 == 0 ? Colors.black : Colors.transparent,
            height: 1,
          ),
        )),
      );
    }
    return Container(
      height: thick ? 2.5 : 1,
      color: Colors.black,
    );
  }

  Widget _buildModernPreviewItem(String name, double qty, double price) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14, fontFamily: 'monospace')),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${qty.toInt()} x ${price.toStringAsFixed(0)}', style: const TextStyle(color: Colors.black, fontSize: 13, fontFamily: 'monospace')),
              Text('${(qty * price).toStringAsFixed(0)}', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }
}

class ReceiptEdgeClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, 0);
    double width = 8.0;
    double height = 5.0;
    int count = (size.width / width).floor();
    
    for (int i = 0; i < count; i++) {
       path.lineTo(i * width + width / 2, height);
       path.lineTo((i + 1) * width, 0);
    }
    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

