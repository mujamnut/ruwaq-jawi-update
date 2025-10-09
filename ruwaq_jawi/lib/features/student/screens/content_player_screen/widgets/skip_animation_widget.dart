import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class SkipAnimationWidget extends StatelessWidget {
  final bool showSkipAnimation;
  final bool isSkipForward;
  final bool isSkipOnLeftSide;
  final bool isFullscreen;

  const SkipAnimationWidget({
    super.key,
    required this.showSkipAnimation,
    required this.isSkipForward,
    required this.isSkipOnLeftSide,
    this.isFullscreen = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!showSkipAnimation) return const SizedBox.shrink();

    final screenHeight = MediaQuery.of(context).size.height;
    final topPosition = isFullscreen ? (screenHeight / 2 - 50) : (screenHeight / 2 - 200);

    return Positioned(
      left: isSkipOnLeftSide ? 40 : null,
      right: !isSkipOnLeftSide ? 40 : null,
      top: topPosition,
      child: AnimatedOpacity(
        opacity: showSkipAnimation ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 300),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PhosphorIcon(
                isSkipForward
                    ? PhosphorIcons.fastForward(PhosphorIconsStyle.fill)
                    : PhosphorIcons.rewind(PhosphorIconsStyle.fill),
                color: Colors.white,
                size: 32,
              ),
              const SizedBox(width: 8),
              const Text(
                '10s',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
