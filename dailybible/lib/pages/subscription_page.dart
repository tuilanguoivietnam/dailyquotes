import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../models/subscription.dart';
import '../services/subscription_service.dart';
import '../providers/subscription_provider.dart';
import '../utils/responsive_utils.dart';
import 'package:flutter/services.dart';

/// 苹果支付队列委托实现
class ExamplePaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(
      SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    return false;
  }
}

class SubscriptionPage extends ConsumerStatefulWidget {
  const SubscriptionPage({Key? key}) : super(key: key);

  @override
  ConsumerState<SubscriptionPage> createState() => _SubscriptionPageState();
}

class _SubscriptionPageState extends ConsumerState<SubscriptionPage> {
  bool _isLoading = true;
  List<SubscriptionPlan> _subscriptionPlans = [];
  String? _selectedPlanId;
  bool _processingPurchase = false;
  bool _processingRestore = false;

  // 内购相关变量
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  List<ProductDetails> _products = [];

  @override
  void initState() {
    super.initState();
    // _loadSubscriptionPlans();

    // 初始化内购监听（iOS和Android都需要）
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(_listenToPurchaseUpdated);

    // 初始化内购
    _initInAppPurchase();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  // 初始化内购
  Future<void> _initInAppPurchase() async {
    final bool available = await _inAppPurchase.isAvailable();
    if (!available) {
      setState(() {
        _products = [];
        _isLoading = false;
      });
      return;
    }

    if (Platform.isIOS) {
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase
              .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iosPlatformAddition.setDelegate(ExamplePaymentQueueDelegate());
    }

    // 产品ID列表（iOS和Android使用相同的产品ID）
    const Set<String> kProductIds = <String>{
      'com.civisolo.dailybible.premium_monthly',
      'com.civisolo.dailybible.premium_yearly',
    };

    // 加载产品信息
    try {
      final ProductDetailsResponse productDetailResponse =
          await _inAppPurchase.queryProductDetails(kProductIds);
      if (productDetailResponse.error != null) {
        print('查询产品详情失败: ${productDetailResponse.error}');
        setState(() {
          _products = [];
          _isLoading = false;
        });
        return;
      }

      if (productDetailResponse.productDetails.isEmpty) {
        print('未找到产品详情');
        setState(() {
          _products = [];
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _products = productDetailResponse.productDetails;
        _subscriptionPlans =
            productDetailResponse.productDetails
                .where((product) {
                  if (product is GooglePlayProductDetails && product.rawPrice == 0){
                    return false;
                  }
                  return true;
                })
                .map((product) {
          print('产品详情: ${product.title} - ${product.description} - ${product.price}');
          return SubscriptionPlan(
            id: product.id,
            name: product.title,
            description: product.description,
            price: product.price,
          );
        }).toList();
        if (_subscriptionPlans.isNotEmpty) {
          _selectedPlanId = _subscriptionPlans[0].id;
        }
        _isLoading = false;
      });
    } catch (e) {
      print('内购产品加载失败: $e');
      setState(() {
        _products = [];
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSubscriptionPlans() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final plans = await SubscriptionService.getSubscriptionPlans();
      setState(() {
        _subscriptionPlans = plans;
        if (plans.isNotEmpty) {
          _selectedPlanId = plans[0].id; // 默认选择第一个计划
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载订阅计划失败: $e')),
        );
      }
    }
  }

  // 处理购买更新
  Future<void> _listenToPurchaseUpdated(
      List<PurchaseDetails> purchaseDetailsList) async {
    bool hasRestoredPurchase = false;

    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // 购买进行中
        setState(() {
          _processingPurchase = true;
        });
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // 购买出错
        setState(() {
          _processingPurchase = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text('subscription.purchase_failed'.tr() +
                    ': ${purchaseDetails.error!.message}')),
          );
        }
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // 购买成功或恢复购买
        // 验证收据
        try {
          if (purchaseDetails.status == PurchaseStatus.restored) {
            // 标记已经恢复了购买
            hasRestoredPurchase = true;
            setState(() {
              _processingRestore = false;
            });
          }

          // 根据平台调用不同的验证方法
          if (Platform.isIOS) {
            await ref.read(subscriptionProvider.notifier).verifyAppleReceipt(
                  purchaseDetails.verificationData.serverVerificationData,
                  purchaseDetails.productID,
                  purchaseDetails.status == PurchaseStatus.restored
                      ? purchaseDetails.purchaseID
                      : null,
                  isPurchase: purchaseDetails.status == PurchaseStatus.purchased,
                );
          } else if (Platform.isAndroid) {
            // Android Google Play收据验证
            if (purchaseDetails is GooglePlayPurchaseDetails) {
              await ref.read(subscriptionProvider.notifier).verifyGoogleReceipt(
                purchaseDetails.verificationData.serverVerificationData,
                purchaseDetails.productID,
                purchaseDetails.billingClientPurchase.purchaseToken,
                isPurchase: purchaseDetails.status == PurchaseStatus.purchased,
              );
            }
          }

          // 只有新购买才显示成功信息
          if (mounted && purchaseDetails.status == PurchaseStatus.purchased) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('subscription.purchase_success'.tr())),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('subscription.verification_failed'.tr() + ': $e')),
            );
          }
        }

        // 完成购买
        if (purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }

        setState(() {
          _processingPurchase = false;
        });
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        // 购买取消
        setState(() {
          _processingPurchase = false;
        });
      }
    }

    // 如果有恢复购买，在所有处理完毕后显示一次恢复成功的消息
    if (hasRestoredPurchase && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('subscription.restore_success'.tr())),
      );
    }

    if (_processingRestore) {
      setState(() {
        _processingRestore = false;
      });
    }
  }

  // 订阅方法
  Future<void> _subscribe() async {
    if (_selectedPlanId == null) return;

    setState(() {
      _processingPurchase = true;
    });

    try {
      // 找到对应的产品
      ProductDetails? productToBuy = _products.firstWhere(
        (product) => product.id == _selectedPlanId,
        orElse: () => throw Exception('未找到产品: $_selectedPlanId'),
      );

      if (productToBuy != null) {
        final PurchaseParam purchaseParam = PurchaseParam(
          productDetails: productToBuy,
          applicationUserName: null,
        );

        // 根据产品类型购买订阅
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        throw Exception('subscription.product_not_found'.tr());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('subscription.purchase_failed'.tr() + ': $e')),
        );
      }
      setState(() {
        _processingPurchase = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubscribed = ref.watch(subscriptionProvider);
    final screenSize = MediaQuery.of(context).size;
    final isTablet = ResponsiveUtils.isTablet(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'subscription.title'.tr(),
          style: const TextStyle(color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.background,
              Theme.of(context).colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 7天免费试用提示
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primaryContainer
                            .withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Theme.of(context).colorScheme.primary),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'subscription.free_trial'.tr(),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'subscription.free_trial_description'.tr(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 会员特权介绍
                    _buildMembershipBenefits(context),
                    const SizedBox(height: 24),

                    // 会员计划选择
                    if (!isSubscribed) ...[
                      Text(
                        'subscription.select_plan'.tr(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      _buildSubscriptionPlans(context),
                      const SizedBox(height: 24),

                      // 订阅按钮
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _processingPurchase ? null : _subscribe,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _processingPurchase
                              ? const CircularProgressIndicator()
                              : Text('subscription.subscribe_now'.tr(),
                                  style: const TextStyle(fontSize: 18)),
                        ),
                      ),
                    ] else ...[
                      // 已订阅状态
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.check_circle,
                                  size: 48, color: Colors.green),
                              const SizedBox(height: 8),
                              Text(
                                'subscription.purchase_success_title'.tr(),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'subscription.purchase_success_message'.tr(),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    ],

                    const SizedBox(height: 24),

                    // 恢复购买按钮
                    const SizedBox(height: 16),
                    Center(
                      child: TextButton(
                        onPressed: () async {
                          try {
                            setState(() {
                              _processingRestore = true;
                            });

                            // 调用恢复购买功能，实际消息会在_listenToPurchaseUpdated中显示
                            await ref
                                .read(subscriptionProvider.notifier)
                                .restorePurchases();
                          } catch (e) {
                            setState(() {
                              _processingRestore = false;
                            });

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(
                                        'subscription.restore_failed'.tr() +
                                            ': $e')),
                              );
                            }
                          }
                        },
                        child: _processingRestore
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              )
                            : Text('subscription.restore_purchases'.tr()),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 服务条款和隐私政策或会员有效期信息
                    Center(
                      child: FutureBuilder<UserSubscription?>(
                        future: SubscriptionService.getUserSubscription(),
                        builder: (context, snapshot) {
                          if (isSubscribed &&
                              snapshot.hasData &&
                              snapshot.data != null) {
                            // 显示会员有效期和取消订阅提醒
                            final subscription = snapshot.data!;
                            final expiryDate = DateFormat('yyyy-MM-dd')
                                .format(subscription.endDate);
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(
                                    'subscription.subscription_expires'
                                        .tr()
                                        .replaceAll('{}', expiryDate),
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'subscription.cancel_notice'.tr(),
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            );
                          } else {
                            // 显示服务条款和隐私政策
                            return Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  style: Theme.of(context).textTheme.bodySmall,
                                  children: [
                                    TextSpan(
                                      text: 'subscription.terms_prefix'.tr(),
                                    ),
                                    TextSpan(
                                      text:
                                          'subscription.terms_of_service'.tr(),
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () async {
                                          // Navigate to Terms of Service
                                          final url = Uri.parse(
                                              'http://localhost:8000/terms-of-service');
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url,
                                                mode: LaunchMode
                                                    .externalApplication);
                                          }
                                        },
                                    ),
                                    TextSpan(
                                      text: 'subscription.terms_and'.tr(),
                                    ),
                                    TextSpan(
                                      text: 'subscription.privacy_policy'.tr(),
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .primary,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                      recognizer: TapGestureRecognizer()
                                        ..onTap = () async {
                                          final url = Uri.parse(
                                              'http://localhost:8000/privacy-policy');
                                          if (await canLaunchUrl(url)) {
                                            await launchUrl(url,
                                                mode: LaunchMode
                                                    .externalApplication);
                                          }
                                        },
                                    ),
                                    // Add suffix for Japanese
                                    if (context.locale.languageCode == 'ja')
                                      TextSpan(
                                        text: 'subscription.terms_suffix'.tr(),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMembershipBenefits(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'subscription.benefits_title'.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          // const SizedBox(height: 16),
          // _buildBenefitItem(Icons.block, 'subscription.benefit_no_ads'.tr(),
          //     'subscription.benefit_no_ads_desc'.tr()),
          // const SizedBox(height: 12),
          // _buildBenefitItem(
          //     Icons.music_note,
          //     'subscription.benefit_white_noise'.tr(),
          //     'subscription.benefit_white_noise_desc'.tr()),
          const SizedBox(height: 12),
          _buildBenefitItem(
              Icons.auto_awesome,
              'subscription.benefit_premium_quotes'.tr(),
              'subscription.benefit_premium_quotes_desc'.tr()),
          // const SizedBox(height: 12),
          // _buildBenefitItem(
          //     Icons.color_lens,
          //     'subscription.benefit_themes'.tr(),
          //     'subscription.benefit_themes_desc'.tr()),
        ],
      ),
    );
  }

  Widget _buildBenefitItem(IconData icon, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSubscriptionPlans(BuildContext context) {
    return Column(
      children: _subscriptionPlans.map<Widget>((plan) {
        final isSelected = _selectedPlanId == plan.id;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedPlanId = plan.id;
            });
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.surface,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Radio<String>(
                  value: plan.id,
                  groupValue: _selectedPlanId,
                  onChanged: (value) {
                    setState(() {
                      _selectedPlanId = value;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(plan.description),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${plan.price}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      plan.id.contains('yearly')
                          ? 'subscription.yearly_period'.tr()
                          : 'subscription.monthly_period'.tr(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
