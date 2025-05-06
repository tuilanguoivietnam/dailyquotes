import 'package:flutter/material.dart';

class RetryButton extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;

  const RetryButton({
    super.key,
    required this.onRetry,
    this.message = '加载失败，点击重试',
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            message,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
