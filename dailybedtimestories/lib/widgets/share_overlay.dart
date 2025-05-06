import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class ShareOverlay extends StatelessWidget {
  const ShareOverlay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/logo.png',
              width: 48,
              height: 48,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'app_name'.tr(),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
