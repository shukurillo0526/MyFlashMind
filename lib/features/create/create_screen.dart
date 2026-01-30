import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/folder.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/supabase_service.dart';
import 'create_set_screen.dart';
import 'import_quizlet_screen.dart';

/// Create screen with options to create sets, folders, or import
class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key});

  void _createSet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const CreateSetScreen(),
      ),
    );
  }

  void _createFolder(BuildContext context) async {
    final nameController = TextEditingController();
    
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: const Text('Create folder'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Folder name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (name != null && name.isNotEmpty) {
      final folder = Folder(
        id: const Uuid().v4(),
        name: name,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      // Save locally
      await context.read<StorageService>().saveFolder(folder);
      // Sync to cloud
      await context.read<SupabaseService>().saveFolder(folder);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Folder "$name" created')),
        );
      }
    }
  }

  void _importFromQuizlet(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const ImportQuizletScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),

              // Create options
              _buildOption(
                context,
                icon: Icons.style,
                iconColor: AppColors.primary,
                title: 'Flashcard set',
                subtitle: 'Create a new set of flashcards',
                onTap: () => _createSet(context),
              ),
              const SizedBox(height: 12),

              _buildOption(
                context,
                icon: Icons.folder,
                iconColor: AppColors.secondary,
                title: 'Folder',
                subtitle: 'Organize your sets into folders',
                onTap: () => _createFolder(context),
              ),
              const SizedBox(height: 12),

              _buildOption(
                context,
                icon: Icons.download,
                iconColor: AppColors.accent,
                title: 'Import from Quizlet',
                subtitle: 'Paste a Quizlet share link to import',
                onTap: () => _importFromQuizlet(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
