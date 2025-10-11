import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_theme.dart';

class SubscriptionPlanFormScreen extends StatefulWidget {
  final Map<String, dynamic>? plan; // null for create, filled for edit

  const SubscriptionPlanFormScreen({super.key, this.plan});

  @override
  State<SubscriptionPlanFormScreen> createState() =>
      _SubscriptionPlanFormScreenState();
}

class _SubscriptionPlanFormScreenState
    extends State<SubscriptionPlanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _planIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _durationController = TextEditingController();

  String _currency = 'MYR';
  bool _isActive = true;
  bool _isLoading = false;

  final List<String> _currencies = ['MYR', 'USD', 'SGD', 'EUR'];
  final List<int> _durationPresets = [7, 30, 90, 180, 365];

  bool get _isEditing => widget.plan != null;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['role'] != 'admin') {
        if (mounted) {
          Navigator.of(context).pop();
        }
        return;
      }

      // Load existing plan data if editing
      if (_isEditing) {
        _initializeFormData();
      } else {
        // Set default duration for new plan
        _durationController.text = '30';
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void _initializeFormData() {
    if (widget.plan == null) return;

    final plan = widget.plan!;
    _planIdController.text = plan['id'] ?? '';
    _nameController.text = plan['name'] ?? '';
    _priceController.text = plan['price']?.toString() ?? '';
    _durationController.text = plan['duration_days']?.toString() ?? '30';
    _currency = plan['currency'] ?? 'MYR';
    _isActive = plan['is_active'] ?? true;

    setState(() {});
  }

  @override
  void dispose() {
    _planIdController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEditing ? 'Edit Pelan Langganan' : 'Tambah Pelan Baru',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _savePlan,
              child: Text(
                _isEditing ? 'Kemaskini' : 'Simpan',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Maklumat Pelan'),
              const SizedBox(height: 16),
              _buildPlanInfoSection(),

              const SizedBox(height: 24),
              _buildSectionTitle('Harga & Tempoh'),
              const SizedBox(height: 16),
              _buildPricingSection(),

              const SizedBox(height: 24),
              _buildSectionTitle('Tetapan'),
              const SizedBox(height: 16),
              _buildSettingsSection(),

              const SizedBox(height: 24),
              _buildSectionTitle('Pratonton'),
              const SizedBox(height: 16),
              _buildPreview(),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppTheme.textPrimaryColor,
      ),
    );
  }

  Widget _buildPlanInfoSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // Plan ID Field
          TextFormField(
            controller: _planIdController,
            enabled: !_isEditing, // Disable editing for existing plans
            decoration: InputDecoration(
              labelText: 'ID Pelan *',
              hintText: 'Contoh: PLAN_MONTHLY',
              helperText: _isEditing
                  ? 'ID tidak boleh diubah selepas dicipta'
                  : 'Gunakan format: PLAN_XXX (huruf besar, tanpa spasi)',
              prefixIcon: const HugeIcon(
                icon: HugeIcons.strokeRoundedTag01,
                color: AppTheme.primaryColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: _isEditing ? Colors.grey.shade100 : Colors.white,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9_]')),
            ],
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'ID pelan tidak boleh kosong';
              }
              if (!RegExp(r'^[A-Z][A-Z0-9_]*$').hasMatch(value)) {
                return 'ID mesti bermula dengan huruf besar dan hanya mengandungi A-Z, 0-9, dan _';
              }
              return null;
            },
            maxLength: 50,
          ),
          const SizedBox(height: 16),

          // Plan Name Field
          TextFormField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Nama Pelan *',
              hintText: 'Contoh: Bulanan Standard',
              prefixIcon: const HugeIcon(
                icon: HugeIcons.strokeRoundedFileEdit,
                color: AppTheme.primaryColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama pelan tidak boleh kosong';
              }
              return null;
            },
            maxLength: 100,
          ),
        ],
      ),
    );
  }

  Widget _buildPricingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          // Price and Currency Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Price Field
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: _priceController,
                  decoration: InputDecoration(
                    labelText: 'Harga *',
                    hintText: '0.00',
                    prefixIcon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedMoney04,
                      color: AppTheme.primaryColor,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,2}'),
                    ),
                  ],
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Harga tidak boleh kosong';
                    }
                    final price = double.tryParse(value.trim());
                    if (price == null || price <= 0) {
                      return 'Harga mesti lebih besar daripada 0';
                    }
                    return null;
                  },
                  onChanged: (value) {
                    setState(() {}); // Rebuild for preview
                  },
                ),
              ),
              const SizedBox(width: 12),

              // Currency Selector
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: InputDecoration(
                    labelText: 'Mata Wang',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: _currencies.map((currency) {
                    return DropdownMenuItem(
                      value: currency,
                      child: Text(currency),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _currency = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Duration Field with Presets
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _durationController,
                decoration: InputDecoration(
                  labelText: 'Tempoh (hari) *',
                  hintText: '30',
                  helperText: 'Tempoh langganan dalam hari',
                  prefixIcon: const HugeIcon(
                    icon: HugeIcons.strokeRoundedCalendar03,
                    color: AppTheme.primaryColor,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Tempoh tidak boleh kosong';
                  }
                  final days = int.tryParse(value.trim());
                  if (days == null || days <= 0) {
                    return 'Tempoh mesti lebih besar daripada 0';
                  }
                  return null;
                },
                onChanged: (value) {
                  setState(() {}); // Rebuild for preview
                },
              ),
              const SizedBox(height: 12),

              // Duration Presets
              const Text(
                'Pilihan Pantas:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _durationPresets.map((days) {
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _durationController.text = days.toString();
                      });
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _durationController.text == days.toString()
                            ? AppTheme.primaryColor.withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _durationController.text == days.toString()
                              ? AppTheme.primaryColor
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        _getDurationLabel(days),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _durationController.text == days.toString()
                              ? AppTheme.primaryColor
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          HugeIcon(
            icon: _isActive
                ? HugeIcons.strokeRoundedCheckmarkCircle02
                : HugeIcons.strokeRoundedCancel01,
            color: _isActive ? Colors.green : Colors.grey,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Status Aktif',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  _isActive
                      ? 'Pelan ini akan ditunjukkan kepada pengguna'
                      : 'Pelan ini akan disembunyikan dari pengguna',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),
          Switch(
            value: _isActive,
            onChanged: (value) {
              setState(() {
                _isActive = value;
              });
            },
            activeThumbColor: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final duration = int.tryParse(_durationController.text) ?? 0;
    final pricePerDay = duration > 0 ? price / duration : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const HugeIcon(
                icon: HugeIcons.strokeRoundedView,
                color: AppTheme.primaryColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Preview Pelan',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppTheme.textPrimaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preview Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nameController.text.isEmpty
                      ? 'Nama Pelan'
                      : _nameController.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _planIdController.text.isEmpty
                      ? 'PLAN_ID'
                      : _planIdController.text,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$_currency ',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      price.toStringAsFixed(2),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  duration > 0
                      ? 'untuk ${_getDurationLabel(duration)}'
                      : 'Tempoh tidak ditetapkan',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    duration > 0
                        ? '${pricePerDay.toStringAsFixed(2)} $_currency/hari'
                        : 'Harga per hari: -',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDurationLabel(int days) {
    if (days == 7) return '7 hari (1 minggu)';
    if (days == 30) return '30 hari (1 bulan)';
    if (days == 90) return '90 hari (3 bulan)';
    if (days == 180) return '180 hari (6 bulan)';
    if (days == 365) return '365 hari (1 tahun)';
    return '$days hari';
  }

  Future<void> _savePlan() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final planData = {
        'name': _nameController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'currency': _currency,
        'duration_days': int.parse(_durationController.text.trim()),
        'is_active': _isActive,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (_isEditing) {
        // Update existing plan
        await Supabase.instance.client
            .from('subscription_plans')
            .update(planData)
            .eq('id', widget.plan!['id']);

        _showSnackBar('Pelan berjaya dikemaskini!');
      } else {
        // Create new plan
        planData['id'] = _planIdController.text.trim();
        planData['created_at'] = DateTime.now().toIso8601String();

        await Supabase.instance.client
            .from('subscription_plans')
            .insert(planData);

        _showSnackBar('Pelan baharu berjaya ditambah!');
      }

      if (mounted) {
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      String errorMessage = 'Ralat: ${e.toString()}';

      // Handle specific errors
      if (e.toString().contains('duplicate key')) {
        errorMessage = 'ID pelan sudah wujud. Sila gunakan ID yang berbeza.';
      } else if (e.toString().contains('foreign key')) {
        errorMessage = 'Tidak dapat menghapus pelan yang sedang digunakan.';
      }

      _showSnackBar(errorMessage, isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
