import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/storage_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final sets = storage.getAllSets();
    final folders = storage.getAllFolders();
    
    // Mock user for now
    const username = "User";
    const email = "user@example.com";
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Settings logic
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 32),
            // Avatar & Info
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      username[0].toUpperCase(),
                      style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    username,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    email,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Stats Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                   _buildStat(context, sets.length.toString(), 'Sets'),
                   Container(width: 1, height: 40, color: AppColors.surfaceLight),
                   _buildStat(context, folders.length.toString(), 'Folders'),
                   Container(width: 1, height: 40, color: AppColors.surfaceLight),
                   _buildStat(context, '1', 'Streak'), // Mock streak
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Menu Items
            _buildMenuItem(context, Icons.notifications_outlined, 'Notifications'),
            _buildMenuItem(context, Icons.emoji_events_outlined, 'Achievements'),
            _buildMenuItem(context, Icons.help_outline, 'Help Center'),
            const Divider(),
            _buildMenuItem(context, Icons.logout, 'Log out', textColor: AppColors.error),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }
  
  Widget _buildMenuItem(BuildContext context, IconData icon, String label, {Color? textColor}) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? AppColors.textPrimary),
      title: Text(
        label,
        style: TextStyle(
          color: textColor ?? AppColors.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, size: 16, color: AppColors.textSecondary),
      onTap: () {},
    );
  }
}
