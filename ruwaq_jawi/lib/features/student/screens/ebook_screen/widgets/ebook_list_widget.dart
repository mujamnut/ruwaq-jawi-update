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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final ebook = ebooks[index];
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: slideController,
                  curve: Interval(
                    (index * 0.05).clamp(0.0, 1.0),
                    1.0,
                    curve: Curves.easeOut,
                  ),
                ),
              ),
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: fadeController,
                  curve: Interval(
                    (index * 0.05).clamp(0.0, 1.0),
                    1.0,
                    curve: Curves.easeOut,
                  ),
                ),
                child: EbookListCardWidget(ebook: ebook),
              ),
            );
          },
          childCount: ebooks.length,
        ),
      ),
    );
  }
}
