import 'dart:io';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:hive/hive.dart';
import '../config/api_config.dart';
import '../models/subscription.dart';
import 'package:http/http.dart' as http;

class SubscriptionService {
  static const String _subscriptionKey = 'user_subscription';
  
  // 获取订阅计划列表
  static Future<List<SubscriptionPlan>> getSubscriptionPlans() async {
    // 直接返回本地定义的订阅计划
    return _getSubscriptionPlans();
  }

  // 处理订阅购买 - 仅用于非iOS平台的测试
  static Future<bool> subscribe(String planId) async {
    if (Platform.isIOS) {
      throw Exception('subscription.ios_purchase_only'.tr());
    }
    
    // 仅用于测试
    await saveSubscription(
      'test_${DateTime.now().millisecondsSinceEpoch}',
      planId,
      DateTime.now().add(const Duration(days: 30))
    );
    return true;
  }

  // 检查用户是否已订阅
  static Future<bool> checkSubscription() async {
    try {
      // 检查本地订阅状态
      final subscription = await getUserSubscription();
      if (subscription != null) {
        // 如果本地有订阅信息，先检查是否过期
        final now = DateTime.now();
        final isExpired = subscription.endDate.isBefore(now);

        // 如果已过期，但有订阅ID，尝试与服务器验证
        if (isExpired || subscription.id != null) {
          // 尝试与服务器验证最新状态
          // 向服务器验证订阅状态
          final response = await http.get(
            Uri.parse('${ApiConfig.baseUrl}/api/check-subscription/${subscription.id}'),
          );

          if (response.statusCode != 200) {
            throw Exception('检查订阅状态失败');
          }

          final serverStatus = jsonDecode(response.body);
          if (serverStatus != null) {
            // 如果服务器返回订阅有效，更新本地状态
            if (serverStatus['is_active']) {
              // 更新本地订阅信息
              if (serverStatus['expires_date'] != null) {
                final newExpiryDate = DateTime.parse(serverStatus['expires_date']);
                await saveSubscription(
                  subscription.id,
                  subscription.planId,
                  newExpiryDate,
                );
              }
              return true;
            }

            // 如果服务器返回订阅无效但启用了自动续订，可能是支付处理延迟
            if (serverStatus['auto_renew_status'] &&
                now.difference(subscription.endDate).inDays < 3) { // 给予宽限期
              return true;
            }

            // 服务器确认订阅无效，清除本地记录
            if (!serverStatus['is_active']) {
              final box = await Hive.openBox('dailybible_settings');
              await box.delete(_subscriptionKey);
              await box.delete('apple_subscription_id');
              await box.delete('google_subscription_id');
              return false;
            }
          }
        }

        // 如果无法连接服务器，暂时信任本地数据
        return subscription.endDate.isAfter(now);
      }

      return false;
    } catch (e) {
      print('检查订阅状态失败: $e');
      return false;
    }
  }

  // 获取用户订阅信息
  static Future<UserSubscription?> getUserSubscription() async {
    // 只在iOS设备上获取订阅信息
    // if (!Platform.isIOS) {
    //   return null;
    // }
    
    try {
      final box = await Hive.openBox('dailybible_settings');
      final subscriptionData = box.get(_subscriptionKey);
      
      if (subscriptionData != null) {
        return UserSubscription.fromJson(json.decode(subscriptionData));
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
  
  // 保存苹果订阅信息
  static Future<void> saveAppleSubscription(
    String subscriptionId,
    String productId,
    DateTime expiresDate,
  ) async {
    try {
      // 添加7天免费试用期
      final now = DateTime.now();
      final trialEndDate = now.add(const Duration(days: 7));
      
      await saveSubscription(subscriptionId, productId, expiresDate, trialEndDate: trialEndDate);
    } catch (e) {
      print('subscription.save_failed'.tr() + ': $e');
      rethrow;
    }
  }
  
  // 统一的保存订阅信息方法
  static Future<void> saveSubscription(
    String subscriptionId,
    String productId,
    DateTime expiresDate,
    {DateTime? trialEndDate}
  ) async {
    final now = DateTime.now();
    
    final subscription = UserSubscription(
      id: subscriptionId,
      planId: productId,
      startDate: now,
      endDate: expiresDate,
      isActive: true,
    );
    
    final box = await Hive.openBox('dailybible_settings');
    await box.put(_subscriptionKey, json.encode({
      'id': subscription.id,
      'plan_id': subscription.planId,
      'start_date': subscription.startDate.toIso8601String(),
      'end_date': subscription.endDate.toIso8601String(),
      'is_active': subscription.isActive,
      'trial_end_date': trialEndDate?.toIso8601String(),
    }));
  }
  
  // 保存Google订阅信息
  static Future<void> saveGoogleSubscription(
    String subscriptionId,
    String productId,
    DateTime expiresDate,
  ) async {
    try {
      // 添加7天免费试用期
      final now = DateTime.now();
      final trialEndDate = now.add(const Duration(days: 7));

      await saveSubscription(subscriptionId, productId, expiresDate, trialEndDate: trialEndDate);
    } catch (e) {
      print('subscription.save_failed'.tr() + ': $e');
      rethrow;
    }
  }

  // 恢复购买
  static Future<void> restorePurchases() async {
    try {
      final InAppPurchase inAppPurchase = InAppPurchase.instance;
      await inAppPurchase.restorePurchases();
    } catch (e) {
      print('subscription.restore_failed'.tr() + ': $e');
      rethrow;
    }
  }

  // 订阅计划数据
  static List<SubscriptionPlan> _getSubscriptionPlans() {
    return [
      SubscriptionPlan(
        id: 'monthly',
        name: 'subscription.monthly_plan'.tr(),
        description: 'subscription.monthly_description'.tr(),
        price: 1.99,
        billingPeriod: 'subscription.monthly_period'.tr(),
        features: [
          'subscription.benefit_no_ads'.tr(),
          'subscription.benefit_white_noise'.tr(),
          'subscription.benefit_premium_quotes'.tr(),
          'subscription.benefit_themes'.tr()
        ],
      ),
      SubscriptionPlan(
        id: 'yearly',
        name: 'subscription.yearly_plan'.tr(),
        description: 'subscription.yearly_description'.tr(),
        price: 9.99,
        billingPeriod: 'subscription.yearly_period'.tr(),
        features: [
          'subscription.benefit_no_ads'.tr(),
          'subscription.benefit_white_noise'.tr(),
          'subscription.benefit_premium_quotes'.tr(),
          'subscription.benefit_themes'.tr(),
          'subscription.benefit_priority_support'.tr()
        ],
      ),
    ];
  }
}