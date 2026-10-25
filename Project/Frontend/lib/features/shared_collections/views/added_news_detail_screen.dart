//Frontend/lib/features/shared_collections/views/added_news_detail_screen.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../viewmodel/shared_collections_details_vm.dart';
import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_confirm_dialog.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../model/added_news_model.dart';
import '../../news/viewModels/article_detail_view_model.dart' show AudioUiState;

class AddedNewsDetailsScreen extends StatefulWidget {
  final AddedNewsModel addedNews;
  final String collectionId;
  final bool isOwnedScreen;
  final bool isExploreScreen;
  final bool isArchivedScreen;

  final Future<void> Function(BuildContext context, AddedNewsModel news)?
      onArchivePressed;

  final Future<void> Function(BuildContext context, AddedNewsModel news)?
      onReportPressed;

  final Future<void> Function(BuildContext context, AddedNewsModel news)?
      onRestorePressed;

  final Future<void> Function(BuildContext context, AddedNewsModel news)?
      onRemovePressed;

  const AddedNewsDetailsScreen({
    super.key,
    required this.addedNews,
    required this.collectionId,
    required this.isOwnedScreen,
    this.isExploreScreen = false,
    this.isArchivedScreen = false,
    this.onArchivePressed,
    this.onRestorePressed,
    this.onRemovePressed,
    this.onReportPressed,
  });

  @override
  State<AddedNewsDetailsScreen> createState() => _AddedNewsDetailsScreenState();
}

class _AddedNewsDetailsScreenState extends State<AddedNewsDetailsScreen> {
  late final AddedNewsDetailViewModel vmSummary;

  @override
  void initState() {
    super.initState();

    vmSummary = AddedNewsDetailViewModel(
      collectionId: widget.collectionId,
      news: widget.addedNews,
    );

    vmSummary.addListener(_onVmChanged);
  }

