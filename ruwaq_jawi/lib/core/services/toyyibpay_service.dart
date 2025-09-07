import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/payment_config.dart';

class ToyyibpayService {
  final String secretKey;
  final String categoryCode;
  final bool isProduction;

  ToyyibpayService({
    required this.secretKey,
    required this.categoryCode,
    required this.isProduction,
  }) {
    // Print configuration on initialization
    PaymentConfig.printConfig();

    // Validate configuration
    if (secretKey.isEmpty) {
      throw Exception('ToyyibPay Secret Key is not configured');
    }
    if (categoryCode.isEmpty) {
      throw Exception('ToyyibPay Category Code is not configured');
    }
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

      print('Request URL: ${PaymentConfig.createBillUrl}');
      print('Request Body: $requestBody');

      final response = await http.post(
        Uri.parse(PaymentConfig.createBillUrl),
        body: requestBody,
      );

      print('API Response Status Code: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final dynamic decodedResponse = json.decode(response.body);
        print('Decoded Response: $decodedResponse');

        // Handle both List and Map responses
        Map<String, dynamic> result;
        if (decodedResponse is List && decodedResponse.isNotEmpty) {
          result = decodedResponse[0] as Map<String, dynamic>;
        } else if (decodedResponse is Map<String, dynamic>) {
          result = decodedResponse;
        } else {
          throw Exception('Unexpected response format: $decodedResponse');
        }

        print('Processed Result: $result');

        // If we have a BillCode, it's a successful response
        if (result['BillCode'] != null) {
          final response = {
            'billCode': result['BillCode'],
            'billUrl': '${PaymentConfig.baseUrl}/${result['BillCode']}',
          };
          print('Successful Response: $response');
          return response;
        }

        // Only check error info if there's no BillCode
        if (result['status'] != null || result['msg'] != null) {
          print('Error Status: ${result['status']}');
          print('Error Message: ${result['msg']}');
          print('Full Error Result: $result');

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
