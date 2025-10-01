import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';
import '../services/password_change_service.dart';

class PasswordChangeDialogWidget extends StatefulWidget {
  final VoidCallback onSuccess;
  final Function(String) onError;

  const PasswordChangeDialogWidget({
    super.key,
    required this.onSuccess,
    required this.onError,
  });

  static void show(
    BuildContext context, {
    required VoidCallback onSuccess,
    required Function(String) onError,
  }) {
    showDialog(
      context: context,
      builder: (context) => PasswordChangeDialogWidget(
        onSuccess: onSuccess,
        onError: onError,
      ),
    );
  }

  @override
  State<PasswordChangeDialogWidget> createState() =>
      _PasswordChangeDialogWidgetState();
}

class _PasswordChangeDialogWidgetState
    extends State<PasswordChangeDialogWidget> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isChangingPassword = false;
  bool _obscureOldPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleChangePassword() async {
    final validationError = PasswordChangeService.validatePasswordChange(
      oldPassword: _oldPasswordController.text,
      newPassword: _newPasswordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (validationError != null) {
      widget.onError(validationError);
      return;
    }

    setState(() {
      _isChangingPassword = true;
    });

    try {
      if (!mounted) return;
      final success = await PasswordChangeService.changePassword(
        context,
        oldPassword: _oldPasswordController.text.trim(),
        newPassword: _newPasswordController.text.trim(),
      );

      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop();
        widget.onSuccess();
      } else {
        widget.onError(
          'Ralat menukar kata laluan. Sila semak kata laluan lama anda.',
        );
      }
    } catch (e) {
      if (mounted) {
        widget.onError('Ralat: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isChangingPassword = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tukar Kata Laluan'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPasswordField(
              controller: _oldPasswordController,
              label: 'Kata Laluan Lama',
              obscureText: _obscureOldPassword,
              onToggleVisibility: () {
                setState(() {
                  _obscureOldPassword = !_obscureOldPassword;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _newPasswordController,
              label: 'Kata Laluan Baru',
              obscureText: _obscureNewPassword,
              onToggleVisibility: () {
                setState(() {
                  _obscureNewPassword = !_obscureNewPassword;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _confirmPasswordController,
              label: 'Sahkan Kata Laluan Baru',
              obscureText: _obscureConfirmPassword,
              onToggleVisibility: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildPasswordRequirements(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isChangingPassword
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isChangingPassword ? null : _handleChangePassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: AppTheme.textLightColor,
          ),
          child: _isChangingPassword
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Tukar'),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: PhosphorIcon(
            obscureText ? PhosphorIcons.eye() : PhosphorIcons.eyeSlash(),
          ),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }

  Widget _buildPasswordRequirements() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.info(),
                color: AppTheme.primaryColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'Keperluan Kata Laluan:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '• Sekurang-kurangnya 6 aksara\n'
            '• Berbeza daripada kata laluan lama',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondaryColor,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}