  @override
  void dispose() {
    vmSummary.removeListener(_onVmChanged);
    vmSummary.dispose();
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

  Future<bool> _ensureOnlineForAction(String message) async {
    final online = await _hasInternetConnection();

    if (!online) {
      _showError(message);
      return false;
    }

    return true;
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

    if (lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout')) {
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

  void _onVmChanged() {
    if (!mounted) return;

    final msg = vmSummary.error;
    if (msg == null || msg.trim().isEmpty) return;

    AppTopMessage.show(
      context,
      text: _cleanError(msg),
      type: TopMsgType.error,
    );

    vmSummary.clearError();
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

    AppTopMessage.show(
      context,
      text: _cleanError(error),
      type: TopMsgType.error,
    );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    Color confirmColor = const Color(0xFFF05260),
  }) {
    return AppConfirmDialog.show(
      context,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: 'لا',
      confirmColor: confirmColor,
    );
  }

  String _audioLabel() {
    switch (vmSummary.audioUiState) {
      case AudioUiState.loading:
        return 'جارٍ التحميل';
      case AudioUiState.playing:
      case AudioUiState.paused:
      case AudioUiState.idle:
        return 'استماع';
    }
  }

  bool get _showSourceButton => true;

  bool get _showRemoveButton =>
      widget.isOwnedScreen && !widget.isExploreScreen;

  bool get _showArchiveButton =>
      widget.isOwnedScreen &&
      !widget.isExploreScreen &&
      !widget.isArchivedScreen;

  bool get _showRestoreButton =>
      widget.isOwnedScreen &&
      !widget.isExploreScreen &&
      widget.isArchivedScreen;

  bool get _showReportButton =>
      !widget.isOwnedScreen &&
      !widget.isExploreScreen &&
      !widget.isArchivedScreen;

  String _categoryToArabic(String? v) {
    switch ((v ?? '').trim()) {
      case 'Health':
        return 'الصحة';
      case 'Politics':
        return 'السياسة';
      case 'Entertainment':
        return 'الترفيه';
      case 'Technology':
        return 'التقنية';
      case 'Sports':
        return 'الرياضة';
      case 'Economy':
        return 'الاقتصاد';
      default:
        return (v == null || v.trim().isEmpty) ? 'الكل' : v.trim();
    }
  }

  String _formatShareDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy - $hh:$min';
  }

  Future<void> _shareAddedNews() async {
    final news = vmSummary.news;
    final sourceLink = news.sourceLink.trim();

    final text = '''
${news.newsTitle}

التصنيف: ${_categoryToArabic(news.category)}
المصدر: ${news.newsSource}
تاريخ النشر: ${_formatShareDate(news.publishDate)}

${vmSummary.displayedContent}

${sourceLink.isNotEmpty ? 'الرابط:\n$sourceLink' : ''}
''';

    await Share.share(text);
  }

  Future<void> _openSource() async {
    final online = await _ensureOnlineForAction(
      'لا يمكن فتح المصدر بدون إنترنت',
    );

    if (!online) return;

    final sourceLink = vmSummary.news.sourceLink.trim();

    if (sourceLink.isEmpty) {
      _showError('لا يوجد رابط مصدر لهذا الخبر');
      return;
    }

    final url = Uri.tryParse(sourceLink);

    if (url == null || !url.hasScheme) {
      _showError('تعذّر فتح الرابط');
      return;
    }

    try {
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);

      if (!opened) {
        _showError('تعذّر فتح الرابط');
      }
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _handleRemoveAction() async {
    if (widget.onRemovePressed == null) return;

    final online = await _ensureOnlineForAction(
      'لا يمكن حذف الخبر بدون إنترنت',
    );

    if (!online) return;

    final confirmed = await _showConfirmDialog(
      title: 'حذف الخبر',
      message: 'هل تريد حذف هذا الخبر من المجموعة؟ لا يمكن التراجع عن هذه العملية.',
      confirmText: 'نعم',
      confirmColor: const Color(0xFFF05260),
    );

    if (!confirmed || !mounted) return;

    try {
      await widget.onRemovePressed!(context, vmSummary.news);

      if (!mounted) return;

      _showSuccess('تم حذف الخبر بنجاح');
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (widget.isExploreScreen) return;

    if (widget.isArchivedScreen) {
      if (widget.onRestorePressed == null) return;

      final online = await _ensureOnlineForAction(
        'لا يمكن استعادة الخبر بدون إنترنت',
      );

      if (!online) return;

      final confirmed = await _showConfirmDialog(
        title: 'استعادة الخبر',
        message: 'هل تريد استعادة هذا الخبر إلى المجموعة؟',
        confirmText: 'نعم',
        confirmColor: const Color(0xFFF05260),
      );

      if (!confirmed || !mounted) return;

      try {
        await widget.onRestorePressed!(context, vmSummary.news);

        if (!mounted) return;

        _showSuccess('تمت استعادة الخبر بنجاح');
      } catch (e) {
        _showError(e);
      }

      return;
    }

    if (widget.isOwnedScreen) {
      if (widget.onArchivePressed == null) return;

      final online = await _ensureOnlineForAction(
        'لا يمكن أرشفة الخبر بدون إنترنت',
      );

      if (!online) return;

      final confirmed = await _showConfirmDialog(
        title: 'أرشفة الخبر',
        message: 'هل تريد أرشفة هذا الخبر؟ سيختفي من الأخبار النشطة ويمكن استعادته لاحقًا.',
        confirmText: 'نعم',
        confirmColor: const Color(0xFFF05260),
      );

      if (!confirmed || !mounted) return;

      try {
        await widget.onArchivePressed!(context, vmSummary.news);

        if (!mounted) return;

        _showSuccess('تمت أرشفة الخبر بنجاح');
      } catch (e) {
        _showError(e);
      }

      return;
    }

    if (widget.onReportPressed == null) return;

    final online = await _ensureOnlineForAction(
      'لا يمكن الإبلاغ بدون إنترنت',
    );

    if (!online) return;

    final confirmed = await _showConfirmDialog(
      title: 'الإبلاغ عن الخبر',
      message: 'هل تريد الإبلاغ عن هذا الخبر؟ سيتم إرساله للمراجعة.',
      confirmText: 'نعم',
      confirmColor: const Color(0xFFF05260),
    );

    if (!confirmed || !mounted) return;

    try {
      await widget.onReportPressed!(context, vmSummary.news);

      if (!mounted) return;

      _showSuccess('تم إرسال البلاغ بنجاح');
    } catch (e) {
      _showError(e);
    }
  }

  List<Widget> _buildParagraphs(String content) {
    final text = content.trim();
    if (text.isEmpty) return const [];

    final parts = _splitToParagraphs(text);

    return parts
        .where((p) => p.trim().isNotEmpty)
        .map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text(
              p.trim(),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 16.5,
                height: 2.0,
                color: AppColors.navy,
                fontWeight: FontWeight.w600,
                fontFamily: 'NotoSansArabic',
              ),
            ),
          ),
        )
        .toList();
  }

