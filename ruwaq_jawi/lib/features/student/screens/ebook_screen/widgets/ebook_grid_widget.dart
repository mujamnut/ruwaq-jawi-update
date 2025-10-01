import 'package:flutter/material.dart';
import '../../../../../core/models/ebook.dart';
import 'ebook_card_widget.dart';

class EbookGridWidget extends StatelessWidget {
  final List<Ebook> ebooks;
  final AnimationController fadeController;
  final AnimationController slideController;

  const EbookGridWidget({
    super.key,
    required this.ebooks,
    required this.fadeController,
    required this.slideController,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.65,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final ebook = ebooks[index];
            return SlideTransition(
              position: Tween<Offset>(
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
                child: EbookCardWidget(
                  ebook: ebook,
                  index: index,
                ),
              ),
            );
          },
          childCount: ebooks.length,
        ),
      ),
    );
  }
}
