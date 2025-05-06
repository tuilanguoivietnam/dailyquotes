import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/rating_service.dart';

class RatingDialog extends StatelessWidget {
  const RatingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: contentBox(context),
    );
  }

  Widget contentBox(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        shape: BoxShape.rectangle,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10.0,
            offset: const Offset(0.0, 10.0),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // 标题
          Text(
            'rating.title'.tr(),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          
          // 星形图标
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return Icon(
                Icons.star,
                color: Colors.amber,
                size: 36,
              );
            }),
          ),
          const SizedBox(height: 20),
          
          // 提示文本
          Text(
            'rating.message'.tr(),
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // 按钮
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () async {
                  RatingService.recordUserRated();
                  Navigator.pop(context);

                  final url = Uri.parse(
                      'https://apps.apple.com/us/app/dailymind-for-a-better-life/id6745580917');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text('rating.rate_now'.tr()),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: Text('rating.later'.tr()),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  RatingService.recordNeverAskAgain();
                  Navigator.pop(context);
                },
                style: TextButton.styleFrom(
                  minimumSize: const Size(double.infinity, 40),
                ),
                child: Text(
                  'rating.no_thanks'.tr(),
                  style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 