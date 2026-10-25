// joined_collections_details_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_confirm_dialog.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../model/added_news_model.dart';
import '../viewmodel/shared_collections_details_vm.dart';
import '../widgets/added_news.dart';
import '../widgets/owner_pill.dart';
import '../widgets/views_pill.dart';
import 'added_news_detail_screen.dart';

class JoinedCollectionDetailsScreen extends StatefulWidget {
  final String collectionId;

  const JoinedCollectionDetailsScreen({
    super.key,
    required this.collectionId,
  });

  @override
  State<JoinedCollectionDetailsScreen> createState() =>
      _JoinedCollectionDetailsScreenState();
}

class _JoinedCollectionDetailsScreenState
    extends State<JoinedCollectionDetailsScreen> with WidgetsBindingObserver {
  static const String _offlineCacheMessage =
      'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';

  StreamSubscription<dynamic>? _connectivitySub;
  Timer? _internetVerifyTimer;

  bool _showOfflineCacheWarning = false;
  bool _checkingConnection = false;
  bool _actionLocked = false;

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
      final online = await _isOnlineNow();

      if (!mounted) return;

      if (!online) {
        _setOfflineWarning(true);
        return;
      }

      _setOfflineWarning(false);

      final vm = context.read<JoinedCollectionDetailsViewModel>();
      final hasStaleOfflineError = _isOfflineApiMessage(vm.apiError) ||
          _isOfflineApiMessage(vm.error);

      if (reloadWhenOnline || hasStaleOfflineError) {
        await vm.loadDetails();

        if (!mounted) return;
        _setOfflineWarning(false);
      }
    } finally {
      _checkingConnection = false;
    }
  }

  Future<bool> _isOnlineNow() async {
    try {
      final dynamic connectivity = await Connectivity().checkConnectivity();

      if (_isConnectivityNone(connectivity)) {
        return false;
      }

      return await _hasInternetConnection();
    } catch (_) {
      return false;
    }
  }

  Future<bool> _hasInternetConnection() async {
    try {
      final socket = await Socket.connect(
        '8.8.8.8',
        53,
        timeout: const Duration(milliseconds: 900),
      );

      socket.destroy();
      return true;
    } catch (_) {
      try {
        final result = await InternetAddress.lookup('google.com').timeout(
          const Duration(milliseconds: 900),
        );

        return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
      } catch (_) {
        return false;
      }
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

  Future<bool> _ensureOnlineForAction({
    required BuildContext targetContext,
    required String message,
  }) async {
    final online = await _isOnlineNow();

    if (!mounted || !targetContext.mounted) return false;

    _setOfflineWarning(!online);

    if (!online) {
      AppTopMessage.show(
        targetContext,
        text: message,
        type: TopMsgType.error,
      );
      return false;
    }

    return true;
  }

  bool _isOfflineApiMessage(String? message) {
    final m = (message ?? '').trim();
    final lower = m.toLowerCase();

    return m.contains('غير متصل') ||
        m.contains('لا يوجد اتصال') ||
        m.contains('بدون إنترنت') ||
        m.contains('آخر بيانات محفوظة') ||
        lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection error') ||
        lower.contains('connection failed') ||
        lower.contains('connection refused');
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
        ),
      ),
    );
  }

  String _cleanError(String? message) {
    final msg = (message ?? '').trim();

    if (msg.isEmpty) {
      return 'حدث خطأ أثناء تنفيذ العملية';
    }

    final lower = msg.toLowerCase();

    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        msg.contains('غير مصرح')) {
      return 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';
    }

    if (_isOfflineLikeError(msg)) {
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

    if (msg.startsWith('HTTP')) {
      return 'حدث خطأ أثناء تنفيذ العملية';
    }

    return msg;
  }

  void _showSuccess(BuildContext context, String message) {
    if (!context.mounted) return;

    AppTopMessage.show(
      context,
      text: message,
      type: TopMsgType.success,
    );
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;

    if (_isOfflineLikeError(message)) {
      _setOfflineWarning(true);
      return;
    }

    AppTopMessage.show(
      context,
      text: _cleanError(message),
      type: TopMsgType.error,
    );
  }

  void _showActionOfflineMessage(BuildContext context, String message) {
    if (!context.mounted) return;

    _setOfflineWarning(true);

    AppTopMessage.show(
      context,
      text: message,
      type: TopMsgType.error,
    );
  }

  Future<void> _deleteNews(
    BuildContext context,
    JoinedCollectionDetailsViewModel vm,
    String newsId,
  ) async {
    if (_actionLocked) return;

    final online = await _ensureOnlineForAction(
      targetContext: context,
      message: 'لا يمكن حذف الخبر بدون إنترنت',
    );

    if (!online || !context.mounted) return;

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'حذف الخبر',
      message: 'هل أنت متأكد من حذف هذا الخبر من المجموعة؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );

    if (!confirmed || !context.mounted) return;

    _actionLocked = true;

    try {
      final error = await vm.deleteNews(newsId);

      if (!context.mounted) return;

      if (error != null) {
        if (_isOfflineLikeError(error)) {
          _showActionOfflineMessage(
            context,
            'لا يمكن حذف الخبر بدون إنترنت',
          );
          return;
        }

        _showError(context, error);
        return;
      }

      _showSuccess(context, 'تم حذف الخبر بنجاح');
    } finally {
      _actionLocked = false;
    }
  }

  Future<void> _leaveGroup(
    BuildContext context,
    JoinedCollectionDetailsViewModel vm,
  ) async {
    if (_actionLocked) return;

    final online = await _ensureOnlineForAction(
      targetContext: context,
      message: 'لا يمكن مغادرة المجموعة بدون إنترنت',
    );

    if (!online || !context.mounted) return;

    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'مغادرة المجموعة',
      message: 'هل أنت متأكد من مغادرة هذه المجموعة؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );

    if (!confirmed || !context.mounted) return;

    _actionLocked = true;

    try {
      final error = await vm.leaveGroup();

      if (!context.mounted) return;

      if (error != null) {
        if (_isOfflineLikeError(error)) {
          _showActionOfflineMessage(
            context,
            'لا يمكن مغادرة المجموعة بدون إنترنت',
          );
          return;
        }

        _showError(context, error);
        return;
      }

      _showSuccess(context, 'تمت مغادرة المجموعة بنجاح');

      Future.delayed(const Duration(milliseconds: 450), () {
        if (!context.mounted) return;
        Navigator.pop(context, true);
      });
    } finally {
      _actionLocked = false;
    }
  }

  Future<void> _reportNews(
    BuildContext context,
    JoinedCollectionDetailsViewModel vm,
    String newsId,
  ) async {
    if (_actionLocked) return;

    final online = await _ensureOnlineForAction(
      targetContext: context,
      message: 'لا يمكن الإبلاغ عن الخبر بدون إنترنت',
    );

    if (!online || !context.mounted) return;

    final reason = await _showReportReasonDialog(context);

    if (reason == null || reason.trim().isEmpty || !context.mounted) return;

    final stillOnline = await _ensureOnlineForAction(
      targetContext: context,
      message: 'لا يمكن الإبلاغ عن الخبر بدون إنترنت',
    );

    if (!stillOnline || !context.mounted) return;

    _actionLocked = true;

    try {
      await vm.reportNews(newsId, reason);

      if (!context.mounted) return;

      _showSuccess(context, 'تم إرسال البلاغ بنجاح');
    } catch (e) {
      if (!context.mounted) return;

      if (_isOfflineLikeError(e)) {
        _showActionOfflineMessage(
          context,
          'لا يمكن الإبلاغ عن الخبر بدون إنترنت',
        );
        return;
      }

      _showError(context, e.toString());
    } finally {
      _actionLocked = false;
    }
  }

  Future<String?> _showReportReasonDialog(BuildContext context) async {
    const reasons = <String>[
      'محتوى غير مرتبط',
      'مصدر غير موثوق',
      'محتوى مسيء أو غير لائق',
      'معلومات خاطئة / محتوى كاذب',
    ];

    String selectedReason = reasons.first;

    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(horizontal: 34),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                        color: Colors.black.withOpacity(0.16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'الإبلاغ عن الخبر',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'NotoSansArabic',
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'اختر سبب الإبلاغ عن هذا الخبر',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'NotoSansArabic',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.text.withOpacity(0.75),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.softBg,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.navy.withOpacity(0.08),
                          ),
                        ),
                        child: Column(
                          children: reasons.map((reason) {
                            final selected = selectedReason == reason;

                            return RadioListTile<String>(
                              value: reason,
                              groupValue: selectedReason,
                              activeColor: const Color(0xFFF05260),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 6,
                              ),
                              title: Text(
                                reason,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontFamily: 'NotoSansArabic',
                                  fontSize: 14.5,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: AppColors.navy,
                                ),
                              ),
                              onChanged: (value) {
                                if (value == null) return;

                                setState(() {
                                  selectedReason = value;
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(
                                  dialogContext,
                                  selectedReason,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFF05260),
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  shadowColor: const Color(0xFFF05260)
                                      .withOpacity(0.35),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                child: const Text(
                                  'نعم',
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
                              child: TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, null),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.navy,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                ),
                                child: const Text(
                                  'لا',
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
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<JoinedCollectionDetailsViewModel>();

    final apiError = vm.apiError;

    final shouldShowOfflineBanner =
        _showOfflineCacheWarning || _isOfflineApiMessage(apiError);

    final collection = vm.joinedCollection;
    final owner = collection.ownerUsername.trim();
    final views = collection.numOfViewers;
    final desc = collection.collectionDescription.trim();

    final media = MediaQuery.of(context);
    final topInset = media.padding.top;

    const double sheetH = 90.0;
    const double sheetRadius = 34.0;

    final double collapsedH = sheetH + topInset;
    final double expandedH = 360.0 + topInset;

    final double reservedBottom = sheetH + 14.0;
    const double gap = 20.0;

    const joinedHeaderGradient = LinearGradient(
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
                            gradient: joinedHeaderGradient,
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ).copyWith(top: 14),
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Opacity(
                                opacity: headerOpacity,
                                child: IgnorePointer(
                                  ignoring: headerOpacity < 0.05,
                                  child: _TopIconButton(
                                    icon: Icons.logout_rounded,
                                    onTap: () => _leaveGroup(context, vm),
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
                                    child: ClipRect(
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
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Text(
                                                  collection.collectionName,
                                                  textAlign: TextAlign.right,
                                                  maxLines: 3,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.w900,
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
                                                  textAlign: TextAlign.right,
                                                  maxLines: 4,
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    OwnerPill.glass(
                                                      owner: owner,
                                                    ),
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
                              padding: const EdgeInsets.fromLTRB(16, 10, 20, 8),
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
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (shouldShowOfflineBanner)
              SliverToBoxAdapter(
                child: _offlineBanner(_offlineCacheMessage),
              ),
            if (vm.isLoading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (vm.error != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Center(
                    child: Text(
                      _cleanError(vm.error),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
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
                      final isReported = vm.isReportedByMe(n.id);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AddedNewsCard(
                          item: n,
                          ownerHandle: '',
                          ownerPillGradient: joinedHeaderGradient,
                          isOwnedScreen: false,
                          onView: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddedNewsDetailsScreen(
                                  addedNews: n,
                                  collectionId: widget.collectionId,
                                  isOwnedScreen: false,
                                  isExploreScreen: false,
                                  onReportPressed: (ctx, news) async {
                                    await _reportNews(ctx, vm, news.id);
                                  },
                                ),
                              ),
                            );
                          },
                          showActions: true,
                          isMine: n.isAddedByMe,
                          onReport: isReported
                              ? null
                              : () => _reportNews(context, vm, n.id),
                          isReportedByMe: isReported,
                          onDelete: n.isAddedByMe
                              ? () => _deleteNews(context, vm, n.id)
                              : null,
                        ),
                      );
                    },
                    childCount: vm.news.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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
