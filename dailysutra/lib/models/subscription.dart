import 'package:hive/hive.dart';

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  var price;
  final String? billingPeriod;
  final List<String>? features;

  SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    this.billingPeriod,
    this.features,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: json['price'].toDouble(),
      billingPeriod: json['billing_period'],
      features: List<String>.from(json['features']),
    );
  }
}

class UserSubscription {
  final String id;
  final String planId;
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;

  UserSubscription({
    required this.id,
    required this.planId,
    required this.startDate,
    required this.endDate,
    required this.isActive,
  });

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: json['id'],
      planId: json['plan_id'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      isActive: json['is_active'],
    );
  }
}