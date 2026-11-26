import 'package:flutter/material.dart';
import 'theme/design_tokens.dart';
import 'services/sync_provider.dart';
import 'screens/role_selection_screen.dart';

void main() {
  runApp(const LogisticsApp());
}

class LogisticsApp extends StatefulWidget {
  const LogisticsApp({super.key});

  @override
  State<LogisticsApp> createState() => _LogisticsAppState();
}

class _LogisticsAppState extends State<LogisticsApp> {
  late final SyncProvider _syncProvider;

  @override
  void initState() {
    super.initState();
    _syncProvider = SyncProvider();

    // Trigger initial fetch
    _syncProvider.fetchData();
  }

  @override
  void dispose() {
    _syncProvider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _syncProvider,
      builder: (context, child) {
        return MaterialApp(
          title: 'Smart Retail Hub',
          debugShowCheckedModeBanner: false,
          theme: DesignTokens.darkTheme,
          home: RoleSelectionScreen(syncProvider: _syncProvider),
        );
      },
    );
  }
}