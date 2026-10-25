// ignore_for_file: unnecessary_import

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_confirm_dialog.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../model/added_news_model.dart';
import '../model/collections_models.dart';
import '../viewmodel/explore_vm.dart';
import '../widgets/added_news.dart';
import '../widgets/owner_pill.dart';
import '../widgets/views_pill.dart';
import 'added_news_detail_screen.dart';

class ExploreCollectionDetailsScreen extends StatelessWidget {
  final ExploreCollectionUiModel collection;
  final Future<void> Function() onJoin;
  final VoidCallback onBack;

  const ExploreCollectionDetailsScreen({
    super.key,
    required this.collection,
    required this.onJoin,
    required this.onBack,
  });
bool _isOfflineApiMessage(String? message) {
  final m = (message ?? '').trim();

  return m.contains('غير متصل') ||
      m.contains('لا يوجد اتصال') ||
      m.contains('آخر بيانات محفوظة');
}

Widget _offlineBanner(String message) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFC9C9),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Color(0xFFE53935),
            size: 20,
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
    ),
  );
}
  String _cleanError(Object error) {
    final msg = error.toString().trim();
    final lower = msg.toLowerCase();

    if (msg.isEmpty) {
      return 'حدث خطأ أثناء تنفيذ العملية';
    }

    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        msg.contains('غير مصرح')) {
      return 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';
    }

    if (lower.contains('409') ||
        lower.contains('conflict') ||
        msg.contains('موجود') ||
        msg.contains('مسبق')) {
      return 'تم إرسال طلب الانضمام مسبقًا';
    }

    if (lower.contains('connection') ||
    lower.contains('network') ||
    lower.contains('socket') ||
    lower.contains('timeout') ||
    lower.contains('internet') ||
    lower.contains('failed host lookup') ||
    lower.contains('connection error') ||
    lower.contains('connection failed') ||
    lower.contains('connection refused') ||
    lower.contains('لا يوجد اتصال') ||
    lower.contains('غير متصل')) {
  return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';
}

    if (lower.contains('404') ||
        lower.contains('not found') ||
        msg.contains('غير موجود')) {
      return 'لم يتم العثور على المجموعة';
    }

    if (lower.contains('500') || lower.contains('internal server')) {
      return 'حدث خطأ في الخادم، حاول مرة أخرى لاحقًا';
    }

    if (msg.startsWith('Exception:')) {
      return msg.replaceFirst('Exception:', '').trim();
    }

    if (msg.startsWith('HTTP')) {
      return 'حدث خطأ أثناء تنفيذ العملية';
    }

    return msg;
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

  Future<void> _handleJoinRequest({
    required BuildContext context,
    required String collectionName,
    required Future<void> Function() onJoin,
  }) async {
    final online = await _hasInternetConnection();

    if (!context.mounted) return;

    if (!online) {
      AppTopMessage.show(
        context,
        text: 'لا يمكن إرسال طلب الانضمام بدون إنترنت',
        type: TopMsgType.error,
      );
      return;
    }

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'طلب الانضمام',
      message: 'هل تريد إرسال طلب انضمام إلى "$collectionName"؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );

    if (!confirmed || !context.mounted) return;

    try {
      await onJoin();

      if (!context.mounted) return;

      AppTopMessage.show(
        context,
        text: 'تم إرسال طلب الانضمام بنجاح',
        type: TopMsgType.success,
      );
    } catch (e) {
      if (!context.mounted) return;

      AppTopMessage.show(
        context,
        text: _cleanError(e),
        type: TopMsgType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final exploreVm = context.watch<ExploreViewModel>();

    final latest = exploreVm.collections.firstWhere(
      (c) => c.id == collection.id,
      orElse: () => collection,
    );

    final status = latest.joinStatus.trim().toLowerCase();
    final isPending = status == 'pending';

    final joinCfg = isPending
        ? const _JoinCfg(
            label: 'تم الطلب',
            icon: Icons.hourglass_top_rounded,
            bg: Color(0xFFF4A322),
          )
        : const _JoinCfg(
            label: 'طلب الانضمام',
            icon: Icons.person_add_alt_1,
            bg: Color(0xFF1AA37A),
          );

    final canJoin = !isPending;

    final media = MediaQuery.of(context);
    final topInset = media.padding.top;

    const double sheetH = 65.0;
    const double sheetRadius = 34.0;

    const double joinBtnH = 40.0;
    const double gapButtonToSheet = 16.0;

    final double collapsedH = sheetH + topInset;
    final double expandedH = 360.0 + topInset;

    final double reservedBottom = sheetH + gapButtonToSheet + joinBtnH + 14.0;

    const double gap = 18.0;

    const exploreGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF5E80C2), // atmospheric blue
      Color(0xFF4262AC), // royal blue
      Color(0xFF2A4282), // navy presence
      Color(0xFF553568), // rich amethyst
      Color(0xFF8B3258), // wine
      Color(0xFFB23E5C), // rosy burgundy
    ],
    stops: [0.0, 0.18, 0.40, 0.60, 0.80, 1.0],
  );

    return Directionality(
      textDirection: TextDirection.rtl,
   child: ChangeNotifierProvider(
  create: (_) => ExploreCollectionDetailsViewModel(
    collectionId: collection.id,
    initialCollection: collection,
  ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: Consumer<ExploreCollectionDetailsViewModel>(
            builder: (context, vm, _) {

              final title = vm.collection.collectionName.trim().isNotEmpty
                  ? vm.collection.collectionName
                  : latest.collectionName;

              final desc = vm.collection.collectionDescription.trim().isNotEmpty
                  ? vm.collection.collectionDescription.trim()
                  : latest.collectionDescription.trim();

              final owner = vm.collection.ownerUsername.trim().isNotEmpty
                  ? vm.collection.ownerUsername.trim()
                  : (latest.ownerUsername ?? '').trim();

              final views = vm.collection.id.isNotEmpty
                  ? vm.collection.numOfViewers
                  : (latest.numOfViewers ?? 0);

                  final apiError = vm.apiError;

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: false,
                    floating: false,
                    snap: false,
                    automaticallyImplyLeading: false,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    toolbarHeight: 0,
                    collapsedHeight: collapsedH,
                    expandedHeight: expandedH,
                    flexibleSpace: LayoutBuilder(
                      builder: (context, constraints) {
                        final maxH = constraints.maxHeight;

                        final t =
                            ((maxH - collapsedH) / (expandedH - collapsedH))
                                .clamp(0.0, 1.0);

                        final eased = Curves.easeOutCubic.transform(t);

                        final headerOpacity = eased;
                        final slideY = (1.0 - eased) * -0.12;

                        return ClipRect(
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                decoration: const BoxDecoration(
                                  gradient: exploreGradient,
                                ),
                              ),
                              DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.10),
                                      Colors.black.withOpacity(0.18),
                                      Colors.black.withOpacity(0.32),
                                    ],
                                    stops: const [0.0, 0.55, 1.0],
                                  ),
                                ),
                              ),
                              SafeArea(
                                bottom: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ).copyWith(top: 14),
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: Opacity(
                                      opacity: headerOpacity,
                                      child: IgnorePointer(
                                        ignoring: headerOpacity < 0.05,
                                        child: _TopIconButton(
                                          icon: Icons.arrow_forward_ios_rounded,
                                          onTap: onBack,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                bottom: reservedBottom,
                                child: SafeArea(
                                  bottom: false,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      84,
                                      16,
                                      0,
                                    ),
                                    child: Opacity(
                                      opacity: headerOpacity,
                                      child: IgnorePointer(
                                        ignoring: headerOpacity < 0.05,
                                        child: FractionalTranslation(
                                          translation: Offset(0, slideY),
                                          child: ClipRect(
                                            child: Align(
                                              alignment: Alignment.topRight,
                                              child: SingleChildScrollView(
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const SizedBox(height: 18),
                                                    Container(
                                                      width: double.infinity,
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: Text(
                                                        title,
                                                        textAlign:
                                                            TextAlign.right,
                                                        maxLines: 3,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: const TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 20,
                                                          fontWeight:
                                                              FontWeight.w900,
                                                          fontFamily:
                                                              'NotoSansArabic',
                                                          height: 1.08,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: gap),
                                                    Container(
                                                      width: double.infinity,
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: Text(
                                                        desc,
                                                        textAlign:
                                                            TextAlign.right,
                                                        maxLines: 4,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          color: Colors.white
                                                              .withOpacity(
                                                            0.92,
                                                          ),
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontFamily:
                                                              'NotoSansArabic',
                                                          height: 1.18,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 12),
                                                    Container(
                                                      width: double.infinity,
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          OwnerPill.glass(
                                                            owner: owner,
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          ViewsPill(
                                                            views: views,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 16,
                                right: 16,
                                bottom: sheetH + gapButtonToSheet,
                                child: Opacity(
                                  opacity: headerOpacity,
                                  child: IgnorePointer(
                                    ignoring: headerOpacity < 0.05,
                                    child: FractionalTranslation(
                                      translation: Offset(0, slideY),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: _FollowButton(
                                          label: joinCfg.label,
                                          icon: joinCfg.icon,
                                          bg: joinCfg.bg,
                                        onTap: canJoin
                                            ? () => _handleJoinRequest(
                                                  context: context,
                                                  collectionName: title,
                                                  onJoin: onJoin,
                                                )
                                            : null,
                                          disabledBg: joinCfg.bg,
                                          disabledFg: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Align(
                                alignment: Alignment.bottomCenter,
                                child: Container(
                                  height: sheetH,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(sheetRadius),
                                      topRight: Radius.circular(sheetRadius),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 22,
                                        offset: const Offset(0, -6),
                                        color: Colors.black.withOpacity(0.06),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      16,
                                      10,
                                      20,
                                      8,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        const SizedBox(height: 8),
                                        const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Icon(
                                              Icons.feed_rounded,
                                              size: 22,
                                              color: AppColors.navy,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'الأخبار المضافة',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: AppColors.navy,
                                                fontFamily: 'NotoSansArabic',
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Container(
                                          height: 1,
                                          color:
                                              AppColors.navy.withOpacity(0.08),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (apiError != null && _isOfflineApiMessage(apiError))
                    SliverToBoxAdapter(
                      child: _offlineBanner(apiError),
                    ),
if (vm.error != null && (vm.error ?? '').trim().isNotEmpty)
  SliverFillRemaining(
    hasScrollBody: false,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          _cleanError(vm.error!),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.danger,
            fontFamily: 'NotoSansArabic',
            fontWeight: FontWeight.w800,
            height: 1.5,
          ),
        ),
      ),
    ),
  )
else if (vm.isLoading)                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 18),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    )
                  else if (vm.news.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 40),
                        child: Center(
                          child: Text(
                            'لم تتم إضافة أي أخبار بعد',
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontWeight: FontWeight.w800,
                              fontSize: 19,
                              color: AppColors.text.withOpacity(0.70),
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) {
                            final AddedNewsModel n = vm.news[i];

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: AddedNewsCard(
                                item: n,
                                ownerHandle: '',
                                ownerPillGradient: exploreGradient,
                                isOwnedScreen: false,
                                onView: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => AddedNewsDetailsScreen(
                                        addedNews: n,
                                        collectionId: collection.id,
                                        isOwnedScreen: false,
                                        isExploreScreen: true,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          childCount: vm.news.length,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _JoinCfg {
  final String label;
  final IconData icon;
  final Color bg;

  const _JoinCfg({
    required this.label,
    required this.icon,
    required this.bg,
  });
}

class _TopIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _TopIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.16),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Center(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _FollowButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final VoidCallback? onTap;

  final Color? disabledBg;
  final Color? disabledFg;

  const _FollowButton({
    required this.label,
    required this.icon,
    required this.bg,
    required this.onTap,
    this.disabledBg,
    this.disabledFg,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            fontFamily: 'NotoSansArabic',
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          disabledBackgroundColor: disabledBg ?? bg,
          disabledForegroundColor: disabledFg ?? Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: Colors.white.withOpacity(0.55),
              width: 0.66,
            ),
          ),
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.28),
        ),
      ),
    );
  }
}