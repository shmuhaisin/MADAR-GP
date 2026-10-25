// Frontend/lib/features/shared_collections/views/memebers_screen.dart

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../../../common_theme/ui/navy_header_clip.dart';
import '../model/member_model.dart';
import '../viewmodel/shared_collections_details_vm.dart';

class MembersScreen extends StatefulWidget {
  final Future<void> Function(String memberId) onDeleteMember;

  const MembersScreen({
    super.key,
    required this.onDeleteMember,
  });

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen>
    with WidgetsBindingObserver {
  static const String _offlineCacheMessage =
      'أنت غير متصل بالإنترنت، يتم عرض آخر بيانات محفوظة';

  StreamSubscription<dynamic>? _connectivitySub;
  Timer? _internetVerifyTimer;

  bool _showOfflineCacheWarning = false;
  bool _checkingConnection = false;
  bool _deleteLocked = false;

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

  Future<bool> _ensureOnlineForDelete() async {
    await _refreshConnectionState();

    if (!mounted) return false;

    if (_showOfflineCacheWarning) {
      AppTopMessage.show(
        context,
        text: 'لا يمكن حذف العضو بدون إنترنت',
        type: TopMsgType.error,
      );
      return false;
    }

    return true;
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

    if (lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout')) {
      return 'تعذّر الاتصال بالخادم، تحقق من الإنترنت';
    }

    if (lower.contains('404') ||
        lower.contains('not found') ||
        msg.contains('غير موجود')) {
      return 'لم يتم العثور على العضو';
    }

    if (lower.contains('409') ||
        lower.contains('conflict') ||
        msg.contains('موجود') ||
        msg.contains('مسبق')) {
      return 'تعذر تنفيذ العملية على هذا العضو';
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

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;

    AppTopMessage.show(
      context,
      text: _cleanError(message),
      type: TopMsgType.error,
    );
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

  Future<void> _handleDeleteMemberTap({
    required BuildContext context,
    required String memberId,
  }) async {
    if (_deleteLocked) return;

    final online = await _ensureOnlineForDelete();

    if (!online || !context.mounted) return;

    setState(() {
      _deleteLocked = true;
    });

    try {
      // Important:
      // Do NOT show confirmation here.
      // The parent OwnedDetailsScreen already shows the confirmation dialog
      // inside _deleteMember(...). This prevents the double-confirm bug.
      await widget.onDeleteMember(memberId);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, e.toString());
    } finally {
      if (!mounted) return;

      setState(() {
        _deleteLocked = false;
      });
    }
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OwnedCollectionDetailsViewModel>();

    final members = vm.ownedCollection.members
        .where((m) => m.role == MemberRole.member)
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.softBg,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: MadarNavyHeaderClip(
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
                            'الأعضاء',
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
            ),
            if (_showOfflineCacheWarning)
              SliverToBoxAdapter(
                child: _offlineBanner(_offlineCacheMessage),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              sliver: members.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 260),
                          child: Text(
                            'لا يوجد أعضاء بعد',
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontWeight: FontWeight.w800,
                              fontSize: 24,
                              color: AppColors.text.withOpacity(0.70),
                            ),
                          ),
                        ),
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final m = members[index];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 16,
                                    offset: const Offset(0, 10),
                                    color: Colors.black.withOpacity(0.06),
                                  ),
                                ],
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: Row(
                                children: [
                                  const CircleAvatar(
                                    radius: 22,
                                    backgroundColor: AppColors.navy,
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      m.username,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.navy,
                                        fontFamily: 'NotoSansArabic',
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE9E9),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFFFC8C8),
                                      ),
                                    ),
                                    child: IconButton(
                                      onPressed: _deleteLocked
                                          ? null
                                          : () => _handleDeleteMemberTap(
                                                context: context,
                                                memberId: m.id,
                                              ),
                                      icon: const Icon(Icons.delete_rounded),
                                      iconSize: 20,
                                      color: const Color(0xFFD93A3A),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      splashRadius: 22,
                                      tooltip: 'حذف العضو',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: members.length,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}