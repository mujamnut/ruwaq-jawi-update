import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../../core/providers/auth_provider.dart';

class ProfileDataManager {
  final VoidCallback onStateChanged;
  final TextEditingController nameController = TextEditingController();
  bool isEditingName = false;

  ProfileDataManager({required this.onStateChanged});

  void initializeNameController(BuildContext context) {
    final authProvider = context.read<AuthProvider>();
    nameController.text = authProvider.userProfile?.fullName ?? '';
  }

  Future<bool> updateName(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.updateProfile(
      fullName: nameController.text.trim(),
    );

    if (success) {
      isEditingName = false;
      onStateChanged();
    }

    return success;
  }

  void toggleEditName() {
    isEditingName = !isEditingName;
    onStateChanged();
  }

  void dispose() {
    nameController.dispose();
  }
}