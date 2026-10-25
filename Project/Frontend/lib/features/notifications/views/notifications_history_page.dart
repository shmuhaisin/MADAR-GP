import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodel/notifications_history_vm.dart';
import '../widgets/notification_card.dart';
import '../viewmodel/semantic_notifications_vm.dart';

import '../../profile/model/profile_model.dart';

import '../../../common_theme/ui/app_colors.dart';
import '../../../common_theme/ui/navy_header_clip.dart';
import '../../../common_theme/ui/app_top_message.dart';

class NotificationHistoryPage extends StatefulWidget {
  const NotificationHistoryPage({super.key});

  @override
  State<NotificationHistoryPage> createState() =>
      _NotificationHistoryPageState();
}

class _NotificationHistoryPageState extends State<NotificationHistoryPage>
    with WidgetsBindingObserver {
  Timer? _refreshTimer;
  String? _lastShownError;

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
void deactivate() {
  final vm = context.read<NotificationHistoryVM>();
  
  for (final n in vm.allNotifications) {
    n.isRead = true;
  }
  
  vm.markAllAsRead();
  
  super.deactivate();
}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;

    if (state == AppLifecycleState.resumed) {
      _refreshSilently();
    }
  }

Future<void> _loadInitial() async {
  final historyVM = context.read<NotificationHistoryVM>();

  await historyVM.markAllAsRead();
  
  await historyVM.loadNotifications();

  if (!mounted) return;
  _showVmErrorsIfAny();
}

  void _startAutoRefresh() {
    _refreshTimer?.cancel();

    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      if (!mounted) return;
      _refreshSilently();
    });
  }

  Future<void> _refreshSilently() async {
    final historyVM = context.read<NotificationHistoryVM>();

    if (historyVM.isLoading) return;

    await historyVM.loadNotifications(silent: true);

    if (!mounted) return;
    _showVmErrorsIfAny();
  }

  void _showVmErrorsIfAny() {
    final error = context.read<NotificationHistoryVM>().error;

    if (error == null || error.trim().isEmpty) return;
    if (_lastShownError == error) return;

    _lastShownError = error;

    AppTopMessage.show(
      context,
      text: error,
      type: TopMsgType.error,
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

  Widget _pillChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.navy : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? AppColors.navy : Colors.grey.shade300,
            width: 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                    color: AppColors.navy.withOpacity(0.25),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.navy,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.navy,
                fontFamily: 'NotoSansArabic',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openKeywordsPicker(BuildContext context) async {
    final historyVM = context.read<NotificationHistoryVM>();
    final semanticVM = context.read<SemanticNotificationsVM>();

    await semanticVM.loadSemanticNotifications();

    if (!context.mounted) return;

    final allKeywords = semanticVM.grouped.values.expand((e) => e).toList();

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final temp = Set<String>.from(historyVM.selectedKeywords);

        return StatefulBuilder(
          builder: (context, setState) {
            bool isAllSelected() =>
                allKeywords.isNotEmpty && temp.length == allKeywords.length;
            bool isInterestFullySelected(List<String> keywords) =>
                keywords.isNotEmpty && keywords.every((k) => temp.contains(k));

            bool isInterestPartiallySelected(List<String> keywords) =>
                keywords.any((k) => temp.contains(k)) &&
                !isInterestFullySelected(keywords);

            void toggleInterest(List<String> keywords) {
              setState(() {
                if (isInterestFullySelected(keywords)) {
                  temp.removeAll(keywords);
                } else {
                  temp.addAll(keywords);
                }
              });
            }

            return Container(
              margin: const EdgeInsets.only(top: 60),
              decoration: BoxDecoration(
                color: AppColors.softBg,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 30,
                    offset: const Offset(0, -10),
                    color: Colors.black.withOpacity(0.12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                if (isAllSelected()) {
                                  temp.clear();
                                } else {
                                  temp
                                    ..clear()
                                    ..addAll(allKeywords);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 9,
                              ),
                              decoration: BoxDecoration(
                                color: isAllSelected()
                                    ? AppColors.navy
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  width: 1.2,
                                  color: isAllSelected()
                                      ? Colors.white.withOpacity(0.25)
                                      : Colors.grey.withOpacity(0.4),
                                ),
                                boxShadow: isAllSelected()
                                    ? [
                                        BoxShadow(
                                          blurRadius: 14,
                                          offset: const Offset(0, 8),
                                          color: Colors.black.withOpacity(0.14),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Text(
                                isAllSelected() ? 'إلغاء الكل' : 'اختيار الكل',
                                style: TextStyle(
                                  color: isAllSelected()
                                      ? Colors.white
                                      : AppColors.navy,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  fontFamily: 'NotoSansArabic',
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'الكلمات الدلالية',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy,
                            fontFamily: 'NotoSansArabic',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 11),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.50,
                    ),
                    child: Builder(
                      builder: (_) {
                        final entries = semanticVM.grouped.entries.toList();

                        if (entries.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'لا توجد كلمات دلالية',
                                style: TextStyle(
                                  fontFamily: 'NotoSansArabic',
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.navy,
                                ),
                              ),
                            ),
                          );
                        }

                        return ListView(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: List.generate(entries.length, (index) {
                            final entry = entries[index];
                            final interest = entry.key;
                            final keywords = entry.value;
                            final isLast = index == entries.length - 1;

                            return Directionality(
                              textDirection: TextDirection.rtl,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
Padding(
  padding: const EdgeInsets.only(top: 14, bottom: 10),
  child: InkWell(
    onTap: () => toggleInterest(keywords),
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: isInterestFullySelected(keywords)
                  ? AppColors.navy
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: isInterestFullySelected(keywords)
                    ? AppColors.navy
                    : AppColors.navy.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: isInterestFullySelected(keywords)
                ? const Icon(
                    Icons.check_rounded,
                    size: 12,
                    color: Colors.white,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Icon(
            Icons.interests_rounded,
            size: 22,
            color: AppColors.navy,
          ),
          const SizedBox(width: 8),
          Text(
            interest.labelAr,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 17,
              color: AppColors.navy,
              fontFamily: 'NotoSansArabic',
            ),
          ),
        ],
      ),
    ),
  ),
),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: keywords.map((kw) {
                                      final selected = temp.contains(kw);

                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            selected
                                                ? temp.remove(kw)
                                                : temp.add(kw);
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: selected
                                                ? const LinearGradient(
                                                    begin:
                                                        Alignment.centerRight,
                                                    end: Alignment.centerLeft,
                                                    colors: [
                                                      AppColors.navy,
                                                      AppColors.accentBlue,
                                                    ],
                                                  )
                                                : null,
                                            color:
                                                selected ? null : Colors.white,
                                            borderRadius:
                                                BorderRadius.circular(99),
                                            border: Border.all(
                                              color: selected
                                                  ? Colors.transparent
                                                  : Colors.grey.shade300,
                                              width: 1.5,
                                            ),
                                          ),
                                          child: Text(
                                            kw,
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              fontFamily: 'NotoSansArabic',
                                              color: selected
                                                  ? Colors.white
                                                  : AppColors.text,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  if (!isLast) ...[
                                    const SizedBox(height: 16),
                                    Divider(
                                      color: Colors.grey.shade200,
                                      height: 1,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                ],
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  _sheetButtons(
                    context: context,
                    count: temp.length,
                    onApply: () => Navigator.pop(context, temp),
                    onClear: () => Navigator.pop(context, <String>{}),
                  ),
                  SizedBox(height: MediaQuery.of(context).viewInsets.bottom),
                ],
              ),
            );
          },
        );
      },
    );

    if (result == null) return;
    result.isEmpty ? historyVM.showAll() : historyVM.applyKeywords(result);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NotificationHistoryVM>();
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final bool offline = vm.isOffline;


  return PopScope(
    canPop: true,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop) {
        await context.read<NotificationHistoryVM>().markAllAsRead();
      }
    },
   child: Scaffold(
      backgroundColor: AppColors.softBg,
      floatingActionButton: Padding(
        padding: EdgeInsets.only(bottom: bottomInset + 8),
        child: FloatingActionButton.extended(
          onPressed: () {
            Navigator.pushNamed(context, '/semantic').then((_) {
              if (!context.mounted) return;
              _refreshSilently();
            });
          },
          backgroundColor: AppColors.navy,
          foregroundColor: Colors.white,
          elevation: 6,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          label: const Text(
            'عرض الكلمات الدلالية',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFamily: 'NotoSansArabic',
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: MadarNavyHeaderClip(
              headerHeight: 110,
              child: const SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      'الإشعارات',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'NotoSansArabic',
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (offline)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: _offlineBanner(
                  'أنت غير متصل بالإنترنت. قد لا تظهر آخر الإشعارات.',
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _pillChip(
                      label: 'الكل',
                      selected: vm.filter == HistoryFilter.all,
                      onTap: vm.showAll,
                      icon: Icons.all_inbox_rounded,
                    ),
                    const SizedBox(width: 8),
                    _pillChip(
                      label: 'طلبات الانضمام',
                      selected: vm.filter == HistoryFilter.joinReq,
                      onTap: vm.setJoinReq,
                      icon: Icons.group_add_rounded,
                    ),
                    const SizedBox(width: 8),
                    _pillChip(
                      label: 'استجابة الطلبات',
                      selected: vm.filter == HistoryFilter.reqReply,
                      onTap: vm.setReqReply,
                      icon: Icons.how_to_reg_rounded,
                    ),
                    const SizedBox(width: 8),
                    _pillChip(
                      label: 'الكلمات الدلالية',
                      selected: vm.filter == HistoryFilter.keyword,
                      onTap: () => _openKeywordsPicker(context),
                      icon: Icons.tag_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: vm.isLoading
                ? const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : vm.items.isEmpty
                    ? SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
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
                                  Icons.notifications_off_rounded,
                                  size: 40,
                                  color: AppColors.navy.withOpacity(0.3),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'لا توجد إشعارات',
                                style: TextStyle(
                                  color: AppColors.text.withOpacity(0.5),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'NotoSansArabic',
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: NotificationTile(item: vm.items[i]),
                          ),
                          childCount: vm.items.length,
                        ),
                      ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 95 + bottomInset)),
        ],
      ),
       ),
    );
  }
}

Widget _sheetButtons({
  required BuildContext context,
  required int count,
  required VoidCallback onApply,
  required VoidCallback onClear,
}) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: onApply,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.navy,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                "تطبيق${count > 0 ? ' ($count)' : ''}",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'NotoSansArabic',
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                ),
              ),
              child: const Text(
                'إزالة التحديد',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                  fontFamily: 'NotoSansArabic',
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
