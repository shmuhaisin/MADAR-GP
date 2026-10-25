import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../../../common_theme/ui/navy_header_clip.dart';
import '../viewmodel/shared_collections_details_vm.dart';
import 'added_news_detail_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with WidgetsBindingObserver {
  static const String _offlineCacheMessage =
      'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';

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
      await _refreshConnectionState();
    });

    _connectivitySub = Connectivity().onConnectivityChanged.listen((result) {
      if (!mounted) return;
      unawaited(_handleConnectivityChanged(result));
    });

    _internetVerifyTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      unawaited(_refreshConnectionState());
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
    unawaited(_refreshConnectionState());
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

    await _refreshConnectionState();
  }

  Future<void> _refreshConnectionState() async {
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

      _setOfflineWarning(!online);
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

  Future<bool> _ensureOnlineForAction({
    required BuildContext targetContext,
    required String message,
  }) async {
    await _refreshConnectionState();

    if (!mounted || !targetContext.mounted) return false;

    if (_showOfflineCacheWarning) {
      AppTopMessage.show(
        targetContext,
        text: message,
        type: TopMsgType.error,
      );
      return false;
    }

    return true;
  }

  String _fmtDate(DateTime d) {
    if (d.millisecondsSinceEpoch == 0) return '';

    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');

    return '$dd/$mm/${d.year}';
  }

  bool _isOfflineApiMessage(String? message) {
    final m = (message ?? '').trim();

    return m.contains('غير متصل') ||
        m.contains('لا يوجد اتصال') ||
        m.contains('آخر بيانات محفوظة');
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

  String _cleanError(Object? error) {
    final msg = (error ?? '').toString().trim();
    final lower = msg.toLowerCase();

    if (msg.isEmpty) {
      return 'حدث خطأ أثناء تنفيذ العملية';
    }

    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        msg.contains('غير مصرح')) {
      return 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';
    }

    if (_isOfflineLikeError(msg)) {
      return 'تعذّر الاتصال بالخادم، تحقق من الإنترنت';
    }

    if (lower.contains('404') ||
        lower.contains('not found') ||
        msg.contains('غير موجود')) {
      return 'لم يتم العثور على الخبر';
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

  void _showError(BuildContext context, Object error) {
    if (!context.mounted) return;

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

  Widget _glossyBackButton({
    required VoidCallback onTap,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withOpacity(0.15),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.28),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.24),
                    Colors.white.withOpacity(0.08),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                    color: Colors.black.withOpacity(0.12),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openReportedNewsDetails(
    BuildContext context,
    OwnedCollectionDetailsViewModel vm,
    String? addedNewsId,
  ) async {
    final id = (addedNewsId ?? '').trim();

    if (id.isEmpty) {
      _showError(context, 'تعذّر العثور على الخبر');
      return;
    }

    final index = vm.news.indexWhere((n) => n.id == id);

    if (index < 0) {
      _showError(context, 'الخبر غير موجود ضمن الأخبار المضافة');
      return;
    }

    final matchedNews = vm.news[index];

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => AddedNewsDetailsScreen(
          addedNews: matchedNews,
          collectionId: vm.ownedCollection.id,
          isOwnedScreen: true,
          isExploreScreen: false,
          isArchivedScreen: false,
          onArchivePressed: (ctx, news) async {
            final online = await _ensureOnlineForAction(
              targetContext: ctx,
              message: 'لا يمكن أرشفة الخبر بدون إنترنت',
            );

            if (!online) return;

            final ok = await vm.archiveNews(news.id);

            if (!ctx.mounted) return;

            if (!ok) {
              throw Exception(vm.error ?? 'تعذر أرشفة الخبر');
            }

            Navigator.pop(ctx, 'archived');
          },
          onRemovePressed: (ctx, news) async {
            final online = await _ensureOnlineForAction(
              targetContext: ctx,
              message: 'لا يمكن حذف الخبر بدون إنترنت',
            );

            if (!online) return;

            final msg = await vm.deleteNews(news.id);

            if (!ctx.mounted) return;

            if (msg != null) {
              throw Exception(msg);
            }

            Navigator.pop(ctx, 'deleted');
          },
        ),
      ),
    );

    if (!context.mounted) return;

    if (result == 'archived') {
      await vm.loadReports();

      if (!context.mounted) return;

      _showSuccess(context, 'تمت أرشفة الخبر بنجاح');
      Navigator.pop(context, id);
      return;
    }

    if (result == 'deleted') {
      await vm.loadReports();

      if (!context.mounted) return;

      _showSuccess(context, 'تم حذف الخبر بنجاح');
      return;
    }
  }

  Future<void> _retryLoadReports(
    BuildContext context,
    OwnedCollectionDetailsViewModel vm,
  ) async {
    final online = await _ensureOnlineForAction(
      targetContext: context,
      message: 'لا يمكن إعادة تحميل البلاغات بدون إنترنت',
    );

    if (!online || !context.mounted) return;

    await vm.loadReports();

    if (!context.mounted) return;

    if (vm.reportsError != null && vm.reportsError!.trim().isNotEmpty) {
      _showError(context, vm.reportsError as Object);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OwnedCollectionDetailsViewModel>();

    final showOfflineBanner = _showOfflineCacheWarning ||
        _isOfflineApiMessage(vm.reportsError);

    Widget body() {
      if (vm.reportsLoading) {
        return const Center(child: CircularProgressIndicator());
      }

      if (vm.reportsError != null &&
          (vm.reportsError ?? '').trim().isNotEmpty &&
          !_isOfflineApiMessage(vm.reportsError)) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _cleanError(vm.reportsError),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.danger,
                    fontWeight: FontWeight.w800,
                    fontFamily: 'NotoSansArabic',
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: () => _retryLoadReports(context, vm),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.navy,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'إعادة المحاولة',
                      style: TextStyle(
                        fontFamily: 'NotoSansArabic',
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      if (vm.reports.isEmpty) {
        return Center(
          child: Text(
            'لا توجد بلاغات',
            style: TextStyle(
              fontFamily: 'NotoSansArabic',
              fontWeight: FontWeight.w800,
              fontSize: 22,
              color: AppColors.text.withOpacity(0.70),
            ),
          ),
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        itemCount: vm.reports.length,
        itemBuilder: (context, index) {
          final report = vm.reports[index];
          final dateText = _fmtDate(report.reportedAt);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE7E9F0)),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 14,
                    offset: const Offset(0, 8),
                    color: Colors.black.withOpacity(0.06),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.feed_rounded,
                        color: AppColors.navy,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'خبر مُبلّغ عنه',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                          fontFamily: 'NotoSansArabic',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    report.newsTitle,
                    textAlign: TextAlign.right,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15.2,
                      fontWeight: FontWeight.w900,
                      color: AppColors.navy,
                      height: 1.35,
                      fontFamily: 'NotoSansArabic',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.warning.withOpacity(0.25),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppColors.warning,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            report.reason,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              color: AppColors.warning,
                              fontFamily: 'NotoSansArabic',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Divider(
                    color: AppColors.navy.withOpacity(0.10),
                    height: 1,
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info,
                          color: AppColors.navy.withOpacity(0.92),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'معلومات المُبلّغ',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontFamily: 'NotoSansArabic',
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: AppColors.navy.withOpacity(0.92),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: [
                      _MetaChipIcon(
                        icon: Icons.person_rounded,
                        label: report.reporterUsername,
                      ),
                      _MetaChipIcon(
                        icon: Icons.calendar_month_rounded,
                        label: dateText,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => _openReportedNewsDetails(
                        context,
                        vm,
                        report.addedNewsId,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'عرض الخبر',
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontWeight: FontWeight.w900,
                              fontSize: 13.6,
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.chevron_right_rounded, size: 22),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.softBg,
        body: Column(
          children: [
            MadarNavyHeaderClip(
              headerHeight: 92,
              overlap: 15,
              sheetRadius: 28,
              child: SizedBox(
                height: 92,
                child: Stack(
                  children: [
                    const Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: 18),
                        child: Text(
                          'البلاغات',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'NotoSansArabic',
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12, right: 12),
                        child: _glossyBackButton(
                          onTap: () => Navigator.pop(context),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showOfflineBanner) _offlineBanner(_offlineCacheMessage),
            Expanded(child: body()),
          ],
        ),
      ),
    );
  }
}

class _MetaChipIcon extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaChipIcon({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final text = label.trim();

    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navy.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.navy.withOpacity(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.navy),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'NotoSansArabic',
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
              color: AppColors.navy,
            ),
          ),
        ],
      ),
    );
  }
}