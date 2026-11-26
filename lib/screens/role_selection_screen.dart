import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../services/sync_provider.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  final SyncProvider syncProvider;

  const RoleSelectionScreen({super.key, required this.syncProvider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront_rounded, size: 90, color: DesignTokens.primary),
            const SizedBox(height: 16),
            Text('Smart Retail Hub', style: DesignTokens.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Select your portal to continue', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 48),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LoginScreen(syncProvider: syncProvider, role: 'customer')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.primary,
                  shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusMedium),
                ),
                icon: const Icon(Icons.person, color: Colors.white),
                label: const Text('Customer Portal', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => LoginScreen(syncProvider: syncProvider, role: 'provider')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: DesignTokens.surfaceElevated,
                  shape: RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusMedium),
                ),
                icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                label: const Text('Provider / Manager Portal', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}