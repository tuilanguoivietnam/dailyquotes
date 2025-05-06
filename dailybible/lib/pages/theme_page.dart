import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart';
import '../providers/color_scheme_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/background_image_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';

class ThemePage extends ConsumerStatefulWidget {
  const ThemePage({Key? key}) : super(key: key);

  @override
  ConsumerState<ThemePage> createState() => _ThemePageState();
}

class _ThemePageState extends ConsumerState<ThemePage> {
  late bool isDark;

  @override
  void initState() {
    super.initState();
    isDark = ref.read(themeProvider) == ThemeMode.dark;
  }

  @override
  void dispose() {
    SystemChrome.setSystemUIOverlayStyle(
        isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark
    );
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final currentScheme = ref.watch(colorSchemeProvider);
    final themeMode = ref.watch(themeProvider);
    final theme = Theme.of(context);
    final brightness = MediaQuery.of(context).platformBrightness;
    final backgroundImage = ref.watch(backgroundImageProvider);

    // 从设备相册选择图片并复制到应用目录
    Future<void> _pickImage() async {
      try {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
        );

        if (pickedFile != null) {
          // 获取应用文档目录
          final appDir = await getApplicationDocumentsDirectory();
          final savedDir = Directory('${appDir.path}/background_images');

          // 确保目录存在
          if (!await savedDir.exists()) {
            await savedDir.create(recursive: true);
          }

          // 生成新的文件名
          final fileName =
              'background_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final savedPath = path.join(savedDir.path, fileName);

          // 复制文件到应用目录
          final File tempFile = File(pickedFile.path);
          if (await tempFile.exists()) {
            final savedFile = await tempFile.copy(savedPath);

            // 保存持久化路径
            ref
                .read(backgroundImageProvider.notifier)
                .setBackgroundImage(savedFile.path);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('theme.image_set_success'.tr())),
            );
          } else {
            throw Exception('Temporary file does not exist');
          }
        }
      } catch (e) {
        print('Error setting background image: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('theme.image_set_error'.tr())),
        );
      }
    }

    // 移除背景图片
    void _removeBackgroundImage() {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('theme.remove_image'.tr()),
          content: Text('theme.remove_image_confirm'.tr()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('common.cancel'.tr()),
            ),
            TextButton(
              onPressed: () async {
                // 删除文件
                if (backgroundImage != null) {
                  try {
                    final file = File(backgroundImage);
                    if (await file.exists()) {
                      await file.delete();
                    }
                  } catch (e) {
                    print('Error deleting background image: $e');
                  }
                }

                ref
                    .read(backgroundImageProvider.notifier)
                    .removeBackgroundImage();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('theme.image_removed'.tr())),
                );
              },
              child: Text('common.confirm'.tr()),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'theme.title'.tr(),
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.background,
              theme.colorScheme.primaryContainer,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          children: [
            ListTile(
              title: Text('theme.dark_mode'.tr()),
              trailing: Switch(
                value: themeMode == ThemeMode.dark ||
                    (themeMode == ThemeMode.system &&
                        brightness == Brightness.dark),
                onChanged: (value) {
                  ref.read(themeProvider.notifier).toggleTheme();
                  setState(() {
                    isDark = value;
                  });
                },
              ),
            ),
            const Divider(),
            // 背景图片设置
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'theme.background_image'.tr(),
                style: theme.textTheme.titleMedium,
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: theme.colorScheme.surface,
                  border: Border.all(
                      color: theme.colorScheme.outline.withOpacity(0.5)),
                ),
                child: backgroundImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(backgroundImage),
                              fit: BoxFit.cover,
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: _removeBackgroundImage,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_outlined,
                              size: 32,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'theme.no_image'.tr(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('theme.choose_image'.tr()),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'theme.color'.tr(),
                style: theme.textTheme.titleMedium,
              ),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: FlexScheme.values.length,
              itemBuilder: (context, index) {
                final scheme = FlexScheme.values[index];
                final isSelected = scheme == currentScheme;
                final schemeData = FlexThemeData.light(scheme: scheme);

                return InkWell(
                  onTap: () {
                    ref
                        .read(colorSchemeProvider.notifier)
                        .setColorScheme(scheme);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    decoration: BoxDecoration(
                      color: themeMode == ThemeMode.dark
                          ? FlexThemeData.dark(scheme: scheme).primaryColor
                          : schemeData.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: AnimatedOpacity(
                        opacity: isSelected ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.check,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
