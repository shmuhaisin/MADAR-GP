import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model/notifications_model.dart';
import '../../../common_theme/ui/app_colors.dart';
import '../../news/models/article_model.dart';
import '../../news/views/article_detail_screen.dart';
import '../../shared_collections/views/join_requests_screen.dart';
import '../../shared_collections/viewmodel/shared_collections_details_vm.dart';

class NotificationTile extends StatelessWidget {
  final NotificationModel item;

  const NotificationTile({super.key, required this.item});

  void _openDetails(BuildContext context, NotificationModel item) {
    final article = ArticleModel(
      id: item.newsID!,
      newsTitle: '',
      newsContent: '',
      newsSource: '',
      sourceLink: '',
      category: '',
      publishDate: DateTime.now(),
      ttsAudioURLforContent: '',
      ttsAudioURLforSummary: '',
      summaryText: '',
      reportsCount: 0,
    );

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
    );
  }

  void _openJoinRequests(BuildContext context, NotificationModel item) {
    if (item.collectionId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (_) =>
              OwnedCollectionDetailsViewModel(collectionId: item.collectionId!),
          child: const JoinRequestsScreen(),
        ),
      ),
    );
  }

  Color _typeColor(NotificationModel n) {
    switch (n.type) {
      case NotifType.joinReq:
        return const Color(0xFFE9A32C);
      case NotifType.reqReply:
        if (n.status == "accepted") return const Color(0xFF4CAF50);
        if (n.status == "rejected") return const Color(0xFFE53935);
        return const Color(0xFF273D68);
      case NotifType.semantic:
        return const Color(0xFF273D68);
    }
  }

  IconData _iconData(NotificationModel n) {
    switch (n.type) {
      case NotifType.joinReq:
        return Icons.group_add_rounded;
      case NotifType.reqReply:
        if (n.status == "accepted") return Icons.how_to_reg_rounded;
        if (n.status == "rejected") return Icons.person_off_rounded;
        return Icons.notifications_rounded;
      case NotifType.semantic:
        return Icons.notifications_rounded;
    }
  }

  String _typeLabel(NotificationModel n) {
    switch (n.type) {
      case NotifType.joinReq:
        return "طلبات الانضمام";
      case NotifType.reqReply:
        return "استجابة الطلبات";
      case NotifType.semantic:
        return "إشعار دلالي";
    }
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return "$dd/$mm/$yyyy";
  }

  @override
  Widget build(BuildContext context) {
    final title = item.title;
    final message = item.message;
    final date = _formatDate(item.date);
    final bool isRead = item.isRead;
    final bool showDetails = item.type == NotifType.semantic;
    final bool showJoinReq = item.type == NotifType.joinReq;
    final typeColor = _typeColor(item);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              blurRadius: 20,
              offset: const Offset(0, 10),
              color: Colors.black.withOpacity(0.10),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: typeColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(_iconData(item), color: typeColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E2C46),
                            ),
                          ),
                        ),
                        if (!isRead) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              "جديد",
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.softBg,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: AppColors.divider, width: 1),
                      ),
                      child: Text(
                        _typeLabel(item),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.navy,
                          fontFamily: 'NotoSansArabic',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (showDetails)
                      const Text(
                        "لمزيد من التفاصيل اضغط عرض",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.subText,
                        ),
                      ),                     
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          size: 17,
                          color: AppColors.subText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          date,
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppColors.subText,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        if (showDetails)
                          ElevatedButton(
                            onPressed: () => _openDetails(context, item),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.navy,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 13,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 5,
                              shadowColor: Colors.black.withOpacity(0.35),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  "عرض",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                SizedBox(width: 5),
                                Icon(Icons.chevron_right, size: 17),
                              ],
                            ),
                          ),
                          if (showJoinReq)  // ← أضف هذا
  ElevatedButton(
    onPressed: () => _openJoinRequests(context, item),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      elevation: 5,
      shadowColor: Colors.black.withOpacity(0.35),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Text("عرض", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        SizedBox(width: 5),
        Icon(Icons.chevron_right, size: 17),
      ],
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
      ),
    );
  }
}
