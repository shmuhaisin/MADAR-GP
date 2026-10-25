
// ignore_for_file: file_names

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'common_theme/ui/bottom_nav.dart';
import 'common_theme/ui/app_top_message.dart';

import 'features/news/views/news_screen.dart';
import 'features/news/viewModels/news_view_model.dart';

import 'features/shared_collections/views/explore_shared_collections_screen.dart';
import 'features/shared_collections/views/shared_collections_main_screen.dart';

import 'features/notifications/views/notifications_history_page.dart';
import 'features/notifications/viewmodel/notifications_history_vm.dart';
import 'features/notifications/viewmodel/semantic_notifications_vm.dart';

import 'features/profile/views/Profile_view.dart';
import 'features/profile/viewmodel/profile_viewmodel.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;

  static const int newsIndex = 0;
  static const int exploreIndex = 1;
  static const int collectionsIndex = 2;
  static const int notificationsIndex = 3;
  static const int profileIndex = 4;

  late final NewsViewModel _newsVM;

  final List<Widget> pages = const [
    NewsScreen(),
    ExploreScreen(),
    SharedCollectionScreen(),
    NotificationHistoryPage(),
    ProfileView(),
  ];

  @override
  void initState() {
    super.initState();

    _newsVM = NewsViewModel();

    Future.microtask(() async {
      if (!mounted) return;

      context.read<NotificationHistoryVM>().loadNotifications();
      context.read<SemanticNotificationsVM>().loadSemanticNotifications();

      final profileVM = context.read<ProfileViewModel>();

      if (profileVM.profile == null && !profileVM.loading) {
        await profileVM.loadProfile();
      }

      if (!mounted) return;

      await _refreshNewsContext();
    });
  }

  @override
  void dispose() {
    _newsVM.dispose();
    super.dispose();
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(seconds: 3),
      );

      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _refreshNewsContext() async {
    if (!mounted) return;

    if (_newsVM.loading || _newsVM.loadingMore) return;

    final profileVM = context.read<ProfileViewModel>();

    if (!profileVM.loading) {
      await profileVM.loadProfile();
    }

    if (!mounted) return;

    final profile = profileVM.profile;
    final interests = profile?.interests ?? const [];

    final userCacheKey = profile?.email ?? profile?.phoneNumber ?? 'guest';

    _newsVM.setCurrentUserKey(userCacheKey);
    _newsVM.setUserInterests(interests);

    await _newsVM.refresh();
  }

  void _handleNavTap(int newIndex) {
    _handleNavTapInternal(newIndex);
  }

  Future<void> _handleNavTapInternal(int newIndex) async {
    if (newIndex < 0 || newIndex >= pages.length) return;

    final profileVM = context.read<ProfileViewModel>();

    final leavingProfile = index == profileIndex && newIndex != profileIndex;

    if (leavingProfile && profileVM.isEditing) {
      profileVM.cancelEdit();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        AppTopMessage.show(
          context,
          text: 'تم إلغاء التعديلات',
          type: TopMsgType.info,
        );
      });
    }

    setState(() {
      index = newIndex;
    });

    if (newIndex == newsIndex) {
      await _refreshNewsContext();
    }

    if (newIndex == notificationsIndex) {
      context.read<NotificationHistoryVM>().loadNotifications();
      context.read<SemanticNotificationsVM>().loadSemanticNotifications();
    }

    if (newIndex == profileIndex) {
      final online = await _hasInternetConnection();

      if (!mounted) return;

      if (!online) {
        profileVM.applyApiError(
          'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة',
        );
      } else if (!profileVM.isEditing) {
        profileVM.clearErrors();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NewsViewModel>.value(
      value: _newsVM,
      child: Scaffold(
        body: IndexedStack(
          index: index,
          children: pages,
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: index,
          notificationsCount:
              context.watch<NotificationHistoryVM>().unreadCount,
          onTap: _handleNavTap,
        ),
      ),
    );
  }
}