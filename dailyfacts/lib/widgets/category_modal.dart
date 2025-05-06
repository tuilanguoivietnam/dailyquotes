import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/category_provider.dart';
import '../providers/selected_category_provider.dart';
import '../providers/subscription_provider.dart';
import '../models/category.dart';
import '../providers/affirmation_list_provider.dart';

class CategoryModal extends ConsumerWidget {
  const CategoryModal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categoriesState = ref.watch(categoryProvider);
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final lang = context.locale.languageCode;
    final allCategoryName = 'home.category_all'.tr();
    final allCategory = Category(id: 'all', name: {lang: allCategoryName});

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'home.categories'.tr(),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              categoriesState.when(
                data: (categories) {
                  final filteredCategories = categories.where((c) {
                    final n = c.name[lang] ?? c.name['zh'] ?? '';
                    return n != allCategoryName;
                  }).toList();
                  final categoriesList = [allCategory, ...filteredCategories];
                  return Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.6,
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: categoriesList.asMap().entries.map((entry) {
                          final index = entry.key;
                          final category = entry.value;
                          final categoryName = category.name[lang] ??
                              category.name['zh'] ??
                              '未命名分类';
                          final isSelected = categoryName == selectedCategory;
                          final isSubscribed = ref.watch(subscriptionProvider);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (categoryName == selectedCategory) {
                                    Navigator.pop(context);
                                    return;
                                  }
                                  if (index > 4 && !isSubscribed) {
                                    Navigator.pushNamed(
                                        context, '/subscription');
                                    return;
                                  }
                                  ref
                                      .read(selectedCategoryProvider.notifier)
                                      .setCategory(
                                          categoryName == allCategoryName
                                              ? allCategoryName
                                              : categoryName);
                                  final lang = context.locale.languageCode;
                                  ref
                                      .read(affirmationListProvider.notifier)
                                      .loadInitial(
                                        categoryName == allCategoryName
                                            ? null
                                            : categoryName,
                                        lang,
                                      );
                                  Navigator.pop(context);
                                },
                                borderRadius: BorderRadius.circular(20),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 18),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                            .withOpacity(0.12)
                                        : theme.colorScheme.surfaceVariant
                                            .withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outline
                                              .withOpacity(0.2),
                                      width: 1.5,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                              color: theme.colorScheme.primary
                                                  .withOpacity(0.08),
                                              blurRadius: 12,
                                              offset: const Offset(0, 2),
                                            ),
                                          ]
                                        : [],
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isSelected
                                            ? Icons.check_circle
                                            : Icons.circle_outlined,
                                        color: isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface
                                                .withOpacity(0.5),
                                      ),
                                      const SizedBox(width: 16),
                                      if (!isSubscribed && index > 4) ...[
                                        Icon(
                                          Icons.lock_outline_rounded,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 16),
                                      ],
                                      Expanded(
                                        child: Text(
                                          categoryName,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: isSelected
                                                ? theme.colorScheme.primary
                                                : theme.colorScheme.onSurface,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'home.category_load_failed'.tr(),
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'home.load_failed_message'.tr(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            final lang = context.locale.languageCode;
                            ref
                                .read(categoryProvider.notifier)
                                .loadCategories(lang);
                          },
                          icon: const Icon(Icons.refresh_rounded),
                          label: Text('home.retry'.tr()),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
