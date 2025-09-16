import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../core/theme/app_theme.dart';

class YouTubeSyncLoadingDialog extends StatefulWidget {
  final String playlistUrl;

  const YouTubeSyncLoadingDialog({
    super.key,
    required this.playlistUrl,
  });

  @override
  State<YouTubeSyncLoadingDialog> createState() => _YouTubeSyncLoadingDialogState();
}

class _YouTubeSyncLoadingDialogState extends State<YouTubeSyncLoadingDialog>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _scaleController;
  late AnimationController _progressController;

  late Animation<double> _rotationAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _progressAnimation;

  int _currentStep = 0;
  final List<String> _steps = [
    'Connecting to YouTube...',
    'Fetching playlist information...',
    'Loading video details...',
    'Processing episodes...',
    'Creating database entries...',
    'Finalizing sync...',
  ];

  @override
  void initState() {
    super.initState();

    // Rotation animation for YouTube logo
    _rotationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _rotationController,
      curve: Curves.linear,
    ));

    // Scale animation for loading indicator
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeInOut,
    ));

    // Progress animation
    _progressController = AnimationController(
      duration: Duration(seconds: _steps.length * 2),
      vsync: this,
    );
    _progressAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(
      parent: _progressController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _rotationController.repeat();
    _scaleController.repeat(reverse: true);
    _progressController.forward();

    // Step progression
    _startStepProgression();
  }

  void _startStepProgression() async {
    final stepDuration = Duration(
      milliseconds: (_progressController.duration!.inMilliseconds / _steps.length).round(),
    );

    for (int i = 0; i < _steps.length; i++) {
      if (mounted) {
        setState(() {
          _currentStep = i;
        });
        await Future.delayed(stepDuration);
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _scaleController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated YouTube Logo
            AnimatedBuilder(
              animation: _rotationAnimation,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationAnimation.value * 2 * 3.14159,
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: PhosphorIcon(
                              PhosphorIcons.youtubeLogo(PhosphorIconsStyle.fill),
                              color: Colors.red,
                              size: 40,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // Title
            Text(
              'Syncing YouTube Playlist',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimaryColor,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Playlist URL (truncated)
            Text(
              _truncateUrl(widget.playlistUrl),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 24),

            // Progress Bar
            Container(
              width: double.infinity,
              height: 6,
              decoration: BoxDecoration(
                color: AppTheme.borderColor.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
              child: AnimatedBuilder(
                animation: _progressAnimation,
                builder: (context, child) {
                  return FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _progressAnimation.value,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.red,
                            Colors.red.shade300,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Progress Percentage
            AnimatedBuilder(
              animation: _progressAnimation,
              builder: (context, child) {
                return Text(
                  '${(_progressAnimation.value * 100).toInt()}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // Current Step
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  // Step indicator
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${_currentStep + 1}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Step text with loading dots
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        _currentStep < _steps.length
                            ? _steps[_currentStep]
                            : 'Completing sync...',
                        key: ValueKey(_currentStep),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textPrimaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                  // Loading dots animation
                  _buildLoadingDots(),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Steps List Preview
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _steps.length,
                itemBuilder: (context, index) {
                  final isCompleted = index < _currentStep;
                  final isCurrent = index == _currentStep;
                  final isPending = index > _currentStep;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        // Status icon
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: isCompleted
                                ? Colors.green
                                : isCurrent
                                    ? Colors.red
                                    : AppTheme.borderColor.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: isCompleted
                                ? PhosphorIcon(
                                    PhosphorIcons.check(),
                                    color: Colors.white,
                                    size: 10,
                                  )
                                : isCurrent
                                    ? Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      )
                                    : null,
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Step text
                        Expanded(
                          child: Text(
                            _steps[index],
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isCompleted
                                  ? Colors.green
                                  : isCurrent
                                      ? AppTheme.textPrimaryColor
                                      : AppTheme.textSecondaryColor.withValues(alpha: 0.6),
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Info text
            Text(
              'Please wait while we sync your playlist...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _scaleController,
          builder: (context, child) {
            final delay = index * 0.2;
            final animationValue = (_scaleController.value + delay) % 1.0;
            final opacity = (0.3 + (animationValue * 0.7)).clamp(0.0, 1.0);

            return Container(
              margin: EdgeInsets.only(left: index > 0 ? 4 : 0),
              child: Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              ),
            );
          },
        );
      }),
    );
  }

  String _truncateUrl(String url) {
    if (url.length <= 50) return url;
    return '${url.substring(0, 25)}...${url.substring(url.length - 15)}';
  }
}