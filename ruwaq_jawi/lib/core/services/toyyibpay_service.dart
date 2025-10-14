import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/payment_config.dart';
import '../utils/app_logger.dart';

class ToyyibpayService {
  final String secretKey;
  final String categoryCode;
  final bool isProduction;

  ToyyibpayService({
    required this.secretKey,
    required this.categoryCode,
    required this.isProduction,
  }) {
    // Validate configuration (PaymentConfig should be initialized in main.dart)
    if (secretKey.isEmpty) {
      throw Exception('ToyyibPay Secret Key is not configured. Please check your .env file.');
    }
    if (categoryCode.isEmpty) {
      throw Exception('ToyyibPay Category Code is not configured. Please check your .env file.');
    }

    // Log service initialization
    AppLogger.info('ToyyibpayService initialized successfully', tag: 'ToyyibpayService');
  }

  Future<Map<String, dynamic>> createBill({
    required double amount,
    required String userId,
    required String planId,
    required String description,
    required String email,
    required String name,
    String? phone,
  }) async {
    try {
      // Prepare request body
      final requestBody = {
        'userSecretKey': secretKey,
        'categoryCode': categoryCode,
        'billName': 'Ruwaq Jawi Subscription',
        'billDescription': description,
        'billPriceSetting': '1',
        'billPayorInfo': '1',
        'billAmount': (amount * 100).toInt().toString(), // Convert to cents
        'billReturnUrl': PaymentConfig.paymentSuccessUrl,
        'billCallbackUrl': PaymentConfig.webhookUrl,
        'billExternalReferenceNo': '${userId}_$planId',
        'billTo': name,
        'billEmail': email,
        'billPhone': phone?.isNotEmpty == true ? phone : '60123456789',
        'billSplitPayment': '0',
        'billSplitPaymentArgs': '',
        'billPaymentChannel': '0',
        'billDisplayMerchant': '1',
        'billContentEmail': 'Thank you for subscribing to Ruwaq Jawi!',
      };

      AppLogger.info('Request URL: ${PaymentConfig.createBillUrl}', tag: 'ToyyibpayService');
      AppLogger.info('Creating bill for user: $userId, plan: $planId, amount: $amount', tag: 'ToyyibpayService');

      final response = await http.post(
        Uri.parse(PaymentConfig.createBillUrl),
        body: requestBody,
      );

      AppLogger.info('API Response Status Code: ${response.statusCode}', tag: 'ToyyibpayService');
      AppLogger.debug('API Response Body: ${response.body}', tag: 'ToyyibpayService');

      if (response.statusCode == 200) {
        final dynamic decodedResponse = json.decode(response.body);
        AppLogger.debug('Decoded Response: $decodedResponse', tag: 'ToyyibpayService');

        // Handle both List and Map responses
        Map<String, dynamic> result;
        if (decodedResponse is List && decodedResponse.isNotEmpty) {
          result = decodedResponse[0] as Map<String, dynamic>;
        } else if (decodedResponse is Map<String, dynamic>) {
          result = decodedResponse;
        } else {
          throw Exception('Unexpected response format: $decodedResponse');
        }

        AppLogger.debug('Processed Result: $result', tag: 'ToyyibpayService');

        // If we have a BillCode, it's a successful response
        if (result['BillCode'] != null) {
          final response = {
            'billCode': result['BillCode'],
            'billUrl': '${PaymentConfig.baseUrl}/${result['BillCode']}',
          };
          AppLogger.info('Bill created successfully: ${result['BillCode']}', tag: 'ToyyibpayService');
          return response;
        }

        // Only check error info if there's no BillCode
        if (result['status'] != null || result['msg'] != null) {
          AppLogger.warning('Error Status: ${result['status']}', tag: 'ToyyibpayService');
          AppLogger.warning('Error Message: ${result['msg']}', tag: 'ToyyibpayService');
          AppLogger.error('Full Error Result: $result', tag: 'ToyyibpayService');

          throw Exception(
            'Failed to create bill: ${result['msg'] ?? 'Unknown error'} (Status: ${result['status']})',
          );
        }

        throw Exception('Failed to create bill: Unexpected response format');
      }
      throw Exception('Failed to create bill: ${response.body}');
    } catch (e) {
      throw Exception('Error creating bill: $e');
    }
  }

  Future<Map<String, dynamic>> getBillStatus(String billCode) async {
    try {
      final response = await http.post(
        Uri.parse(PaymentConfig.getBillUrl),
        body: {'userSecretKey': secretKey, 'billCode': billCode},
      );

      if (response.statusCode == 200) {
        final dynamic decodedResponse = json.decode(response.body);

        // Handle both List and Map responses
        if (decodedResponse is List && decodedResponse.isNotEmpty) {
          return decodedResponse[0] as Map<String, dynamic>;
        } else if (decodedResponse is Map<String, dynamic>) {
          return decodedResponse;
        }
        throw Exception('Bill not found');
      }
      throw Exception('Failed to get bill status: ${response.body}');
    } catch (e) {
      throw Exception('Error getting bill status: $e');
    }
  }
}
