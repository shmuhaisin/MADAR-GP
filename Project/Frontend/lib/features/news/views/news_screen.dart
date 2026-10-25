// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:madar_app/features/news/viewModels/news_view_model.dart';
import 'package:madar_app/features/news/views/article_detail_screen.dart';
import 'package:madar_app/features/news/widgets/category_chip.dart';
import 'package:madar_app/features/news/widgets/news_card.dart';
import 'package:provider/provider.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../../../common_theme/ui/navy_header_clip.dart';
import 'package:madar_app/features/profile/viewmodel/profile_viewmodel.dart';
import 'package:madar_app/features/news/widgets/news_pagination.dart';

class NewsScreen extends StatefulWidget {
  final String? successMessage;

  const NewsScreen({
    super.key,
    this.successMessage,
  });

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> with WidgetsBindingObserver {
  bool _didFirstLoad = false;
  bool _wasOffline = false;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final msg = widget.successMessage;

      if (msg == null || msg.trim().isEmpty) return;

      _showSuccessBanner(msg);
    });

    _startConnectivityListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _connectivitySub?.cancel();
    _connectivitySub = null;

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.resumed) {
      _loadUserNewsContext(
        context,
        showSuccessWhenChanged: false,
        preserveSelectedCategory: true,
      );
    }
  }

  void _startConnectivityListener() {
    _connectivitySub?.cancel();

    _connectivitySub = Connectivity().onConnectivityChanged.listen(
      (_) async {
        if (!mounted) return;

        final online = await _hasInternetConnection();

        if (!online) {
          _wasOffline = true;
          return;
        }

        if (_wasOffline) {
          _wasOffline = false;

          await _loadUserNewsContext(
            context,
            showSuccessWhenChanged: true,
            preserveSelectedCategory: true,
          );
        }
      },
    );
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

  Future<void> _loadUserNewsContext(
    BuildContext context, {
    bool showSuccessWhenChanged = false,
    bool preserveSelectedCategory = true,
  }) async {
    final profileVm = context.read<ProfileViewModel>();
    final newsVm = context.read<NewsViewModel>();

    if (newsVm.loading || newsVm.loadingMore) return;

    final oldArticlesCount = newsVm.articles.length;

    String? previousCategoryValue;

    if (preserveSelectedCategory &&
        newsVm.categories.isNotEmpty &&
        newsVm.selectedCategoryIndex >= 0 &&
        newsVm.selectedCategoryIndex < newsVm.categories.length) {
      previousCategoryValue =
          newsVm.categories[newsVm.selectedCategoryIndex]['value']?.toString();
    }

    await profileVm.loadProfile();

    if (!mounted) return;

    final profile = profileVm.profile;
    final interests = profile?.interests ?? const [];

    final userCacheKey = profile?.email ?? profile?.phoneNumber ?? 'guest';

    newsVm.setCurrentUserKey(userCacheKey);
    newsVm.setUserInterests(interests);

    await newsVm.refresh();

    if (!mounted) return;

    if (preserveSelectedCategory && previousCategoryValue != null) {
      final restoreIndex = newsVm.categories.indexWhere(
        (category) => category['value']?.toString() == previousCategoryValue,
      );

      if (restoreIndex != -1 &&
          restoreIndex != newsVm.selectedCategoryIndex) {
        newsVm.setCategory(restoreIndex);
      }
    }

    final newArticlesCount = newsVm.articles.length;

    if (showSuccessWhenChanged && newArticlesCount != oldArticlesCount) {
      AppTopMessage.show(
        context,
        text: 'تم تحديث الأخبار',
        type: TopMsgType.success,
      );
    }
  }

  void _showSuccessBanner(String message) {
    if (!mounted) return;

    AppTopMessage.show(
      context,
      text: message,
      type: TopMsgType.success,
    );
  }

  Widget _offlineBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFC9C9),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 7),
            color: Colors.red.withOpacity(0.08),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFFFE3E3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.wifi_off_rounded,
              color: Color(0xFFE53935),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'NotoSansArabic',
                color: Color(0xFFC62828),
                fontSize: 12.8,
                fontWeight: FontWeight.w800,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _emptyNewsMessage(NewsViewModel vm) {
    if (vm.categories.isEmpty ||
        vm.selectedCategoryIndex < 0 ||
        vm.selectedCategoryIndex >= vm.categories.length) {
      return 'لا توجد أخبار حالياً';
    }

    final selectedValue = vm.categories[vm.selectedCategoryIndex]['value'];

    if (selectedValue == null) {
      return 'لا توجد أخبار حالياً';
    }

    return 'لا توجد أخبار لهذا الاهتمام حالياً';
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NewsViewModel>();

    if (!_didFirstLoad) {
      _didFirstLoad = true;

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;

        await _loadUserNewsContext(
          context,
          preserveSelectedCategory: true,
        );
      });
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.softBg,
        body: RefreshIndicator(
          onRefresh: () => _loadUserNewsContext(
            context,
            showSuccessWhenChanged: false,
            preserveSelectedCategory: true,
          ),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: MadarNavyHeaderClip(
                  headerHeight: 92,
                  overlap: 15,
                  sheetRadius: 28,
                  child: const SizedBox(
                    height: 92,
                    child: Stack(
                      children: [
                        Align(
                          alignment: Alignment.topCenter,
                          child: Padding(
                            padding: EdgeInsets.only(top: 18),
                            child: Text(
                              'الأخبار',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'NotoSansArabic',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              if (vm.isOffline)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: _offlineBanner(
                      'أنت غير متصل بالإنترنت. يتم عرض آخر أخبار محفوظة.',
                    ),
                  ),
                ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 12),

                    SizedBox(
                      height: 50,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: vm.categories.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final label =
                              (vm.categories[index]['label'] ?? '').toString();

                          return CategoryChip(
                            label: label,
                            isSelected: vm.selectedCategoryIndex == index,
                            onTap: () => vm.setCategory(index),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    if (vm.loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 200),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (vm.articles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 200),
                        child: Center(
                          child: Text(
                            _emptyNewsMessage(vm),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              color: AppColors.text.withOpacity(0.70),
                            ),
                          ),
                        ),
                      )
                    else ...[
                      ...vm.articles.map(
                        (article) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: NewsCard(
                            article: article,
                            onTap: () async {
                              final msg = await Navigator.push<String>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ArticleDetailScreen(
                                    article: article,
                                  ),
                                ),
                              );

                              if (!mounted) return;

                              if (msg != null && msg.trim().isNotEmpty) {
                                _showSuccessBanner(msg);
                              }
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      NewsPagination(
                        currentPage: vm.currentPage,
                        totalPages: vm.totalPages,
                        onPageSelected: (page) => vm.fetchPage(page),
                      ),
                    ],
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}