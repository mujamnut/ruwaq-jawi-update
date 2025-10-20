import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../../core/theme/app_theme.dart';

IconData notificationIconForType(String type) {
  switch (type.toLowerCase()) {
    case 'email':
      return PhosphorIcons.envelope();
    case 'push':
      return PhosphorIcons.bell();
    case 'announcement':
    case 'admin_announcement':
      return PhosphorIcons.megaphone();
    case 'update':
    case 'content_published':
      return PhosphorIcons.downloadSimple();
    case 'promotion':
      return PhosphorIcons.gift();
    case 'reminder':
      return PhosphorIcons.clock();
    case 'system':
      return PhosphorIcons.gear();
    case 'payment':
    case 'payment_success':
      return PhosphorIcons.creditCard();
    case 'subscription':
    case 'subscription_expiring':
      return PhosphorIcons.crown();
    case 'content':
      return PhosphorIcons.bookOpen();
    default:
      return PhosphorIcons.bellRinging();
  }
}

Color notificationColorForType(String type) {
  switch (type.toLowerCase()) {
    case 'email':
      return Colors.blue;
    case 'push':
      return AppTheme.primaryColor;
    case 'announcement':
    case 'admin_announcement':
      return Colors.orange;
    case 'update':
    case 'content_published':
      return Colors.green;
    case 'promotion':
      return Colors.purple;
    case 'reminder':
      return Colors.amber;
    case 'system':
      return Colors.grey;
    case 'payment':
    case 'payment_success':
      return Colors.teal;
    case 'subscription':
    case 'subscription_expiring':
      return const Color(0xFFFFD700);
    case 'content':
      return AppTheme.primaryColor;
    default:
      return AppTheme.primaryColor;
  }
}

String typeDisplayName(String type) {
  switch (type.toLowerCase()) {
    case 'email':
      return 'E-mel';
    case 'push':
      return 'Push';
    case 'announcement':
    case 'admin_announcement':
      return 'Pengumuman';
    case 'update':
      return 'Kemaskini';
    case 'promotion':
      return 'Promosi';
    case 'reminder':
      return 'Peringatan';
    case 'system':
      return 'Sistem';
    case 'payment':
    case 'payment_success':
      return 'Pembayaran';
    case 'subscription':
    case 'subscription_expiring':
      return 'Langganan';
    case 'content':
    case 'content_published':
      return 'Kandungan';
    default:
      return 'Umum';
  }
}

String formatTimeAgoShort(DateTime dateTime) {
  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.inMinutes < 1) {
    return 'Baru saja';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes} min lalu';
  } else if (difference.inHours < 24) {
    return '${difference.inHours} jam lalu';
  } else if (difference.inDays < 7) {
    return '${difference.inDays} hari lalu';
  } else {
    return '${(difference.inDays / 7).floor()} minggu lalu';
  }
}

