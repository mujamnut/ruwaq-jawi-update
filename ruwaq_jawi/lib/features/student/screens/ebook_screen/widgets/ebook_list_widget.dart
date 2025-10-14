import 'package:flutter/material.dart';
import '../../../../../core/models/ebook.dart';
import 'ebook_list_card_widget.dart';

class EbookListWidget extends StatelessWidget {
  final List<Ebook> ebooks;
  final AnimationController fadeController;
  final AnimationController slideController;

  const EbookListWidget({
    super.key,
    required this.ebooks,
    required this.fadeController,
    required this.slideController,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final ebook = ebooks[index];
          // Wrap with RepaintBoundary for better performance
          return RepaintBoundary(
            child: SlideTransition(
              position:
                  Tween<Offset>(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: slideController,
                      curve: Interval(
                        (index * 0.1).clamp(0.0, 1.0),
                        1.0,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                  ),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: fadeController,
                  curve: Interval(
                    (index * 0.1).clamp(0.0, 1.0),
                    1.0,
                    curve: Curves.easeOut,
                  ),
                ),
                child: EbookListCardWidget(ebook: ebook),
              ),
            ),
          );
        }, childCount: ebooks.length),
      ),
    );
  }
}
