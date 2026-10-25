// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../profile/model/profile_model.dart';
import '../../profile/viewmodel/profile_viewmodel.dart';
import '../viewmodel/semantic_notifications_vm.dart';
import '../viewmodel/notifications_history_vm.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/navy_header_clip.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../../../common_theme/ui/app_confirm_dialog.dart';

class SemanticNotificationsPage extends StatefulWidget {
  const SemanticNotificationsPage({super.key});

  @override
  State<SemanticNotificationsPage> createState() =>
      _SemanticNotificationsPageState();
}

const LinearGradient interestsGradient = LinearGradient(
  begin: Alignment.centerRight,
  end: Alignment.centerLeft,
  colors: [AppColors.navy, AppColors.accentBlue],
);

class _SemanticNotificationsPageState extends State<SemanticNotificationsPage>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;

  static const Duration _refreshInterval = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _loadInitial();
      _startAutoRefresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _refreshTimer = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.resumed) {
      _refreshSilently();
    }
  }

  Future<void> _loadInitial() async {
    final profileVM = context.read<ProfileViewModel>();
    final semanticVM = context.read<SemanticNotificationsVM>();

    await profileVM.loadProfile();
    await semanticVM.loadSemanticNotifications();

    if (!mounted) return;
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted) return;
      _refreshSilently();
    });
  }

  Future<void> _refreshSilently() async {
    final vm = context.read<SemanticNotificationsVM>();

    if (vm.isLoading) return;

    await vm.loadSemanticNotifications(silent: true);

    if (!mounted) return;
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
      ),
    );
  }

  Widget _glossyBackButton({required VoidCallback onTap}) {
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

  void _showOfflineEditMessage() {
    AppTopMessage.show(
      context,
      text: 'لا يمكن تعديل الكلمات الدلالية بدون اتصال بالإنترنت',
      type: TopMsgType.error,
    );
  }

  Future<void> _createDialog() async {
    final vm = context.read<SemanticNotificationsVM>();
    final profileVM = context.read<ProfileViewModel>();

    if (vm.isOffline) {
      AppTopMessage.show(
        context,
        text: 'لا يمكن إضافة كلمة دلالية بدون اتصال بالإنترنت',
        type: TopMsgType.error,
      );
      return;
    }

    await profileVM.loadProfile();

    if (!mounted) return;

    final userInterests = profileVM.selectedInterests.toList();

    if (userInterests.isEmpty) {
      AppTopMessage.show(
        context,
        text: 'لا توجد اهتمامات لإضافة كلمة دلالية',
        type: TopMsgType.error,
      );
      return;
    }

    Interest? selected;
    String keyword = '';
    bool isSubmitting = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isValid =
                selected != null && keyword.trim().isNotEmpty && !isSubmitting;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 24,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(dialogCtx).size.height -
                        MediaQuery.of(dialogCtx).viewInsets.bottom -
                        80,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.navy.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.tag_rounded,
                                size: 20,
                                color: AppColors.navy,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'كلمة دلالية جديدة',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.navy,
                                fontFamily: 'NotoSansArabic',
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: () => Navigator.pop(dialogCtx),
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'الاهتمام',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'NotoSansArabic',
                          ),
                        ),
                        const SizedBox(height: 8),
                        PopupMenuButton<Interest>(
                          onSelected: (v) {
                            setDialogState(() {
                              selected = v;
                            });
                          },
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          color: Colors.white,
                          elevation: 8,
                          offset: const Offset(0, 50),
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(dialogCtx).size.width - 96,
                          ),
                          itemBuilder: (_) {
                            return userInterests.map((e) {
                              final isSelected = selected == e;

                              return PopupMenuItem<Interest>(
                                value: e,
                                height: 48,
                                child: Directionality(
                                  textDirection: TextDirection.rtl,
                                  child: Row(
                                    children: [
                                      Text(
                                        e.labelAr,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w600,
                                          fontFamily: 'NotoSansArabic',
                                          color: isSelected
                                              ? AppColors.navy
                                              : AppColors.text,
                                        ),
                                      ),
                                      const Spacer(),
                                      if (isSelected)
                                        const Icon(
                                          Icons.check_rounded,
                                          color: AppColors.navy,
                                          size: 18,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    selected == null
                                        ? 'اختر من القائمة'
                                        : selected!.labelAr,
                                    textAlign: TextAlign.right,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: selected != null
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      fontFamily: 'NotoSansArabic',
                                      color: selected != null
                                          ? AppColors.text
                                          : Colors.grey.shade400,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 20,
                                  color: Colors.grey.shade500,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'الكلمة المفتاحية',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'NotoSansArabic',
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                          style: const TextStyle(
                            color: AppColors.navy,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'NotoSansArabic',
                          ),
                          onChanged: (v) {
                            final filtered = v.replaceAll(
                              RegExp(r'[^\u0600-\u06FF\s]'),
                              '',
                            );

                            setDialogState(() {
                              keyword = filtered;
                            });
                          },
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[\u0600-\u06FF\s]'),
                            ),
                          ],
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'مثال: الذكاء الاصطناعي',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'NotoSansArabic',
                            ),
                            filled: true,
                            fillColor: AppColors.softBg,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide:
                                  const BorderSide(color: AppColors.navy),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.navy.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.navy.withOpacity(0.12),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 16,
                                color: AppColors.navy.withOpacity(0.7),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'احرص على إدخال كلمة دقيقة وصحيحة إملائياً للحصول على إشعارات أكثر دقة وملاءمة لاهتمامك.',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: AppColors.navy.withOpacity(0.75),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                    fontFamily: 'NotoSansArabic',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: SizedBox(
                            width: 130,
                            height: 44,
                            child: ElevatedButton(
                              onPressed: isValid
                                  ? () async {
                                      setDialogState(() {
                                        isSubmitting = true;
                                      });

                                      final ok = await vm.add(
                                        interest: selected!,
                                        keyword: keyword.trim(),
                                      );

                                      if (!dialogCtx.mounted) return;
                                      Navigator.pop(dialogCtx);

                                      if (!mounted) return;

                                      if (ok) {
                                        await context
                                            .read<NotificationHistoryVM>()
                                            .loadNotifications(silent: true);

                                        AppTopMessage.show(
                                          context,
                                          text:
                                              'تم إنشاء الكلمة الدلالية بنجاح',
                                          type: TopMsgType.success,
                                        );
                                      } else {
                                        AppTopMessage.show(
                                          context,
                                          text: vm.error ??
                                              'فشل إنشاء الكلمة الدلالية',
                                          type: TopMsgType.error,
                                        );
                                      }
                                    }
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.navy,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: Colors.grey.shade300,
                                disabledForegroundColor: Colors.grey.shade500,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'إنشاء',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'NotoSansArabic',
                                ),
                              ),
                            ),
                          ),
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
    );
  }

  Future<bool> _confirmDeleteKeyword(String keyword) {
    return AppConfirmDialog.show(
      context,
      title: 'حذف الكلمة الدلالية',
      message: 'هل تريد حذف "$keyword"؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );
  }

  Widget _interestBlock({
    required Interest title,
    required List<String> keywords,
    required void Function(String kw) onDelete,
    bool showDivider = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Directionality(
          textDirection: TextDirection.rtl,
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.interests_rounded,
                  size: 17,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title.labelAr,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'NotoSansArabic',
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.navy.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  keywords.length.toString(),
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'NotoSansArabic',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            alignment: WrapAlignment.start,
            spacing: 10,
            runSpacing: 10,
            children: keywords.map((kw) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: interestsGradient,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                      color: AppColors.navy.withOpacity(0.2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onDelete(kw),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      kw,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'NotoSansArabic',
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        if (showDivider) ...[
          const SizedBox(height: 20),
          Divider(color: Colors.grey.shade200, height: 1),
          const SizedBox(height: 8),
        ] else
          const SizedBox(height: 16),
      ],
    );
  }

 Widget _buildHeader() {
  final top = MediaQuery.of(context).padding.top;
  final headerH = 100.0 + top;

  return MadarNavyHeaderClip(
    headerHeight: headerH,
    overlap: 0,
    sheetRadius: 0,
    child: Stack(
      children: [
        const Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: EdgeInsets.only(top: 18),
            child: Text(
              'الكلمات الدلالية',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
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
  );
}
  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SemanticNotificationsVM>();
    final entries = vm.grouped.entries.toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.softBg,
        body: Column(
          children: [
            _buildHeader(),
            if (vm.isOffline)
              _offlineBanner(
                'أنت غير متصل بالإنترنت. يتم عرض آخر كلمات دلالية محفوظة.',
              ),
            Expanded(
              child: vm.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : entries.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: AppColors.navy.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.tag_rounded,
                                  size: 40,
                                  color: AppColors.navy.withOpacity(0.3),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد كلمات دلالية محفوظة',
                                style: TextStyle(
                                  color: AppColors.text.withOpacity(0.5),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'NotoSansArabic',
                                ),
                              ),
                              const SizedBox(height: 6),
                              ElevatedButton.icon(
                                onPressed: vm.isOffline
                                    ? _showOfflineEditMessage
                                    : _createDialog,
                                icon: const Icon(Icons.add_rounded, size: 20),
                                label: const Text(
                                  'إنشاء كلمة دلالية',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'NotoSansArabic',
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: vm.isOffline
                                      ? Colors.grey.shade400
                                      : AppColors.navy,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
                          children: [
                            GestureDetector(
                              onTap: vm.isOffline
                                  ? _showOfflineEditMessage
                                  : _createDialog,
                              child: Opacity(
                                opacity: vm.isOffline ? 0.65 : 1,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(18),
                                    boxShadow: [
                                      BoxShadow(
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                        color: Colors.black.withOpacity(0.06),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color:
                                              AppColors.navy.withOpacity(0.08),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: const Icon(
                                          Icons.add_rounded,
                                          color: AppColors.navy,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      const Text(
                                        'إنشاء كلمة دلالية',
                                        style: TextStyle(
                                          color: AppColors.navy,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          fontFamily: 'NotoSansArabic',
                                        ),
                                      ),
                                      const Spacer(),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: Colors.grey.shade400,
                                        size: 24,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 15,
                                    offset: const Offset(0, 5),
                                    color: Colors.black.withOpacity(0.06),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: List.generate(entries.length, (i) {
                                  final entry = entries[i];
                                  final isLast = i == entries.length - 1;

                                  return _interestBlock(
                                    title: entry.key,
                                    keywords: entry.value,
                                    onDelete: (kw) async {
                                      if (vm.isOffline) {
                                        AppTopMessage.show(
                                          context,
                                          text:
                                              'لا يمكن حذف كلمة دلالية بدون اتصال بالإنترنت',
                                          type: TopMsgType.error,
                                        );
                                        return;
                                      }

                                      final confirm =
                                          await _confirmDeleteKeyword(kw);

                                      if (!confirm) return;

                                      final ok = await vm.delete(
                                        interest: entry.key,
                                        keyword: kw,
                                      );

                                      if (!mounted) return;

                                      if (ok) {
                                        await context
                                            .read<NotificationHistoryVM>()
                                            .loadNotifications(silent: true);

                                        AppTopMessage.show(
                                          context,
                                          text: 'تم حذف الكلمة الدلالية بنجاح',
                                          type: TopMsgType.success,
                                        );
                                      } else {
                                        AppTopMessage.show(
                                          context,
                                          text: vm.error ??
                                              'فشل حذف الكلمة الدلالية',
                                          type: TopMsgType.error,
                                        );
                                      }
                                    },
                                    showDivider: !isLast,
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
