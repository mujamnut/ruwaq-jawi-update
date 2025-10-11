import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AdminUsersErrorDetails {
  const AdminUsersErrorDetails({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;
}

class AdminUsersErrorMapper {
  String messageFor(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('socketexception') ||
        errorString.contains('failed host lookup') ||
        errorString.contains('no address associated with hostname') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection timed out')) {
      return 'Tiada sambungan internet. Sila semak sambungan anda dan cuba lagi.';
    }

    if (errorString.contains('authretryablefetchexception') ||
        errorString.contains('invalid_grant') ||
        errorString.contains('unauthorized')) {
      return 'Sesi anda telah tamat. Sila log masuk semula.';
    }

    if (errorString.contains('500') ||
        errorString.contains('internal server error')) {
      return 'Pelayan mengalami masalah. Sila cuba lagi dalam beberapa minit.';
    }

    if (errorString.contains('timeout')) {
      return 'Permintaan mengambil masa terlalu lama. Sila cuba lagi.';
    }

    if (errorString.contains('clientexception') ||
        errorString.contains('httperror')) {
      return 'Masalah sambungan rangkaian. Sila semak sambungan internet anda.';
    }

    return 'Ralat tidak dijangka berlaku. Sila cuba lagi atau hubungi sokongan teknikal.';
  }

  AdminUsersErrorDetails detailsFor(String message) {
    if (message.contains('sambungan internet') ||
        message.contains('sambungan rangkaian')) {
      return const AdminUsersErrorDetails(
        icon: HugeIcons.strokeRoundedWifiDisconnected02,
        title: 'Tiada Sambungan Internet',
      );
    } else if (message.contains('sesi') || message.contains('log masuk')) {
      return const AdminUsersErrorDetails(
        icon: HugeIcons.strokeRoundedLockPassword,
        title: 'Sesi Tamat Tempoh',
      );
    } else if (message.contains('pelayan') || message.contains('server')) {
      return const AdminUsersErrorDetails(
        icon: HugeIcons.strokeRoundedCloud,
        title: 'Masalah Pelayan',
      );
    } else if (message.contains('masa terlalu lama') ||
        message.contains('timeout')) {
      return const AdminUsersErrorDetails(
        icon: HugeIcons.strokeRoundedClock01,
        title: 'Sambungan Terputus',
      );
    }

    return const AdminUsersErrorDetails(
      icon: HugeIcons.strokeRoundedAlert02,
      title: 'Ralat Sistem',
    );
  }
}
