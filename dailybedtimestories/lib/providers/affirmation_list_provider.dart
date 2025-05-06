import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dailystory/services/storage_service.dart';
import 'package:dailystory/services/api_service.dart';
import 'package:dailystory/models/affirmation.dart';

import '../services/notification_service.dart';

class AffirmationListNotifier extends StateNotifier<AsyncValue<List<String>>> {
  final ApiService _apiService;
  List<String> _localAffirmations = [];
  String? _notificationAffirmation;
  bool noNetworkRequested = true;

  AffirmationListNotifier(this._apiService)
      : super(const AsyncValue.loading()) {
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    try {
      final localData = await StorageService.getAffirmations();
      await NotificationService.instance.getNotificationAppLaunchDetails();
      _notificationAffirmation = NotificationService.instance.notificationAffirmation;
      if (localData != null && localData.isNotEmpty) {
        _localAffirmations = localData.map((a) => a.message).toList();
        _localAffirmations.shuffle(); // 打乱顺序
      }
      if (_notificationAffirmation!= null) {
        _localAffirmations.insert(0, _notificationAffirmation!);
      }
      if (_localAffirmations.isNotEmpty) {
        state = AsyncValue.data(_localAffirmations);
      }
    } catch (e) {
      print('Error loading local data: $e');
    }
  }

  Future<void> loadInitial(String? category, String lang,
      {bool useCache = false, bool append = false}) async {
    try {
      _notificationAffirmation = NotificationService.instance.notificationAffirmation;
      if (useCache) {
        // 如果使用缓存，直接返回本地数据
        if (_localAffirmations.isNotEmpty) {
          final List<String> combinedData = [];

          // 确保通知金句总是在第一位
          if (_notificationAffirmation != null) {
            combinedData.add(_notificationAffirmation!);

            // 从本地数据中移除通知金句，避免重复
            final localWithoutNotification = _localAffirmations
                .where((item) => item != _notificationAffirmation)
                .toList();
            combinedData.addAll(localWithoutNotification);
          } else {
            combinedData.addAll(_localAffirmations);
          }

          if (append && state.value != null) {
            // 确保不重复添加已有数据
            final existingItems = state.value!.toSet();
            final newItems = combinedData
                .where((item) => !existingItems.contains(item))
                .toList();
            state = AsyncValue.data([...state.value!, ...newItems]);
          } else {
            state = AsyncValue.data(combinedData);
          }
        }
        return;
      }

      // 只显示 loading，不先显示本地数据，避免闪烁
      if(!noNetworkRequested) state = const AsyncValue.loading();

      // 加载网络数据
      final networkData = await _apiService.getAffirmations(category, lang);

      // 合并数据，确保通知金句在最前面
      final List<String> combinedData = [];
      if (_notificationAffirmation != null) {
        combinedData.add(_notificationAffirmation!);

        // 移除网络数据中与通知金句重复的项
        final networkWithoutNotification = networkData
            .where((item) => item != _notificationAffirmation)
            .toList();
        combinedData.addAll(networkWithoutNotification);
      } else {
        combinedData.addAll(networkData);
      }

      if (noNetworkRequested && _localAffirmations.isNotEmpty && combinedData.isNotEmpty){
        final List<String> combinedLocalAndServerData = [];
        final localWithoutNotification = _localAffirmations
            .where((item) => item != _notificationAffirmation)
            .toList();
        if (_notificationAffirmation == null){
          combinedLocalAndServerData.add(localWithoutNotification[0]);
        }
        combinedLocalAndServerData.addAll(combinedData);
        state = AsyncValue.data(combinedLocalAndServerData);
      }else{
        // 更新状态
        state = AsyncValue.data(combinedData);
      }

      noNetworkRequested = false;

      // 保存到本地
      final affirmations = combinedData
          .asMap()
          .entries
          .map((e) => Affirmation(
                id: e.key.toString(),
                message: e.value,
                category: category ?? '',
                createdAt: DateTime.now(),
              ))
          .toList();
      await StorageService.saveAffirmations(affirmations);
      _localAffirmations = combinedData;
    } catch (e) {
      print('网络加载失败: $e');
      // 网络加载失败，尝试加载本地数据并 append 到后面
      if (_localAffirmations.isNotEmpty) {
        final List<String> combinedData = [];

        // 确保通知金句总是在第一位
        if (_notificationAffirmation != null) {
          combinedData.add(_notificationAffirmation!);

          // 从本地数据中移除通知金句，避免重复
          final localWithoutNotification = _localAffirmations
              .where((item) => item != _notificationAffirmation)
              .toList();
          combinedData.addAll(localWithoutNotification);
        } else {
          combinedData.addAll(_localAffirmations);
        }

        if (append && state.value != null) {
          // 确保不重复添加已有数据
          final existingItems = state.value!.toSet();
          final newItems = combinedData
              .where((item) => !existingItems.contains(item))
              .toList();
          state = AsyncValue.data([...state.value!, ...newItems]);
        } else {
          state = AsyncValue.data(combinedData);
        }
      } else {
        state = AsyncValue.error(e, StackTrace.current);
      }
    }
    NotificationService.instance.clearNotificationAffirmation();
  }

  void addNotificationAffirmation(String affirmation) {
    print('添加通知金句: $affirmation');
    _notificationAffirmation = affirmation;

    if (state.hasValue) {
      final currentList = state.value!;
      // 创建新列表，确保通知金句在第一位
      final List<String> newList = [];

      // 添加通知金句到第一位
      newList.add(affirmation);

      // 添加其他金句，排除通知金句
      newList.addAll(currentList.where((item) => item != affirmation));

      state = AsyncValue.data(newList);
      _localAffirmations = newList;

      // 保存到本地
      final affirmations = newList
          .asMap()
          .entries
          .map((e) => Affirmation(
                id: e.key.toString(),
                message: e.value,
                category: '',
                createdAt: DateTime.now(),
              ))
          .toList();
      StorageService.saveAffirmations(affirmations);
    } else {
      // 如果当前没有加载数据，直接创建包含通知金句的列表
      state = AsyncValue.data([affirmation]);
      _localAffirmations = [affirmation];

      // 保存到本地
      final affirmations = [
        Affirmation(
          id: '0',
          message: affirmation,
          category: '',
          createdAt: DateTime.now(),
        )
      ];
      StorageService.saveAffirmations(affirmations);
    }
    NotificationService.instance.clearNotificationAffirmation();
  }

  Future<void> loadMore(String lang) async {
    if (state.isLoading) return;

    try {
      final currentList = state.value ?? [];
      final moreData =
          await _apiService.getMoreAffirmations(currentList.length, lang);
      if (moreData.isNotEmpty) {
        // 确保没有重复项
        final existingItems = currentList.toSet();
        final newItems =
            moreData.where((item) => !existingItems.contains(item)).toList();

        if (newItems.isNotEmpty) {
          final newList = [...currentList, ...newItems];
          state = AsyncValue.data(newList);
          _localAffirmations = newList;

          // 保存到本地
          final affirmations = newList
              .asMap()
              .entries
              .map((e) => Affirmation(
                    id: e.key.toString(),
                    message: e.value,
                    category: '',
                    createdAt: DateTime.now(),
                  ))
              .toList();
          await StorageService.saveAffirmations(affirmations);
        }
      }
    } catch (e) {
      print('加载更多数据失败: $e');
    }
  }
}

final affirmationListProvider =
    StateNotifierProvider<AffirmationListNotifier, AsyncValue<List<String>>>(
        (ref) {
  return AffirmationListNotifier(ref.watch(apiServiceProvider));
});
