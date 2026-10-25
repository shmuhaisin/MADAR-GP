// owned_collections_details_screen.dart

import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_confirm_dialog.dart';
import '../../../common_theme/ui/app_top_message.dart';

import '../views/reports_screen.dart';
import '../views/join_requests_screen.dart';
import './memebers_screen.dart';
import '../viewmodel/shared_collections_details_vm.dart';
import '../viewmodel/shared_collections_main_vm.dart';
import '../widgets/added_news.dart';
import '../widgets/owner_pill.dart';
import '../widgets/views_pill.dart';
import '../model/added_news_model.dart';
import '../model/member_model.dart';
import 'added_news_detail_screen.dart';
import 'archived_news_screen.dart';

class OwnedDetailsScreen extends StatefulWidget {
  final String collectionId;
  final String? focusNewsId;
  final bool openEditDirectly;

  const OwnedDetailsScreen({
    super.key,
    required this.collectionId,
    this.focusNewsId,
    this.openEditDirectly = false,
  });

  @override
  State<OwnedDetailsScreen> createState() => _OwnedDetailsScreenState();
}

class _OwnedDetailsScreenState extends State<OwnedDetailsScreen>
    with WidgetsBindingObserver {
  final ItemScrollController _itemScrollController = ItemScrollController();

  static const String _offlineCacheMessage =
      'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';

  String? _highlightId;
  bool _didAutoFocus = false;
  bool _didOpenDirectEdit = false;

  StreamSubscription<dynamic>? _connectivitySub;
  Timer? _internetVerifyTimer;

  bool _showOfflineCacheWarning = false;
  bool _checkingConnection = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Future.microtask(() async {
      if (!mounted) return;
      await _refreshConnectionState(reloadWhenOnline: false);
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      unawaited(_handleConnectivityChanged(result));
    });

    _internetVerifyTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      unawaited(_refreshConnectionState(reloadWhenOnline: false));
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _internetVerifyTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_refreshConnectionState(reloadWhenOnline: true));
  }

  void _setOfflineWarning(bool value) {
    if (!mounted || _showOfflineCacheWarning == value) return;

    setState(() {
      _showOfflineCacheWarning = value;
    });
  }

  dynamic _fallbackOwnedCollectionFromMainCache(BuildContext context) {
    try {
      final mainVm = context.read<SharedCollectionsViewModel>();

      for (final dynamic item in mainVm.ownedCollections) {
        if ((item.id ?? '').toString() == widget.collectionId) {
          return item;
        }
      }
    } catch (_) {
      // The main collections provider may not exist when this screen is opened
      // directly. In that case, use the details ViewModel only.
    }

    return null;
  }

  bool _isConnectivityNone(dynamic result) {
    if (result is ConnectivityResult) {
      return result == ConnectivityResult.none;
    }

    if (result is List<ConnectivityResult>) {
      return result.isEmpty ||
          result.every((item) => item == ConnectivityResult.none);
    }

    return false;
  }

  Future<void> _handleConnectivityChanged(dynamic result) async {
    if (_isConnectivityNone(result)) {
      _setOfflineWarning(true);
      return;
    }

    await _refreshConnectionState(reloadWhenOnline: true);
  }

  Future<void> _refreshConnectionState({
    required bool reloadWhenOnline,
  }) async {
    if (_checkingConnection) return;

    _checkingConnection = true;

    try {
      final dynamic connectivity = await Connectivity().checkConnectivity();

      if (!mounted) return;

      if (_isConnectivityNone(connectivity)) {
        _setOfflineWarning(true);
        return;
      }

      final online = await _hasInternetConnection();

      if (!mounted) return;

      if (!online) {
        _setOfflineWarning(true);
        return;
      }

      _setOfflineWarning(false);

      if (reloadWhenOnline) {
        final vm = context.read<OwnedCollectionDetailsViewModel>();
        await vm.loadDetails();

        if (!mounted) return;
        _setOfflineWarning(false);
      }
    } finally {
      _checkingConnection = false;
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com').timeout(
        const Duration(milliseconds: 900),
      );

      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _isOfflineLikeError(Object? error) {
    final msg = (error ?? '').toString().trim();
    final lower = msg.toLowerCase();

    return lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout') ||
        lower.contains('internet') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection error') ||
        lower.contains('connection failed') ||
        lower.contains('connection refused') ||
        msg.contains('لا يوجد اتصال') ||
        msg.contains('غير متصل') ||
        msg.contains('بدون إنترنت') ||
        msg.contains('آخر بيانات محفوظة');
  }

  Future<bool> _ensureOnlineForAction(String message) async {
    await _refreshConnectionState(reloadWhenOnline: false);

    if (!mounted) return false;

    if (_showOfflineCacheWarning) {
      AppTopMessage.show(
        context,
        text: message,
        type: TopMsgType.error,
      );
      return false;
    }

    return true;
  }

  bool _isOfflineApiMessage(String? message) {
  final m = (message ?? '').trim();

  return m.contains('غير متصل') ||
      m.contains('لا يوجد اتصال') ||
      m.contains('آخر بيانات محفوظة');
}

Widget _offlineBanner(String message) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
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
        boxShadow: [
          BoxShadow(
            blurRadius: 14,
            offset: const Offset(0, 7),
            color: Colors.red.withOpacity(0.08),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
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
    ),
  );
}

  String _cleanError(Object? error) {
    final msg = (error ?? '').toString().trim();
    final lower = msg.toLowerCase();

    if (msg.isEmpty) return 'حدث خطأ أثناء تنفيذ العملية';

    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        msg.contains('غير مصرح')) {
      return 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';
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
    msg.contains('لا يوجد اتصال') ||
    msg.contains('غير متصل')) {
  return 'لا يوجد اتصال بالإنترنت على هذا الجهاز';
}
    if (lower.contains('404') ||
        lower.contains('not found') ||
        msg.contains('غير موجود')) {
      return 'لم يتم العثور على البيانات المطلوبة';
    }

    if (lower.contains('409') ||
        lower.contains('conflict') ||
        msg.contains('موجود') ||
        msg.contains('مسبق')) {
      return 'تم تنفيذ هذه العملية مسبقًا';
    }

    if (lower.contains('500') || lower.contains('internal server')) {
      return 'حدث خطأ في الخادم، حاول مرة أخرى لاحقًا';
    }

    if (msg.startsWith('Exception:')) {
      final clean = msg.replaceFirst('Exception:', '').trim();
      return clean.isEmpty ? 'حدث خطأ أثناء تنفيذ العملية' : clean;
    }

    if (msg.startsWith('HTTP')) return 'حدث خطأ أثناء تنفيذ العملية';

    return msg;
  }

  void _showSuccess(String text) {
    if (!mounted) return;

    AppTopMessage.show(
      context,
      text: text,
      type: TopMsgType.success,
    );
  }

  void _showError(Object error) {
    if (!mounted) return;

    if (_isOfflineLikeError(error)) {
      _setOfflineWarning(true);
      return;
    }

    AppTopMessage.show(
      context,
      text: _cleanError(error),
      type: TopMsgType.error,
    );
  }

  Future<void> _afterSheetClosed(Future<void> Function() action) async {
    await Future.delayed(const Duration(milliseconds: 160));

    if (!mounted) return;

    await action();
  }

  void _tryAutoFocus(OwnedCollectionDetailsViewModel vm) {
    if (_didAutoFocus) return;

    final id = widget.focusNewsId?.trim();
    if (id == null || id.isEmpty) return;

    if (vm.isLoading) return;
    if (vm.news.isEmpty) return;

    _didAutoFocus = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToNews(id);
    });
  }

  void _tryOpenDirectEdit(OwnedCollectionDetailsViewModel vm) {
    if (_didOpenDirectEdit) return;
    if (!widget.openEditDirectly) return;
    if (vm.isLoading) return;
    if (vm.ownedCollection.id.trim().isEmpty) return;

    _didOpenDirectEdit = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 180));

      if (!mounted) return;

      final online = await _ensureOnlineForAction(
        'لا يمكن تعديل المجموعة بدون إنترنت',
      );

      if (!online || !mounted) return;

      _showEditDialog(context, vm);
    });
  }


  Future<void> _scrollToNews(String newsId) async {
    if (!mounted) return;

    final vm = context.read<OwnedCollectionDetailsViewModel>();

    int guard = 0;
    while (vm.isLoading && guard < 20) {
      await Future.delayed(const Duration(milliseconds: 120));
      guard++;

      if (!mounted) return;
    }

    final idx = vm.news.indexWhere((n) => n.id == newsId);
    if (idx < 0) return;

    int attachGuard = 0;
    while (!_itemScrollController.isAttached && attachGuard < 10) {
      await Future.delayed(const Duration(milliseconds: 80));
      attachGuard++;

      if (!mounted) return;
    }

    if (_itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: idx,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.20,
      );
    }

    if (!mounted) return;

    setState(() {
      _highlightId = newsId;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _highlightId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
final vm = context.watch<OwnedCollectionDetailsViewModel>();

final apiError = vm.apiError;
final shouldShowOfflineBanner =
    _showOfflineCacheWarning ||
    (apiError != null && _isOfflineApiMessage(apiError));

_tryAutoFocus(vm);    _tryOpenDirectEdit(vm);

    final collection = vm.ownedCollection;
    final fallbackCollection = _fallbackOwnedCollectionFromMainCache(context);
    final useFallbackHeader = collection.id.trim().isEmpty ||
        collection.collectionName.trim().isEmpty;

    final title = collection.collectionName.trim().isNotEmpty
        ? collection.collectionName.trim()
        : ((fallbackCollection?.collectionName ?? '') as String).trim();

    final desc = collection.collectionDescription.trim().isNotEmpty
        ? collection.collectionDescription.trim()
        : ((fallbackCollection?.collectionDescription ?? '') as String).trim();

    final owner = collection.ownerUsername.trim().isNotEmpty
        ? collection.ownerUsername.trim()
        : ((fallbackCollection?.ownerUsername ?? '') as String).trim();

    final views = useFallbackHeader
        ? ((fallbackCollection?.numOfViewers ?? collection.numOfViewers) as int)
        : collection.numOfViewers;

    final media = MediaQuery.of(context);
    final topInset = media.padding.top;

    const double sheetH = 90.0;
    const double sheetRadius = 34.0;

    final double collapsedH = sheetH + topInset;
    final double expandedH = 360.0 + topInset;

    final double reservedBottom = sheetH + 14.0;
    const double gap = 20.0;

    const ownedHeaderGradient = LinearGradient(
      begin: Alignment.centerRight,
      end: Alignment.centerLeft,
      colors: [
        AppColors.accentBlue2,
        Color.fromARGB(255, 25, 41, 87),
      ],
    );

    final membersCount =
        collection.members.where((m) => m.role == MemberRole.member).length;

    final membersText = _membersCountLabel(membersCount);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
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

                  final t = ((maxH - collapsedH) / (expandedH - collapsedH))
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
                            gradient: ownedHeaderGradient,
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
                            padding: const EdgeInsets.symmetric(horizontal: 12)
                                .copyWith(top: 14),
                            child: Align(
                              alignment: Alignment.topRight,
                              child: Opacity(
                                opacity: headerOpacity,
                                child: IgnorePointer(
                                  ignoring: headerOpacity < 0.05,
                                  child: _TopIconButton(
                                    icon: Icons.arrow_forward_ios_rounded,
                                    onTap: () => Navigator.pop(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12)
                                .copyWith(top: 14),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Opacity(
                                opacity: headerOpacity,
                                child: IgnorePointer(
                                  ignoring: headerOpacity < 0.05,
                                  child: _TopIconButton(
                                    icon: Icons.more_horiz_rounded,
                                    onTap: () => _showOptionsMenu(context, vm),
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
                              padding: const EdgeInsets.fromLTRB(16, 84, 16, 0),
                              child: Opacity(
                                opacity: headerOpacity,
                                child: IgnorePointer(
                                  ignoring: headerOpacity < 0.05,
                                  child: FractionalTranslation(
                                    translation: Offset(0, slideY),
                                    child: Align(
                                      alignment: Alignment.topRight,
                                      child: SingleChildScrollView(
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(height: 18),
                                            Container(
                                              width: double.infinity,
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                title,
                                                textAlign: TextAlign.right,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                  fontFamily: 'NotoSansArabic',
                                                  height: 1.08,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: gap),
                                            Container(
                                              width: double.infinity,
                                              alignment: Alignment.centerRight,
                                              child: Text(
                                                desc,
                                                textAlign: TextAlign.right,
                                                maxLines: 3,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.92),
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w700,
                                                  fontFamily:
                                                      'NotoSansArabic',
                                                  height: 1.18,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: gap),
                                            Container(
                                              width: double.infinity,
                                              alignment: Alignment.centerRight,
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  OwnerPill.glass(owner: owner),
                                                  const SizedBox(width: 8),
                                                  ViewsPill(views: views),
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
                          ),
                        ),
                        Positioned(
                          left: 16,
                          right: 16,
                          bottom: 10,
                          child: Opacity(
                            opacity: headerOpacity,
                            child: IgnorePointer(
                              ignoring: headerOpacity < 0.05,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () async {
                                  final online = await _ensureOnlineForAction(
                                    'لا يمكن عرض الأعضاء بدون إنترنت',
                                  );

                                  if (!online || !mounted) return;

                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          ChangeNotifierProvider.value(
                                        value: vm,
                                        child: MembersScreen(
                                          onDeleteMember: (id) =>
                                              _deleteMember(context, vm, id),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerRight,
                                      end: Alignment.centerLeft,
                                      colors: [
                                        AppColors.accentBlue2,
                                        Color.fromARGB(255, 25, 41, 87),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 16,
                                        offset: const Offset(0, 10),
                                        color: Colors.black.withOpacity(0.08),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.groups_rounded,
                                        color: Colors.white,
                                        size: 26,
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'الأعضاء',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          fontFamily: 'NotoSansArabic',
                                        ),
                                      ),
                                      const Spacer(),
                                      if (membersText.isNotEmpty) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.16),
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color:
                                                  Colors.white.withOpacity(0.18),
                                            ),
                                          ),
                                          child: Text(
                                            membersText,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w900,
                                              fontFamily: 'NotoSansArabic',
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                      ],
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                    ],
                                  ),
                                ),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.start,
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
                      color: AppColors.navy.withOpacity(0.08),
                    ),
                  ],
                ),
              ),
            ),


if (shouldShowOfflineBanner)
  SliverToBoxAdapter(
    child: _offlineBanner(_offlineCacheMessage),
  ),



            if (vm.error != null &&
                (vm.error ?? '').trim().isNotEmpty &&
                !_isOfflineLikeError(vm.error))
  SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 0),
      child: Center(
        child: Text(
          _cleanError(vm.error),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'NotoSansArabic',
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: AppColors.danger,
            height: 1.5,
          ),
        ),
      ),
    ),
  )
else if (vm.isLoading)
  const SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.only(top: 18),
      child: Center(child: CircularProgressIndicator()),
    ),
  )
else if (vm.news.isEmpty)
  SliverToBoxAdapter(
    child: Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Center(
        child: Text(
          'لم تتم إضافة أي أخبار بعد',
          style: TextStyle(
            fontFamily: 'NotoSansArabic',
            fontWeight: FontWeight.w800,
            fontSize: 17,
            color: AppColors.text.withOpacity(0.70),
          ),
        ),
      ),
    ),
  )
            else
              SliverFillRemaining(
                hasScrollBody: true,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
                  child: ScrollablePositionedList.builder(
                    itemScrollController: _itemScrollController,
                    itemCount: vm.news.length,
                    itemBuilder: (context, i) {
                      final AddedNewsModel n = vm.news[i];
                      final addedByUsername =
                          vm.usernameForUserId(n.addedByUserId);

                      final isHighlighted = n.id == _highlightId;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: isHighlighted
                              ? AppColors.accentBlue.withOpacity(0.10)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: AddedNewsCard(
                          item: n,
                          ownerHandle: addedByUsername,
                          ownerPillGradient: ownedHeaderGradient,
                          isOwnedScreen: true,
                          onView: () async {
                            final changed = await Navigator.push<String>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddedNewsDetailsScreen(
                                  addedNews: n,
                                  collectionId: widget.collectionId,
                                  isOwnedScreen: true,
                                  isExploreScreen: false,
                                  onArchivePressed: (ctx, news) async {
                                    final online = await _ensureOnlineForAction(
                                      'لا يمكن أرشفة الخبر بدون إنترنت',
                                    );

                                    if (!online) {
                                      throw Exception(
                                        'لا يمكن أرشفة الخبر بدون إنترنت',
                                      );
                                    }

                                    final ok = await vm.archiveNews(news.id);

                                    if (!ctx.mounted) return;

                                    if (!ok) {
                                      throw Exception(
                                        vm.error ?? 'تعذر أرشفة الخبر',
                                      );
                                    }

                                    Navigator.pop(ctx, 'archived');
                                  },
                                  onRemovePressed: (ctx, news) async {
                                    final online = await _ensureOnlineForAction(
                                      'لا يمكن حذف الخبر بدون إنترنت',
                                    );

                                    if (!online) {
                                      throw Exception(
                                        'لا يمكن حذف الخبر بدون إنترنت',
                                      );
                                    }

                                    final error = await vm.deleteNews(news.id);

                                    if (!ctx.mounted) return;

                                    if (error != null) {
                                      throw Exception(error);
                                    }

                                    Navigator.pop(ctx, 'deleted');
                                  },
                                ),
                              ),
                            );

                            if (!mounted) return;

                            if (changed == 'archived') {
                              await vm.loadDetails();

                              if (!mounted) return;

                              _showSuccess('تمت أرشفة الخبر بنجاح');
                            } else if (changed == 'deleted') {
                              await vm.loadDetails();

                              if (!mounted) return;

                              _showSuccess('تم حذف الخبر بنجاح');
                            }
                          },
                          showActions: true,
                          isMine: n.isAddedByMe,
                          onDelete: () => _deleteNews(context, vm, n.id),
                          onReport: null,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showOptionsMenu(
    BuildContext parentContext,
    OwnedCollectionDetailsViewModel vm,
  ) {
    showModalBottomSheet(
      context: parentContext,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.edit, color: AppColors.navy),
                    title: const Text(
                      'تحرير المجموعة',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppColors.navy,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext, rootNavigator: true).pop();

                      _afterSheetClosed(() async {
                        if (!mounted) return;

                        final online = await _ensureOnlineForAction(
                          'لا يمكن تعديل المجموعة بدون إنترنت',
                        );

                        if (!online || !mounted) return;

                        _showEditDialog(context, vm);
                      });
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.group_add, color: AppColors.navy),
                    title: const Text(
                      'عرض طلبات الانضمام',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppColors.navy,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext, rootNavigator: true).pop();

                      _afterSheetClosed(() async {
                        final online = await _ensureOnlineForAction(
                          'لا يمكن عرض طلبات الانضمام بدون إنترنت',
                        );

                        if (!online || !mounted) return;

                        await vm.loadJoinRequests();

                        if (!mounted) return;

                        await Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: vm,
                              child: const JoinRequestsScreen(),
                            ),
                          ),
                        );
                      });
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading:
                        const Icon(Icons.flag_rounded, color: AppColors.navy),
                    title: const Text(
                      'عرض البلاغات',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppColors.navy,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext, rootNavigator: true).pop();

                      _afterSheetClosed(() async {
                        final online = await _ensureOnlineForAction(
                          'لا يمكن عرض البلاغات بدون إنترنت',
                        );

                        if (!online || !mounted) return;

                        await vm.loadReports();

                        if (!mounted) return;

                        final focusId =
                            await Navigator.of(context, rootNavigator: true)
                                .push<String>(
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: vm,
                              child: const ReportsScreen(),
                            ),
                          ),
                        );

                        if (!mounted) return;

                        if (focusId != null && focusId.trim().isNotEmpty) {
                          await _scrollToNews(focusId.trim());
                        }
                      });
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading:
                        const Icon(Icons.archive_rounded, color: AppColors.navy),
                    title: const Text(
                      'عرض الأخبار المؤرشفة',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppColors.navy,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext, rootNavigator: true).pop();

                      _afterSheetClosed(() async {
                        if (!mounted) return;

                        final online = await _ensureOnlineForAction(
                          'لا يمكن عرض الأخبار المؤرشفة بدون إنترنت',
                        );

                        if (!online || !mounted) return;

                        await Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: vm,
                              child: const ArchivedNewsScreen(),
                            ),
                          ),
                        );
                      });
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.share, color: AppColors.navy),
                    title: const Text(
                      'مشاركة المجموعة',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppColors.navy,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext, rootNavigator: true).pop();

                      _afterSheetClosed(() async {
                        if (!mounted) return;

                        final online = await _ensureOnlineForAction(
                          'لا يمكن مشاركة المجموعة بدون إنترنت',
                        );

                        if (!online || !mounted) return;

                        await _shareCollection(context, vm);
                      });
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.delete, color: AppColors.danger),
                    title: const Text(
                      'حذف المجموعة',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontWeight: FontWeight.w800,
                        fontSize: 15.5,
                        color: AppColors.danger,
                      ),
                    ),
                    onTap: () {
                      Navigator.of(sheetContext, rootNavigator: true).pop();

                      _afterSheetClosed(() async {
                        if (!mounted) return;
                        await _deleteGroup(context, vm);
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEditDialog(
    BuildContext pageContext,
    OwnedCollectionDetailsViewModel vm,
  ) {
    if (!mounted) return;

    final titleController =
        TextEditingController(text: vm.ownedCollection.collectionName);
    final descController =
        TextEditingController(text: vm.ownedCollection.collectionDescription);

    bool titleTouched = false;
    bool descTouched = false;

    String? validateTitle(String input) {
      final value = input.trim();

      if (value.isEmpty) return 'اسم المجموعة مطلوب';
      if (value.length < 3) {
        return 'اسم المجموعة ينبغي أن يحتوي على 3 أحرف على الأقل';
      }
      if (value.length > 40) return 'الحد الأقصى 40 حرف';

      final allowed = RegExp(r'^[\u0600-\u06FFa-zA-Z0-9\s\-_()]+$');
      if (!allowed.hasMatch(value)) {
        return 'مسموح فقط: حروف وأرقام ومسافة و - _ ( )';
      }

      if (RegExp(r'\s{2,}').hasMatch(value)) {
        return 'لا تترك مسافات كثيرة بين الكلمات';
      }

      return null;
    }

    String? validateDesc(String input) {
      final value = input.trim();

      if (value.isEmpty) return 'وصف المجموعة مطلوب';
      if (value.length < 10) {
        return 'الوصف ينبغي أن يحتوي على 10 أحرف على الأقل';
      }
      if (value.length > 90) return 'الحد الأقصى 90 حرف';

      return null;
    }

    showDialog<void>(
      context: pageContext,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (editDialogContext) {
        return StatefulBuilder(
          builder: (editDialogContext, setDialogState) {
            final titleError =
                titleTouched ? validateTitle(titleController.text) : null;
            final descError =
                descTouched ? validateDesc(descController.text) : null;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 30),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                  decoration: BoxDecoration(
                    color: AppColors.softBg,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'تحرير المجموعة',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'NotoSansArabic',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: AppColors.navy,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextField(
                          controller: titleController,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          keyboardType: TextInputType.multiline,
                          maxLength: 40,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(40),
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[\u0600-\u06FFa-zA-Z0-9\s\-_()]'),
                            ),
                          ],
                          onChanged: (_) {
                            setDialogState(() {
                              titleTouched = true;
                            });
                          },
                         decoration: InputDecoration(
  label: RichText(
    textDirection: TextDirection.rtl,
    text: TextSpan(
      text: 'اسم المجموعة ',
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'NotoSansArabic',
      ),
      children: const [
        TextSpan(
          text: '*',
          style: TextStyle(
            color: Colors.red,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'NotoSansArabic',
          ),
        ),
      ],
    ),
  ),
  errorText: titleError,
  errorMaxLines: 2,
  counterText: '${titleController.text.trim().length}/40',
  border: const OutlineInputBorder(),
  filled: true,
  fillColor: Colors.white,
),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: descController,
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          maxLines: 4,
                          maxLength: 90,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(90),
                          ],
                          onChanged: (_) {
                            setDialogState(() {
                              descTouched = true;
                            });
                          },
                          keyboardType: TextInputType.multiline,
                         decoration: InputDecoration(
  label: RichText(
    textDirection: TextDirection.rtl,
    text: TextSpan(
      text: 'الوصف ',
      style: TextStyle(
        color: Colors.grey[600],
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFamily: 'NotoSansArabic',
      ),
      children: const [
        TextSpan(
          text: '*',
          style: TextStyle(
            color: Colors.red,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            fontFamily: 'NotoSansArabic',
          ),
        ),
      ],
    ),
  ),
  errorText: descError,
  errorMaxLines: 2,
  counterText: '${descController.text.trim().length}/90',
  border: const OutlineInputBorder(),
  filled: true,
  fillColor: Colors.white,
),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: TextButton(
                                  onPressed: () =>
                                      Navigator.of(editDialogContext).pop(),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.navy,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: const Text(
                                    'إلغاء',
                                    style: TextStyle(
                                      fontFamily: 'NotoSansArabic',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: SizedBox(
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: () async {
                                    setDialogState(() {
                                      titleTouched = true;
                                      descTouched = true;
                                    });

                                    final newTitle =
                                        titleController.text.trim();
                                    final newDesc = descController.text.trim();

                                    final titleValidation =
                                        validateTitle(newTitle);
                                    final descValidation =
                                        validateDesc(newDesc);

                                    if (titleValidation != null ||
                                        descValidation != null) {
                                      return;
                                    }

                                    final online = await _ensureOnlineForAction(
                                      'لا يمكن تعديل المجموعة بدون إنترنت',
                                    );

                                    if (!online) return;
                                    if (!editDialogContext.mounted) return;

                                    final confirmed =
                                        await AppConfirmDialog.show(
                                      editDialogContext,
                                      title: 'حفظ التعديلات',
                                      message:
                                          'هل تريد حفظ التعديلات على المجموعة؟',
                                      confirmText: 'نعم',
                                      cancelText: 'لا',
                                      confirmColor: const Color(0xFFF05260),
                                    );

                                    if (!confirmed) return;
                                    if (!editDialogContext.mounted) return;

                                    final error = await vm.updateGroup(
  newTitle,
  newDesc,
);

if (!mounted || !editDialogContext.mounted) return;

                                    if (!editDialogContext.mounted) return;

                                   if (error == null) {
  Navigator.of(editDialogContext).pop();

  if (!mounted) return;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;

    _showSuccess('تم تحديث المجموعة بنجاح');
  });
} else {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;

    _showError(error);
  });
}
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.navy,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                  child: const Text(
                                    'حفظ',
                                    style: TextStyle(
                                      fontFamily: 'NotoSansArabic',
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() async {
  await Future.delayed(const Duration(milliseconds: 250));

  titleController.dispose();
  descController.dispose();
});
  }

  Future<void> _deleteGroup(
    BuildContext pageContext,
    OwnedCollectionDetailsViewModel vm,
  ) async {
    final online = await _ensureOnlineForAction(
      'لا يمكن حذف المجموعة بدون إنترنت',
    );

    if (!online || !mounted) return;

    final confirmed = await AppConfirmDialog.show(
      pageContext,
      title: 'حذف المجموعة',
      message:
          'هل أنت متأكد من حذف هذه المجموعة؟ لا يمكن التراجع عن هذه العملية.',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );

    if (!confirmed || !mounted) return;

    final error = await vm.deleteGroup();

    if (!mounted) return;

    if (error != null) {
      _showError(error);
      return;
    }

    _showSuccess('تم حذف المجموعة بنجاح');

    await Future.delayed(const Duration(milliseconds: 450));

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  Future<void> _shareCollection(
    BuildContext pageContext,
    OwnedCollectionDetailsViewModel vm,
  ) async {
    try {
      AppTopMessage.show(
        pageContext,
        text: 'جاري إنشاء رابط المشاركة...',
        type: TopMsgType.info,
      );

      final shareLink = await vm.shareCollection();

      if (!mounted) return;

      if (shareLink == null || shareLink.isEmpty) {
        _showError('فشل إنشاء رابط المشاركة');
        return;
      }

      final shareText = '''
🔗 مجموعة مشتركة: ${vm.ownedCollection.collectionName}

${vm.ownedCollection.collectionDescription}

انضم إلى مجموعتي المشتركة في تطبيق مدار!

$shareLink
''';

      await Share.share(
        shareText,
        subject: 'مجموعة مشتركة - ${vm.ownedCollection.collectionName}',
      );
    } catch (e) {
      if (!mounted) return;
      _showError(e);
    }
  }

  Future<void> _deleteMember(
    BuildContext pageContext,
    OwnedCollectionDetailsViewModel vm,
    String memberId,
  ) async {
    final online = await _ensureOnlineForAction(
      'لا يمكن حذف العضو بدون إنترنت',
    );

    if (!online || !mounted) return;

    final memberName = vm.usernameForUserId(memberId);

    final confirmed = await AppConfirmDialog.show(
      pageContext,
      title: 'حذف العضو',
      message: memberName.trim().isEmpty
          ? 'هل تريد حذف هذا العضو من المجموعة؟'
          : 'هل تريد حذف "$memberName" من المجموعة؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );

    if (!confirmed || !mounted) return;

    final error = await vm.deleteMember(memberId);

    if (!mounted) return;

    if (error != null) {
      _showError(error);
      return;
    }

    _showSuccess('تم حذف العضو بنجاح');
  }

  Future<void> _deleteNews(
    BuildContext pageContext,
    OwnedCollectionDetailsViewModel vm,
    String newsId,
  ) async {
    final online = await _ensureOnlineForAction(
      'لا يمكن حذف الخبر بدون إنترنت',
    );

    if (!online || !mounted) return;

    final confirmed = await AppConfirmDialog.show(
      pageContext,
      title: 'حذف الخبر',
      message: 'هل أنت متأكد من حذف هذا الخبر من المجموعة؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );

    if (!confirmed || !mounted) return;

    final error = await vm.deleteNews(newsId);

    if (!mounted) return;

    if (error != null) {
      _showError(error);
      return;
    }

    _showSuccess('تم حذف الخبر بنجاح');
  }
}

String _membersCountLabel(int n) {
  if (n <= 0) return '';
  if (n == 1) return 'عضو';
  if (n == 2) return 'عضوان';
  return '$n أعضاء';
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