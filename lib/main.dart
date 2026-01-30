import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'data/services/storage_service.dart';
import 'data/services/supabase_service.dart';
import 'features/app_shell.dart';
import 'features/auth/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );
  
  // Initialize local storage
  final storageService = StorageService();
  await storageService.init();
  
  // Create Supabase service
  final supabaseService = SupabaseService(Supabase.instance.client);
  
  runApp(
    MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storageService),
        Provider<SupabaseService>.value(value: supabaseService),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyFlashMindApp(),
    ),
  );
}

class MyFlashMindApp extends StatelessWidget {
  const MyFlashMindApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'MyFlashMind',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const AuthWrapper(),
        );
      },
    );
  }
}

/// Wrapper that shows auth screen or app based on auth state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = context.read<SupabaseService>();
    
    return StreamBuilder<AuthState>(
      stream: supabase.authStateChanges,
      builder: (context, snapshot) {
        // Show auth screen if not authenticated
        if (!supabase.isAuthenticated) {
          return const AuthScreen();
        }
        
        // Show main app if authenticated
        return const AppShell();
      },
    );
  }
}
