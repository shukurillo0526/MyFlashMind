import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';
import 'home/home_screen.dart';
import 'library/library_screen.dart';
import 'create/create_screen.dart';

/// Main app shell with bottom navigation bar
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  final GlobalKey<LibraryScreenState> _libraryKey = GlobalKey<LibraryScreenState>();

  /// Navigate to a specific tab
  void navigateToTab(int index) {
    setState(() => _currentIndex = index);
    // Reload library data when switching to library tab
    if (index == 2) {
      _libraryKey.currentState?.reloadData();
    }
  }

  /// Navigate to Create tab
  void goToCreate() => navigateToTab(1);

  /// Navigate to Library tab
  void goToLibrary() => navigateToTab(2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          HomeScreen(onNavigateToCreate: goToCreate),
          const CreateScreen(),
          LibraryScreen(key: _libraryKey, onNavigateToCreate: goToCreate),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(
              color: AppColors.surface,
              width: 0.5,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: navigateToTab,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.add_circle_outline),
              activeIcon: Icon(Icons.add_circle),
              label: 'Create',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined),
              activeIcon: Icon(Icons.folder),
              label: 'Library',
            ),
          ],
        ),
      ),
    );
  }
}
