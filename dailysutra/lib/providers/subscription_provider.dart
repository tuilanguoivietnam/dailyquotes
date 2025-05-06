import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:convert';
import '../config/api_config.dart';
import '../services/storage_service.dart';
import '../services/subscription_service.dart';

// 订阅状态提供者
final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, bool>(
      (ref) => SubscriptionNotifier(),
);

class SubscriptionNotifier extends StateNotifier<bool> {
  SubscriptionNotifier() : super(false) {
    // 初始化时检查订阅状态
    _init();
  }

  Future<void> _init() async {
    // 检查订阅状态（iOS和Android都支持）
    final isSubscribed = await SubscriptionService.checkSubscription();
    state = isSubscribed;
  }

  // 刷新订阅状态
  Future<void> refreshSubscription() async {
    // 刷新订阅状态（iOS和Android都支持）
    final isSubscribed = await SubscriptionService.checkSubscription();
    state = isSubscribed;
  }

  // 设置订阅状态
  void setSubscription(bool value) {
    state = value;
  }

  // 验证苹果收据
  Future<void> verifyAppleReceipt(String receiptData, String productId, String? transactionId, {bool isPurchase = true, }) async {
    try {
      // 只在iOS设备上处理订阅
      if (!Platform.isIOS) {
        return;
      }

      // 使用统一的API端点，通过is_restore参数区分新购买和恢复购买
      const endpoint = '/api/verify-receipt';

      // 向后端发送收据数据进行验证
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'receipt_data': receiptData,
          'product_id': productId,
          'transaction_id': transactionId,
          'is_restore': !isPurchase, // 根据isPurchase参数设置is_restore
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('${isPurchase ? "验证收据" : "恢复购买"}失败: ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body);

      if (!responseData['valid']) {
        throw Exception(responseData['error']);
      }

      // 更新订阅状态
      state = responseData['is_active'];

      // 存储订阅ID以便后续检查
      final subscriptionId = responseData['subscription_id'];
      await StorageService.saveAppleSubscriptionId(subscriptionId);

      // 保存到期时间
      final expiresDate = DateTime.parse(responseData['expires_date']);
      await StorageService.saveAppleSubscription(
        subscriptionId,
        productId,
        expiresDate,
      );

      print('${isPurchase ? "订阅验证" : "恢复购买"}成功，订阅有效期至: $expiresDate');
    } catch (e) {
      print('${isPurchase ? "处理苹果收据" : "恢复购买"}失败: $e');
      rethrow;
    }
  }

  // 验证Google收据
  Future<void> verifyGoogleReceipt(String receiptData, String productId, String? purchaseToken, {bool isPurchase = true}) async {
    try {
      const endpoint = '/api/verify-google-receipt';

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'receipt_data': receiptData,
          'product_id': productId,
          'purchase_token': purchaseToken,
          'is_restore': !isPurchase,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('${isPurchase ? "验证收据" : "恢复购买"}失败: ${response.statusCode}');
      }

      final responseData = jsonDecode(response.body);

      if (!responseData['valid']) {
        throw Exception(responseData['error']);
      }

      // 更新订阅状态
      state = responseData['is_active'];

      // 存储订阅ID以便后续检查
      final subscriptionId = responseData['subscription_id'];
      await StorageService.saveGoogleSubscriptionId(subscriptionId);

      // 保存到期时间
      final expiresDate = DateTime.parse(responseData['expires_date']);
      await StorageService.saveGoogleSubscription(
        subscriptionId,
        productId,
        expiresDate,
      );

      print('${isPurchase ? "Google订阅验证" : "恢复购买"}成功，订阅有效期至: $expiresDate');
    } catch (e) {
      print('${isPurchase ? "处理Google收据" : "恢复购买"}失败: $e');
      rethrow;
    }
  }

  // 恢复购买
  Future<void> restorePurchases() async {
    try {
      await SubscriptionService.restorePurchases();
      await refreshSubscription();
    } catch (e) {
      print('恢复购买失败: $e');
      rethrow;
    }
  }
}