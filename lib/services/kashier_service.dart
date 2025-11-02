import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class KashierConfig {
  final String merchantId; // e.g. MID-31202-773
  final String apiKey; // used for HMAC secret as per docs
  final String? secretKey; // optional, not used by hash unless required
  final String currency; // e.g. EGP
  final String mode; // 'test' or 'live'

  KashierConfig({
    required this.merchantId,
    required this.apiKey,
    required this.currency,
    required this.mode,
    this.secretKey,
  });

  static KashierConfig fromEnv() {
    final mid = dotenv.env['KASHIER_MERCHANT_ID'] ?? '';
    final apiKey = dotenv.env['KASHIER_API_KEY'] ?? '';
    final secretKey = dotenv.env['KASHIER_SECRET_KEY'];
    final currency = dotenv.env['KASHIER_CURRENCY'] ?? 'EGP';
    final mode = (dotenv.env['KASHIER_MODE'] ?? 'test').toLowerCase();

    if (mid.isEmpty || apiKey.isEmpty) {
      throw StateError('Kashier env not set: KASHIER_MERCHANT_ID / KASHIER_API_KEY');
    }
    return KashierConfig(
      merchantId: mid,
      apiKey: apiKey,
      secretKey: secretKey,
      currency: currency,
      mode: (mode == 'live') ? 'live' : 'test',
    );
  }
}

class KashierService {
  // HMAC-SHA256 hash for order, per docs:
  // path = '/?payment={mid}.{orderId}.{amount}.{currency}[.{customerReference}]'
  static String generateOrderHash({
    required String mid,
    required String orderId,
    required String amount, // must match exactly what is sent (e.g. '100.00')
    required String currency, // e.g. 'EGP'
    String? customerReference,
    required String apiKeySecret,
  }) {
    final path = '/?payment=$mid.$orderId.$amount.$currency'
        '${customerReference != null && customerReference.isNotEmpty ? '.${customerReference}' : ''}';
    final key = utf8.encode(apiKeySecret);
    final bytes = utf8.encode(path);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString();
  }

  // Build Hosted Payment Page URL with required query params
  static Uri buildHostedPaymentUri({
    required KashierConfig config,
    required String orderId,
    required String amount,
    String? currency,
    String? customerReference,
    String mode = 'test',
    String? merchantRedirect,
    String? failureRedirect,
    String? allowedMethods, // e.g. 'card'
    String? defaultMethod, // e.g. 'card'
    String? redirectMethod, // e.g. 'get'
    Map<String, String>? extra,
  }) {
    final curr = currency ?? config.currency;
    final hash = generateOrderHash(
      mid: config.merchantId,
      orderId: orderId,
      amount: amount,
      currency: curr,
      customerReference: customerReference,
      apiKeySecret: config.apiKey,
    );

    final qp = <String, String>{
      'merchantId': config.merchantId,
      'orderId': orderId,
      'amount': amount,
      'currency': curr,
      'hash': hash,
      'mode': mode.isEmpty ? config.mode : mode,
    };
    if (merchantRedirect != null) qp['merchantRedirect'] = merchantRedirect;
    if (failureRedirect != null) qp['failureRedirect'] = failureRedirect;
    if (allowedMethods != null) qp['allowedMethods'] = allowedMethods;
    if (defaultMethod != null) qp['defaultMethod'] = defaultMethod;
    if (redirectMethod != null) qp['redirectMethod'] = redirectMethod;
    if (extra != null) qp.addAll(extra);

    return Uri.https('payments.kashier.io', '/', qp);
  }

  // Utility to format amounts exactly as sent to HPP and hashing
  static String formatAmount(num amount) {
    // Always 2 decimal places as string, e.g. '100.00'
    return amount.toStringAsFixed(2);
  }
}

