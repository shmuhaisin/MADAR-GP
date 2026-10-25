// ignore_for_file: use_build_context_synchronously, unused_element_parameter

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:madar_app/features/news/models/article_model.dart';
import 'package:madar_app/features/news/viewModels/article_detail_view_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:madar_app/features/shared_collections/viewmodel/shared_collections_main_vm.dart';
import 'package:madar_app/features/shared_collections/viewmodel/shared_collections_details_vm.dart';
import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/app_top_message.dart';
import '../../../common_theme/ui/app_confirm_dialog.dart';

class ArticleDetailScreen extends StatefulWidget {
  final ArticleModel article;

  const ArticleDetailScreen({
    super.key,
    required this.article,
  });

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late final ArticleDetailViewModel vm;
  late final AddArticleToCollectionViewModel addArticleVm;
  BuildContext? _groupsSheetContext;

  @override
  void initState() {
    super.initState();

    vm = ArticleDetailViewModel(
      articleId: widget.article.id,
      initialArticle: widget.article,
    );

    addArticleVm = AddArticleToCollectionViewModel();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      vm.loadDetails();
    });

    vm.event.addListener(() async {
      final e = vm.event.value;
      if (e == null || !mounted) return;

      if (e is ShowAddToSheetEvent) {
        final online = await _hasInternetConnection();

        if (!online) {
          AppTopMessage.show(
            context,
            text: 'لا يمكن إضافة الخبر إلى مجموعة بدون إنترنت',
            type: TopMsgType.error,
          );
          return;
        }

        await context.read<SharedCollectionsViewModel>().loadAll();

        if (!mounted) return;

        _showChooseGroupSheet();
        return;
      }

      if (e is ShowAddConfirmEvent) {
        final ok = await _showAddConfirmDialog(e.groupName);

        if (ok == true) {
          if (_groupsSheetContext != null) {
            Navigator.of(_groupsSheetContext!).pop();
            _groupsSheetContext = null;
          }

          final success = await addArticleVm.addCurrentArticleToCollection(
            collectionId: vm.selectedCollectionId!,
            originalNewsId: widget.article.id,
          );

          if (!mounted) return;

          if (success) {
            AppTopMessage.show(
              context,
              text: 'تمت إضافة الخبر إلى المجموعة بنجاح',
              type: TopMsgType.success,
            );
            return;
          }

          AppTopMessage.show(
            context,
            text: _cleanAddArticleError(addArticleVm.error),
            type: TopMsgType.error,
          );
        }

        return;
      }

      if (e is RedirectToNewsWithSuccessEvent) {
        if (_groupsSheetContext != null) {
          Navigator.of(_groupsSheetContext!).pop();
          _groupsSheetContext = null;
        }

        Navigator.pop(context, e.message);
        return;
      }

      if (e is ShowReportConfirmEvent) {
        final online = await _hasInternetConnection();

        if (!online) {
          AppTopMessage.show(
            context,
            text: 'لا يمكن الإبلاغ بدون إنترنت',
            type: TopMsgType.error,
          );
          return;
        }

        final ok = await _showReportConfirmDialog();

        if (ok == true) {
          await vm.reportConfirmed();
        }

        return;
      }

      if (e is ShowErrorEvent) {
        final msg = e.message.trim();
        final lower = msg.toLowerCase();

        if (lower.contains('null') || lower.contains('connection')) return;

        AppTopMessage.show(
          context,
          text: _cleanGeneralError(msg),
          type: TopMsgType.error,
        );

        return;
      }
    });
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

  String _cleanAddArticleError(String? error) {
    final msg = (error ?? '').trim();

    if (msg.isEmpty) {
      return 'حدث خطأ أثناء إضافة الخبر';
    }

    final lower = msg.toLowerCase();

    if (lower.contains('409') ||
        lower.contains('conflict') ||
        msg.contains('موجود بالفعل') ||
        msg.contains('الخبر موجود بالفعل')) {
      return 'هذا الخبر موجود بالفعل في المجموعة';
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

    if (lower.contains('500') || lower.contains('internal server')) {
      return 'حدث خطأ في الخادم، حاول مرة أخرى لاحقًا';
    }

    return 'تعذّرت إضافة الخبر إلى المجموعة';
  }

  String _cleanGeneralError(String? error) {
    final msg = (error ?? '').trim();

    if (msg.isEmpty) {
      return 'حدث خطأ غير متوقع';
    }

    final lower = msg.toLowerCase();

    if (lower.contains('409') ||
        lower.contains('conflict') ||
        msg.contains('موجود بالفعل')) {
      return 'هذا العنصر موجود بالفعل';
    }

    if (lower.contains('401') ||
        lower.contains('unauthorized') ||
        msg.contains('غير مصرح')) {
      return 'انتهت الجلسة، يرجى تسجيل الدخول مرة أخرى';
    }

    if (lower.contains('404') ||
        lower.contains('not found') ||
        msg.contains('غير موجود')) {
      return 'لم يتم العثور على البيانات المطلوبة';
    }

    if (lower.contains('connection') ||
        lower.contains('network') ||
        lower.contains('socket') ||
        lower.contains('timeout')) {
      return 'تعذّر الاتصال بالخادم، تحقق من الإنترنت';
    }

    if (lower.contains('500') || lower.contains('internal server')) {
      return 'حدث خطأ في الخادم، حاول مرة أخرى لاحقًا';
    }

    if (msg.startsWith('HTTP')) {
      return 'حدث خطأ أثناء تنفيذ العملية';
    }

    return msg;
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  String _audioLabel() {
    switch (vm.audioUiState) {
      case AudioUiState.loading:
        return 'جارٍ التحميل';
      case AudioUiState.playing:
        return 'استماع';
      case AudioUiState.paused:
        return 'استماع';
      case AudioUiState.idle:
        return 'استماع';
    }
  }

  @override
  Widget build(BuildContext context) {
    const double horizontalPad = 16;
    const double overlapAmount = 26;

    const double floatingButtonSize = 54;
    const double floatingButtonsLeft = 16;
    const double floatingButtonsBottom = 16;
    const double floatingButtonsGap = 10;
   const int floatingButtonsCount = 3;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: AnimatedBuilder(
        animation: vm,
        builder: (_, __) {
          final a = vm.article ?? widget.article;
          final media = MediaQuery.of(context);
          final topInset = media.padding.top;
          final safeBottom = media.padding.bottom;



final double contentBottomPadding = safeBottom +
    floatingButtonsBottom +
    (floatingButtonSize * floatingButtonsCount) +
    ((floatingButtonsCount - 1) * floatingButtonsGap) +
    28;

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
                                      Builder(
                                        builder: (btnCtx) => _TopIconButton(
  icon: Icons.share_rounded,
  onTap: () {
    final article = vm.article ?? widget.article;
    vm.shareArticle(article);
  },
),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 26),
                                  Text(
                                    a.newsTitle,
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
                                        label: a.newsSource,
                                        icon: Icons.public_rounded,
                                      ),
                                      _HeaderMetaChip(
                                        label: _categoryToArabic(a.category),
                                        icon: Icons.interests_rounded,
                                      ),
                                      _HeaderDateChip(date: a.publishDate),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _HeaderToggleCard(
                                          label: _audioLabel(),
                                          icon: vm.audioUiState ==
                                                  AudioUiState.loading
                                              ? Icons.hourglass_top_rounded
                                              : Icons.graphic_eq,
                                          value: vm.ttsEnabled,
                                          onChanged: (v) => vm.toggleTts(v),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: _HeaderToggleCard(
                                          label: 'ملخص',
                                          icon: Icons.article_outlined,
                                          value: vm.summaryEnabled,
                                          onChanged: vm.toggleSummary,
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
                                      vm.summaryEnabled
                                          ? Icons.auto_awesome
                                          : Icons.article_outlined,
                                      size: 22,
                                      color: AppColors.navy,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      vm.summaryEnabled
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
                                if (vm.summaryLoading)
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
                                    vm.summaryEnabled &&
                                            a.summaryText.trim().isNotEmpty
                                        ? a.summaryText
                                        : a.newsContent,
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
                      _FloatingSideIconButton(
  icon:Icons.add_rounded,
  backgroundColor:const Color.fromARGB(255, 39, 86, 148) ,
  tooltip: 'إضافة إلى مجموعة',
  size: floatingButtonSize,
  onTap: vm.onAddToPressed,
),
  const SizedBox(height: floatingButtonsGap),
                      _FloatingSideIconButton(
                        icon: Icons.open_in_new_rounded,
                        backgroundColor: AppColors.navy,
                        tooltip: 'عرض المصدر',
                        size: floatingButtonSize,
                        onTap: () async {
                          final url = Uri.tryParse(a.sourceLink);
                          if (url == null) return;

                          if (!await launchUrl(
                            url,
                            mode: LaunchMode.externalApplication,
                          )) {
                            if (!mounted) return;

                            AppTopMessage.show(
                              context,
                              text: 'تعذّر فتح الرابط',
                              type: TopMsgType.error,
                            );
                          }
                        },
                      ),
                      const SizedBox(height: floatingButtonsGap),
                      _FloatingSideIconButton(
                        icon: Icons.flag_rounded,
                        backgroundColor: AppColors.danger,
                        tooltip: 'بلّغ',
                        size: floatingButtonSize,
                        onTap: vm.onReportPressed,
                      ),
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

  Future<void> _showChooseGroupSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        _groupsSheetContext = sheetCtx;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.softBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              boxShadow: [
                BoxShadow(
                  blurRadius: 30,
                  offset: const Offset(0, -10),
                  color: Colors.black.withOpacity(0.12),
                ),
              ],
            ),
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.78,
              minChildSize: 0.35,
              maxChildSize: 0.92,
              builder: (context, scrollController) {
                final groupsVm = context.watch<SharedCollectionsViewModel>();
                final owned = groupsVm.ownedCollections;
                final joined = groupsVm.joinedCollections;

                return ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        'المجموعات',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: AppColors.navy,
                          fontFamily: 'NotoSansArabic',
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _NewsPickerSectionHeader(
                      title: 'مجموعاتي المشتركة',
                      dotColor: AppColors.accentBlue,
                    ),
                    const SizedBox(height: 10),
                    if (groupsVm.loading) ...[
                      const SizedBox(height: 60),
                      const Center(child: CircularProgressIndicator()),
                    ] else if (owned.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'لم تقم بإنشاء مجموعات مشتركة بعد',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.text.withOpacity(0.70),
                            ),
                          ),
                        ),
                      )
                    else
                      ...owned.map((c) {
                        return _NewsCollectionPickTile(
                          title: c.collectionName,
                          isOwned: true,
                          onTap: () => vm.onGroupChosen(
                            collectionId: c.id,
                            collectionName: c.collectionName,
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    const _NewsPickerSectionHeader(
                      title: 'مجموعات انضممت إليها',
                      dotColor:Color(0xFF8B3258),
                    ),
                    const SizedBox(height: 10),
                    if (!groupsVm.loading && joined.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'لم تنضم إلى مجموعات مشتركة بعد',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'NotoSansArabic',
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: AppColors.text.withOpacity(0.70),
                            ),
                          ),
                        ),
                      )
                    else if (!groupsVm.loading)
                      ...joined.map((c) {
                        return _NewsCollectionPickTile(
                          title: c.collectionName,
                          isOwned: false,
                          onTap: () => vm.onGroupChosen(
                            collectionId: c.id,
                            collectionName: c.collectionName,
                          ),
                        );
                      }),
                    const SizedBox(height: 18),
                  ],
                );
              },
            ),
          ),
        );
      },
    );

    _groupsSheetContext = null;
  }

  Future<bool?> _showAddConfirmDialog(String group) async {
    final result = await AppConfirmDialog.show(
      context,
      title: 'إضافة الخبر',
      message: 'هل تريد إضافة هذا الخبر إلى مجموعة "$group"؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );

    return result;
  }

  Future<bool?> _showReportConfirmDialog() async {
    final result = await AppConfirmDialog.show(
      context,
      title: 'الإبلاغ عن الخبر',
      message: 'هل تريد الإبلاغ عن هذا الخبر؟',
      confirmText: 'نعم',
      cancelText: 'لا',
      confirmColor: const Color(0xFFF05260),
    );

    return result;
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

  const _HeaderDateChip({
    required this.date,
  });

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
                Icon(icon, size: 16, color: Colors.white),
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
  size: icon == Icons.add_rounded ? 30 : 22,
),
          ),
        ),
      ),
    );
  }
}

