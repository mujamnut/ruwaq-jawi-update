import 'package:flutter/material.dart';
import '../../../widgets/shimmer_loading.dart';

class AdminUsersLoadingList extends StatelessWidget {
  const AdminUsersLoadingList({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: itemCount,
      itemBuilder: (context, index) => const UserShimmerCard(),
    );
  }
}