  List<String> _splitToParagraphs(String text) {
    final normalized = text.trim();

    if (normalized.isEmpty) return [];

    if (normalized.contains('\n\n')) {
      return normalized
          .split(RegExp(r'\n\s*\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    final sentences = normalized
        .split(RegExp(r'(?<=[\.\!\؟])\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return sentences.isEmpty ? [normalized] : sentences;
  }

  @override
  Widget build(BuildContext context) {
    const double horizontalPad = 16;
    const double overlapAmount = 26;

    const double floatingButtonSize = 54;
    const double floatingButtonsLeft = 16;
    const double floatingButtonsBottom = 16;
    const double floatingButtonsGap = 10;

    final media = MediaQuery.of(context);
    final topInset = media.padding.top;
    final safeBottom = media.padding.bottom;

    final int floatingButtonsCount = (_showSourceButton ? 1 : 0) +
        (_showRemoveButton ? 1 : 0) +
        (_showArchiveButton ? 1 : 0) +
        (_showRestoreButton ? 1 : 0) +
        (_showReportButton ? 1 : 0);

    final double contentBottomPadding = safeBottom +
        floatingButtonsBottom +
        (floatingButtonSize * floatingButtonsCount) +
        ((floatingButtonsCount > 1
            ? (floatingButtonsCount - 1) * floatingButtonsGap
            : 0)) +
        28;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedBuilder(
        animation: vmSummary,
        builder: (_, __) {
          final news = vmSummary.news;

          return Scaffold(
            backgroundColor: Colors.white,
            body: Stack(
              children: [
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.only(bottom: contentBottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerRight,
                            end: Alignment.centerLeft,
                            colors: [
                              AppColors.headerNavy,
                              AppColors.accentBlue2,
                            ],
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.05),
                                      Colors.black.withOpacity(0.10),
                                      Colors.black.withOpacity(0.18),
                                    ],
                                    stops: const [0.0, 0.55, 1.0],
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                horizontalPad,
                                topInset + 14,
                                horizontalPad,
                                34 + overlapAmount,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      _TopIconButton(
                                        icon: Icons.arrow_forward_ios_rounded,
                                        onTap: () => Navigator.pop(context),
                                      ),
                                      const Spacer(),
                                      _TopIconButton(
                                        icon: Icons.share_rounded,
                                        onTap: _shareAddedNews,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 26),
                                  Text(
                                    news.newsTitle,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      fontFamily: 'NotoSansArabic',
                                      height: 1.28,
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _HeaderMetaChip(
                                        label: news.newsSource,
                                        icon: Icons.public_rounded,
                                      ),
                                      _HeaderMetaChip(
                                        label: _categoryToArabic(news.category),
                                        icon: Icons.interests_rounded,
                                      ),
                                      _HeaderDateChip(
                                        date: news.publishDate,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _HeaderToggleCard(
                                          label: _audioLabel(),
                                          icon: vmSummary.audioUiState ==
                                                  AudioUiState.loading
                                              ? Icons.hourglass_top_rounded
                                              : Icons.graphic_eq,
                                          value: vmSummary.ttsEnabled,
                                          onChanged: (v) =>
                                              vmSummary.toggleTts(v),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _HeaderToggleCard(
                                          label: 'ملخص',
                                          icon: Icons.article_outlined,
                                          value: vmSummary.summaryEnabled,
                                          onChanged: (v) =>
                                              vmSummary.toggleSummary(v),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -overlapAmount),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(34),
                              topRight: Radius.circular(34),
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      vmSummary.summaryEnabled
                                          ? Icons.auto_awesome
                                          : Icons.article_outlined,
                                      size: 22,
                                      color: AppColors.navy,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      vmSummary.summaryEnabled
                                          ? 'ملخص الخبر'
                                          : 'محتوى الخبر',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.navy,
                                        fontFamily: 'NotoSansArabic',
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  height: 1,
                                  color: AppColors.navy.withOpacity(0.08),
                                ),
                                const SizedBox(height: 18),
                                if (vmSummary.summaryLoading)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 40),
                                    child: Center(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          CircularProgressIndicator(
                                            color: AppColors.navy,
                                            strokeWidth: 2.5,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'جارٍ توليد الملخص...',
                                            style: TextStyle(
                                              fontFamily: 'NotoSansArabic',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 14,
                                              color: AppColors.navy,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ..._buildParagraphs(
                                    vmSummary.displayedContent,
                                  ),
                                const SizedBox(height: overlapAmount),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: floatingButtonsLeft,
                  bottom: safeBottom + floatingButtonsBottom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_showSourceButton)
                        _FloatingSideIconButton(
                          icon: Icons.open_in_new_rounded,
                          backgroundColor: AppColors.navy,
                          tooltip: 'عرض المصدر',
                          size: floatingButtonSize,
                          onTap: _openSource,
                        ),
                      if (_showArchiveButton) ...[
                        if (_showSourceButton || _showRemoveButton)
                          const SizedBox(height: floatingButtonsGap),
                        _FloatingSideIconButton(
                          icon: Icons.archive_outlined,
                          backgroundColor: AppColors.warning,
                          tooltip: 'أرشفة',
                          size: floatingButtonSize,
                          onTap: _handlePrimaryAction,
                        ),
                      ],
                      if (_showRestoreButton) ...[
                        if (_showSourceButton || _showRemoveButton)
                          const SizedBox(height: floatingButtonsGap),
                        _FloatingSideIconButton(
                          icon: Icons.unarchive_outlined,
                          backgroundColor: const Color(0xFF1AA37A),
                          tooltip: 'استعادة',
                          size: floatingButtonSize,
                          onTap: _handlePrimaryAction,
                        ),
                      ],
                      if (_showRemoveButton) ...[
                        if (_showSourceButton)
                          const SizedBox(height: floatingButtonsGap),
                        _FloatingSideIconButton(
                          icon: Icons.delete_outline_rounded,
                          backgroundColor: AppColors.danger,
                          tooltip: 'حذف الخبر',
                          size: floatingButtonSize,
                          onTap: _handleRemoveAction,
                        ),
                      ],
                      if (_showReportButton) ...[
                        if (_showSourceButton)
                          const SizedBox(height: floatingButtonsGap),
                        _FloatingSideIconButton(
                          icon: Icons.flag_rounded,
                          backgroundColor: AppColors.danger,
                          tooltip: 'بلّغ',
                          size: floatingButtonSize,
                          onTap: _handlePrimaryAction,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeaderMetaChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _HeaderMetaChip({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = label.trim();
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'NotoSansArabic',
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderDateChip extends StatelessWidget {
  final DateTime date;

  const _HeaderDateChip({required this.date});

  String _formatDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    if (date.millisecondsSinceEpoch == 0) return const SizedBox.shrink();

    final text = _formatDate(date);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.calendar_month_rounded,
            size: 16,
            color: Colors.white,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontFamily: 'NotoSansArabic',
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderToggleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _HeaderToggleCard({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onChanged(!value),
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: Colors.white,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'NotoSansArabic',
                    ),
                  ),
                ),
                IgnorePointer(
                  ignoring: true,
                  child: Transform.scale(
                    scale: 0.56,
                    child: Switch(
                      value: value,
                      onChanged: onChanged,
                      activeThumbColor: Colors.white,
                      activeTrackColor: Colors.white.withOpacity(0.42),
                      inactiveThumbColor: Colors.white70,
                      inactiveTrackColor: Colors.white24,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingSideIconButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final VoidCallback onTap;
  final String tooltip;
  final double size;

  const _FloatingSideIconButton({
    required this.icon,
    required this.backgroundColor,
    required this.onTap,
    required this.tooltip,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor.withOpacity(0.95),
        borderRadius: BorderRadius.circular(18),
        elevation: 0,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 22,
            ),
          ),
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