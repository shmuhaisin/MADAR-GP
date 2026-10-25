import 'package:flutter/material.dart';
import '../../../common_theme/ui/app_colors.dart';
import '../model/collections_models.dart';


class ExploreCollectionCard extends StatelessWidget {
  final ExploreCollectionUiModel model;
  final VoidCallback onView;

  final Future<void> Function() onJoin;

  const ExploreCollectionCard({
    super.key,
    required this.model,
    required this.onView,
    required this.onJoin,
  });

  
  @override
  Widget build(BuildContext context) {
    const radius = 18.0;
    final state = model.joinState;
    final joinCfg = _joinButtonConfig(state);
    final canJoin = state == JoinState.notJoined;

    final desc = model.collectionDescription.trim();
    final owner = (model.ownerUsername ?? '').trim();
    final views = model.numOfViewers ?? 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            blurRadius: 16,
            offset: const Offset(0, 10),
            color: Colors.black.withOpacity(0.10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
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
            Positioned.fill(child: Container(color: Colors.black.withOpacity(0.18))),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.16), width: 1),
                  borderRadius: BorderRadius.circular(radius),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _IconPillButton(
                        icon: Icons.collections_bookmark,
                    
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          model.collectionName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'NotoSansArabic',
                            height: 1.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 34,
                    child: Text(
                      desc,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.92),
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'NotoSansArabic',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _CardOwnerPill(owner: owner)),
                      const SizedBox(width: 6),
                      _CardViewsPill(views: views),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: _MiniButton(
                          label: joinCfg.label,
                          icon: joinCfg.icon,
                          bg: joinCfg.bg,
                       onTap: canJoin ? () async => await onJoin() : null,
                          disabledBg: joinCfg.bg,
                          disabledFg: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _MiniButton(
                          label: 'عرض',
                          icon: Icons.chevron_right,
                          bg: AppColors.navy,
                          onTap: onView,
                          trailingIcon: true,
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
    );
  }

  _JoinCfg _joinButtonConfig(JoinState state) {
    switch (state) {
      case JoinState.notJoined:
        return const _JoinCfg(
          label: 'انضمام',
          icon: Icons.person_add_alt_1,
          bg: Color(0xFF1AA37A),
        );
      case JoinState.requested:
        return const _JoinCfg(
          label: 'تم الطلب',
          icon: Icons.hourglass_top_rounded,
          bg: Color(0xFFF4A322),
        );
    }
  }
}

class _JoinCfg {
  final String label;
  final IconData icon;
  final Color bg;
  const _JoinCfg({required this.label, required this.icon, required this.bg});
}

class _CardOwnerPill extends StatelessWidget {
  final String owner;
  const _CardOwnerPill({required this.owner});

  @override
  Widget build(BuildContext context) {
    if (owner.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999), 
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person, color: Colors.white, size: 15),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              owner,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontFamily: 'NotoSansArabic',
                fontSize: 11.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardViewsPill extends StatelessWidget {
  final int views;
  const _CardViewsPill({required this.views});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.remove_red_eye, color: Colors.white, size: 15),
          const SizedBox(width: 4), 
          Text(
            '$views',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontFamily: 'NotoSansArabic',
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconPillButton extends StatelessWidget {
  final IconData icon;

  const _IconPillButton({required this.icon});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.14),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.16)),
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color bg;
  final VoidCallback? onTap;
  final Color? disabledBg;
  final Color? disabledFg;
  final bool trailingIcon; 

  const _MiniButton({
    required this.label,
    required this.icon,
    required this.bg,
    required this.onTap,
    this.disabledBg,
    this.disabledFg,
    this.trailingIcon = false, 
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = Flexible(
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          fontFamily: 'NotoSansArabic',
        ),
      ),
       
    );

    final iconWidget = Icon(icon, size: 16);

    return SizedBox(
      height: 36, 
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: Colors.white,
          disabledBackgroundColor: disabledBg ?? bg,
          disabledForegroundColor: disabledFg ?? Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 2), 
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.white.withOpacity(0.55), width: 0.66),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: trailingIcon 
            ? [textWidget, const SizedBox(width: 4), iconWidget] 
            : [iconWidget, const SizedBox(width: 4), textWidget], 
        ),
      ),
    );
  }
}
