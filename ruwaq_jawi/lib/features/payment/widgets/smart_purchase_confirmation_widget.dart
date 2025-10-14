import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../core/theme/app_theme.dart';

class SmartPurchaseConfirmationWidget extends StatelessWidget {
  final String currentPlanName;
  final String newPlanName;
  final String actionType; // 'new', 'extension', 'upgrade', 'downgrade'
  final int proratedDays;
  final double proratedValue;
  final double additionalCost;
  final double refundAmount;
  final String recommendation;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final bool isLoading;

  const SmartPurchaseConfirmationWidget({
    super.key,
    required this.currentPlanName,
    required this.newPlanName,
    required this.actionType,
    required this.proratedDays,
    required this.proratedValue,
    required this.additionalCost,
    required this.refundAmount,
    required this.recommendation,
    required this.onConfirm,
    required this.onCancel,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getActionColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: HugeIcon(
                  _getActionIcon(),
                  color: _getActionColor(),
                  size: 24.0,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getActionTitle(),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      _getActionSubtitle(),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Current Subscription Info (if not new)
          if (actionType != 'new') ...[
            _buildCurrentSubscriptionInfo(),
            const SizedBox(height: 16),

            // Arrow
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    PhosphorIcons.arrowDown(),
                    color: Colors.grey[400],
                    size: 20,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // New Subscription Info
          _buildNewSubscriptionInfo(),

          // Prorated Days Info (if applicable)
          if (proratedDays > 0) ...[
            const SizedBox(height: 16),
            _buildProratedInfo(),
          ],

          // Cost Summary
          const SizedBox(height: 20),
          _buildCostSummary(),

          // Recommendation
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                HugeIcon(
                  HugeIcons.strokeRoundedInformationCircle,
                  color: Colors.blue,
                  size: 20.0,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    recommendation,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue[800],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey[300]!),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Batal',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getActionColor(),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          _getConfirmButtonText(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSubscriptionInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Langganan Semasa',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currentPlanName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewSubscriptionInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getActionColor().withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getActionColor().withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Langganan Baru',
                style: TextStyle(
                  fontSize: 12,
                  color: _getActionColor(),
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (actionType != 'new') ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getActionColor(),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    actionType.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            newPlanName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProratedInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          HugeIcon(
            HugeIcons.strokeRoundedTimeDuration05,
            color: Colors.green,
            size: 20.0,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${proratedDays} hari kredit diterapkan',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  'Nilai kredit: RM${proratedValue.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCostSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          if (additionalCost > 0) ...[
            _buildCostRow('Kos Langganan Baru', additionalCost, Colors.black87),
            if (proratedValue > 0) ...[
              _buildCostRow('Kredit Diterapkan', -proratedValue, Colors.green),
            ],
            const Divider(),
            _buildCostRow(
              'Jumlah Tambahan',
              additionalCost - proratedValue,
              Colors.black87,
              isBold: true,
            ),
          ] else if (refundAmount > 0) ...[
            _buildCostRow('Kredit/Refund', refundAmount, Colors.green),
            const Divider(),
            _buildCostRow(
              'Jumlah Dijimatkan',
              refundAmount,
              Colors.green,
              isBold: true,
            ),
          ] else ...[
            _buildCostRow('Jumlah Bayaran', additionalCost, Colors.black87, isBold: true),
          ],
        ],
      ),
    );
  }

  Widget _buildCostRow(String label, double amount, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
          Text(
            amount >= 0 ? '+RM${amount.toStringAsFixed(2)}' : '-RM${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getActionColor() {
    switch (actionType) {
      case 'new':
        return AppTheme.primaryColor;
      case 'extension':
        return Colors.blue;
      case 'upgrade':
        return Colors.green;
      case 'downgrade':
        return Colors.orange;
      default:
        return AppTheme.primaryColor;
    }
  }

  HugeIcon _getActionIcon() {
    switch (actionType) {
      case 'new':
        return HugeIcons.strokeRoundedAdd01;
      case 'extension':
        return HugeIcons.strokeRoundedTimeDuration05;
      case 'upgrade':
        return HugeIcons.strokeRoundedArrowUp;
      case 'downgrade':
        return HugeIcons.strokeRoundedArrowDown;
      default:
        return HugeIcons.strokeRoundedAdd01;
    }
  }

  String _getActionTitle() {
    switch (actionType) {
      case 'new':
        return 'Langganan Baru';
      case 'extension':
        return 'Perpanjang Langganan';
      case 'upgrade':
        return 'Naik Taraf Langganan';
      case 'downgrade':
        return 'Tukar Langganan';
      default:
        return 'Langganan';
    }
  }

  String _getActionSubtitle() {
    switch (actionType) {
      case 'new':
        return 'Aktifkan langganan baharu';
      case 'extension':
        return 'Tambah masa kepada langganan semasa';
      case 'upgrade':
        return 'Dapatkan lebih banyak faedah';
      case 'downgrade':
        return 'Jimat kos dengan pilihan ekonomi';
      default:
        return '';
    }
  }

  String _getConfirmButtonText() {
    switch (actionType) {
      case 'new':
        return 'Aktifkan Sekarang';
      case 'extension':
        return 'Perpanjang Sekarang';
      case 'upgrade':
        return 'Naik Taraf Sekarang';
      case 'downgrade':
        return 'Tukar Sekarang';
      default:
        return 'Sahkan';
    }
  }
}