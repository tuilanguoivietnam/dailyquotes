import './storage_service.dart';
import 'package:http/http.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import '../widgets/affirmation_card.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/share_overlay.dart';

class ShareService {
  static Future<void> shareAffirmation(
      ScreenshotController screenshotController,
      {BuildContext? context,
      Function? onShareComplete}) async {
    try {
      if (context == null) {
        throw Exception('Context is required for capturing');
      }

      // 尝试获取当前显示的AffirmationCard
      final AffirmationCard? card = _findAffirmationCard(context);
      if (card == null) {
        throw Exception('无法找到AffirmationCard组件');
      }

      final backgroundImagePath = await StorageService.getBackgroundImage();

      // 创建一个不带滚动和高度限制的卡片内容，用于截图
      final fullContentWidget = _buildFullContentWidget(context, card, backgroundImagePath);
      
      // 获取屏幕宽度
      final screenWidth = MediaQuery.of(context).size.width;
      
      // 使用TextPainter计算文本实际需要的高度
      final theme = Theme.of(context);
      final fontSize = card.fontSize ?? 44.0;
      
      // 创建文本样式与卡片中相同
      final textStyle = theme.textTheme.headlineSmall?.copyWith(
        fontFamily: _getFontFamily(card.affirmation),
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
        height: 1.6,
        color: theme.colorScheme.onPrimaryContainer,
      );
      
      // 计算文本实际宽度（减去左右padding）
      final textWidth = screenWidth - 64; // 左右各32的padding
      
      // 使用TextPainter计算文本高度
      final textPainter = TextPainter(
        text: TextSpan(
          text: card.affirmation,
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
        maxLines: null, // 允许多行
      );
      
      // 设置宽度限制并布局
      textPainter.layout(maxWidth: textWidth);
      
      // 获取文本高度
      final textHeight = textPainter.height;
      
      // 计算总高度：上下padding(80*2) + 文本高度 + 中间间距(64) + ShareOverlay估计高度(100)
      final estimatedHeight = 80 * 2 + textHeight + 64 + 100;
      
      // 额外添加一些边距，确保不会溢出
      final finalHeight = estimatedHeight * 1.2;
      
      print('Text height: $textHeight, Estimated total height: $finalHeight');
      
      // 使用captureFromWidget捕获整个内容
      final Uint8List? imageBytes = await screenshotController.captureFromWidget(
        fullContentWidget,
        delay: const Duration(milliseconds: 200),
        pixelRatio: MediaQuery.of(context).devicePixelRatio * 1.5,
        targetSize: Size(
          screenWidth, 
          finalHeight
        ),
      );
      
      if (imageBytes == null) {
        print('Error: Failed to capture screenshot - imageBytes is null');
        throw Exception('Failed to capture screenshot');
      }

      // 保存截图到临时文件
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final random = Random().nextInt(10000);
      final file =
          File('${tempDir.path}/affirmation_share_${timestamp}_$random.png');
      try {
        await file.writeAsBytes(imageBytes);
        print('Successfully saved image to: ${file.path}');
      } catch (e) {
        print('Error saving file: $e');
        throw Exception('Failed to save image file');
      }

      // 直接分享图片
      try {
        final result = await Share.shareXFiles(
          [XFile(file.path, mimeType: 'image/png')],
        );
        print('Share result: $result');

        // 无论分享成功与否，都确保清理临时文件
        if (await file.exists()) {
          await file.delete();
        }
        
        // 完成回调
        onShareComplete?.call();
      } catch (e) {
        print('Error sharing file: $e');
        // 确保清理临时文件
        if (await file.exists()) {
          await file.delete();
        }
        throw Exception('Failed to share image: $e');
      }
    } catch (e) {
      print('Error in shareAffirmation: $e');
      onShareComplete?.call();
      rethrow;
    }
  }
  
  // 在Widget树中查找AffirmationCard组件
  static AffirmationCard? _findAffirmationCard(BuildContext context) {
    AffirmationCard? result;
    void visitor(Element element) {
      if (element.widget is AffirmationCard) {
        result = element.widget as AffirmationCard;
        return;
      }
      element.visitChildren(visitor);
    }
    context.visitChildElements(visitor);
    return result;
  }
  
  // 判断字体家族
  static String _getFontFamily(String text) {
    final isChinese = RegExp(r'[\u4e00-\u9fa5]').hasMatch(text);
    if (isChinese) return 'NotoSansSC';
    return 'OpenSans';
  }
  
  // 构建完整内容的Widget，不含滚动限制
  static Widget _buildFullContentWidget(BuildContext context, AffirmationCard card, String? backgroundImagePath) {
    final theme = Theme.of(context);
    // 使用ConstrainedBox确保Widget有足够的高度而不会溢出
    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: MediaQuery.of(context).size.width,
        // 移除垂直方向的固定padding，改用内部控制
        padding: const EdgeInsets.symmetric(
          horizontal: 32,
        ),
        decoration: backgroundImagePath != null
            ? BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(28),
          image: DecorationImage(
            image: FileImage(File(backgroundImagePath)),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              theme.colorScheme.background.withOpacity(0.1),
              BlendMode.srcATop,
            ),
          ),
        )
            : BoxDecoration(
                color: theme.colorScheme.primaryContainer,
              ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          // 改为MainAxisSize.max以使容器占据所有可用空间
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 80), // 顶部padding
            Text(
              card.affirmation,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontFamily: _getFontFamily(card.affirmation),
                fontWeight: FontWeight.w600,
                fontSize: card.fontSize ?? 44,
                height: 1.6,
                color: backgroundImagePath != null
                    ? Colors.white
                    : theme.colorScheme.onPrimaryContainer,
                shadows: [
                  Shadow(
                    color: Colors.black.withOpacity(0.25),
                    offset: const Offset(0, 2),
                    blurRadius: 8,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 64),
            ShareOverlay(),
            const SizedBox(height: 80), // 底部padding
          ],
        ),
      ),
    );
  }
}