class _NewsCollectionPickTile extends StatelessWidget {
  final String title;
  final bool isOwned;
  final VoidCallback onTap;

  const _NewsCollectionPickTile({
    required this.title,
    required this.isOwned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const radius = 16.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (isOwned)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        AppColors.accentBlue2,
                        Color.fromARGB(255, 25, 41, 87),
                      ],
                    ),
                  ),
                ),
              ),
            if (!isOwned)
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                   gradient: LinearGradient(
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
  ),
                  ),
                ),
              ),
            if (!isOwned)
              Positioned.fill(
                child: Container(color: Colors.black.withOpacity(0.16)),
              ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withOpacity(0.16),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  leading: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _NewsPickIconPill(icon: Icons.collections_bookmark),
                    ],
                  ),
                  title: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      fontFamily: 'NotoSansArabic',
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewsPickIconPill extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color iconColor;
  final Color bgColor;

  const _NewsPickIconPill({
    required this.icon,
    this.tooltip = '',
    this.iconColor = Colors.white,
    this.bgColor = const Color.fromARGB(60, 255, 255, 255),
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }
}

class _NewsPickerSectionHeader extends StatelessWidget {
  final String title;
  final Color dotColor;

  const _NewsPickerSectionHeader({
    required this.title,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.navy,
            fontFamily: 'NotoSansArabic',
          ),
        ),
      ],
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