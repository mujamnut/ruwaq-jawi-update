import 'package:flutter/material.dart';
import '../../../../../core/models/ebook.dart';

class EbookDescriptionWidget extends StatelessWidget {
  final Ebook ebook;

  const EbookDescriptionWidget({super.key, required this.ebook});

  @override
  Widget build(BuildContext context) {
    if (ebook.description == null || ebook.description!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Deskripsi E-Book',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          ebook.description!,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6),
          textAlign: TextAlign.justify,
        ),
      ],
    );
  }
}