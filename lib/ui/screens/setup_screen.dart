import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import '../../providers/features/auth_provider.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final TextEditingController _ipController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool isCloudMode = false;
  bool isMasterChoice = true;
  bool isLoading = false;

  @override
  void dispose() {
    _ipController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Container(
              width: 550,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      Theme.of(context).brightness == Brightness.dark ? 0.3 : 0.05,
                    ),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icon.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tizimni sozlash',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ushbu terminal qanday usulda ishlashini tanlang',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Mode Selection
                  Row(
                    children: [
                      Expanded(
                        child: _buildChoiceCard(
                          title: 'Lokal Tarmoq',
                          subtitle: 'Master va unga ulanadigan qo\'shimcha kassalar',
                          icon: Icons.lan_outlined,
                          isSelected: !isCloudMode,
                          onTap: () => setState(() => isCloudMode = false),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildChoiceCard(
                          title: 'Bulutli Tizim',
                          subtitle: 'Har bir kassa alohida bazada va bulutga bog\'lanadi',
                          icon: Icons.cloud_outlined,
                          isSelected: isCloudMode,
                          onTap: () => setState(() => isCloudMode = true),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 24),

                  if (!isCloudMode) ...[
                    // LAN Specific Options
                    Row(
                      children: [
                        Expanded(
                          child: _buildSubChoiceCard(
                            title: 'Asosiy (Master)',
                            icon: Icons.storage_rounded,
                            isSelected: isMasterChoice,
                            onTap: () => setState(() => isMasterChoice = true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSubChoiceCard(
                            title: 'Qo\'shimcha',
                            icon: Icons.computer_rounded,
                            isSelected: !isMasterChoice,
                            onTap: () => setState(() => isMasterChoice = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (isMasterChoice) ...[
                      _buildIpInfo(),
                      const SizedBox(height: 24),
                      _buildPasswordField(),
                    ],
                    if (!isMasterChoice) ...[
                      _buildIpField(),
                    ],
                  ] else ...[
                    // Cloud Mode options
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(height: 12),
                          Text(
                            "Bulutli rejimda har bir terminal o'zining mustaqil ma'lumotlar bazasiga ega bo'ladi. Ma'lumotlar markazlashgan Railway serveri orqali sinxronizatsiya qilinadi.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildPasswordField(),
                  ],

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: isLoading ? null : _handleSetup,
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              (isCloudMode || isMasterChoice)
                                  ? 'SOZLOVNI YAKUNLASH'
                                  : 'ULANISH VA DAVOM ETISH',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSetup() async {
    final appState = context.read<AppState>();
    
    // Validation
    if ((isCloudMode || (!isCloudMode && isMasterChoice)) && _passwordController.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Xo\'jayin paroli kamida 4 belgidan iborat bo\'lishi kerak')),
      );
      return;
    }

    if (!isCloudMode && !isMasterChoice && _ipController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Asosiy kompyuter IP manzilini kiriting')),
      );
      return;
    }

    setState(() => isLoading = true);
    try {
      await appState.setTerminalMode(
        isMasterChoice,
        ip: _ipController.text,
        password: _passwordController.text,
        isCloud: isCloudMode,
      );
      
      if (mounted) {
        await context.read<AuthProvider>().loadAuth();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withOpacity(0.08)
              : theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? theme.colorScheme.primary : Colors.grey,
              size: 36,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubChoiceCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIpInfo() {
    return FutureBuilder<String?>(
      future: context.read<AppState>().localIp,
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ushbu kompyuter IP manzili: ${snapshot.data ?? "Aniqlanmoqda..."}\nUni boshqa kompyuterda kiriting.',
                  style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPasswordField() {
    return TextField(
      controller: _passwordController,
      decoration: InputDecoration(
        labelText: "Xo'jayin paroli (Tiklash uchun)",
        hintText: "Kamida 4 ta belgi",
        prefixIcon: const Icon(Icons.vpn_key_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildIpField() {
    return TextField(
      controller: _ipController,
      decoration: InputDecoration(
        labelText: 'Asosiy kompyuter IP manzili',
        hintText: 'Masalan: 192.168.1.10',
        prefixIcon: const Icon(Icons.lan_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
