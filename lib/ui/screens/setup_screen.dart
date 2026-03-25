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
        child: Container(
          width: 500,
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
                width: 120,
                height: 120,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
              SizedBox(height: 24),
              Text(
                'Tizimni sozlash',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Ushbu terminal turini tanlang',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              SizedBox(height: 32),

              // Master/Client Toggle
              Row(
                children: [
                  Expanded(
                    child: _buildChoiceCard(
                      title: 'Asosiy (Master)',
                      subtitle: 'Server bo\'lib ishlaydi',
                      icon: Icons.storage_rounded,
                      isSelected: isMasterChoice,
                      onTap: () => setState(() => isMasterChoice = true),
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: _buildChoiceCard(
                      title: 'Qo\'shimcha',
                      subtitle: 'Serverga ulanadi',
                      icon: Icons.computer_rounded,
                      isSelected: !isMasterChoice,
                      onTap: () => setState(() => isMasterChoice = false),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 32),

              if (isMasterChoice) ...[
                FutureBuilder<String?>(
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
                          Icon(Icons.info_outline, color: Colors.amber),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Ushbu kompyuter IP manzili: ${snapshot.data ?? "Aniqlanmoqda..."}\nUni boshqa kompyuterda kiriting.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                SizedBox(height: 24),
                TextField(
                  controller: _passwordController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: "Xo'jayin paroli (Tiklash uchun)",
                    hintText: "Kamida 4 ta belgi",
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  obscureText: false,
                ),
              ],

              if (!isMasterChoice) ...[
                TextField(
                  controller: _ipController,
                  decoration: InputDecoration(
                    labelText: 'Asosiy kompyuter IP manzili',
                    hintText: 'Masalan: 192.168.1.10',
                    prefixIcon: Icon(Icons.lan_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                SizedBox(height: 24),
              ],

              SizedBox(height: 16),

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
                  onPressed: isLoading
                      ? null
                      : () async {
                          if (isMasterChoice &&
                              _passwordController.text.length < 4) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Parol kamida 4 belgidan iborat bo\'lishi kerak',
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() => isLoading = true);
                          try {
                            await context.read<AppState>().setTerminalMode(
                              isMasterChoice,
                              ip: _ipController.text,
                              password: _passwordController.text,
                            );
                            
                            // Re-load auth and settings to sync activation status
                            if (mounted) {
                              await context.read<AuthProvider>().loadAuth();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    e.toString().replaceAll('Exception: ', ''),
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => isLoading = false);
                          }
                        },
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          isMasterChoice
                              ? 'DAVOM ETISH'
                              : 'ULANISH VA DAVOM ETISH',
                          style: TextStyle(
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
      ), // GestureDetector
    );
  }

  Widget _buildChoiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.05)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey,
              size: 32,
            ),
            SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
