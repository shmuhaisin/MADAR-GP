import 'dart:math';
import 'package:flutter/material.dart';
import 'package:madar_app/common_theme/ui/app_colors.dart';

class CollectionsPager<T> extends StatefulWidget {
  final List<T> items;

  final int itemsPerPage;
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  final double itemSpacing;
  final double? height;
  final double? itemHeight;

  final double pageSpacing;

  const CollectionsPager({
    super.key,
    required this.items,
    required this.itemBuilder,
    this.itemsPerPage = 2,
    this.itemSpacing = 5,
    this.pageSpacing = 1,
    this.height,
    this.itemHeight,
  });

  @override
  State<CollectionsPager<T>> createState() => _CollectionsPagerState<T>();
}

class _CollectionsPagerState<T> extends State<CollectionsPager<T>> {
  late final PageController _controller;
  int _pageIndex = 0;

  int get _pageCount => (widget.items.isEmpty)
      ? 0
      : (widget.items.length / widget.itemsPerPage).ceil();

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= _pageCount) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  double _computedHeight() {
    if (widget.height != null) return widget.height!;
    final ih = widget.itemHeight;
    if (ih == null) {

      return (170 * widget.itemsPerPage) + (widget.itemSpacing * (widget.itemsPerPage - 1));
    }
    return (ih * widget.itemsPerPage) + (widget.itemSpacing * (widget.itemsPerPage - 1));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();

    final hasMultiplePages = _pageCount > 1;
    final isFirstPage = _pageIndex == 0;
    final isLastPage = _pageIndex == _pageCount - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _computedHeight(),
          child: PageView.builder(
            controller: _controller,
            itemCount: _pageCount,
            onPageChanged: (i) => setState(() => _pageIndex = i),
            itemBuilder: (context, page) {
              final start = page * widget.itemsPerPage;
              final end = min(start + widget.itemsPerPage, widget.items.length);
              final pageItems = widget.items.sublist(start, end);

              return Padding(
                padding: EdgeInsets.symmetric(horizontal: widget.pageSpacing),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: List.generate(pageItems.length, (i) {
                    final realIndex = start + i;

                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i == pageItems.length - 1 ? 0 : widget.itemSpacing,
                      ),
                      child: widget.itemBuilder(
                        context,
                        pageItems[i],
                        realIndex,
                      ),
                    );
                  }),
                ),
              );
            },
          ),
        ),

        if (hasMultiplePages) ...[
          const SizedBox(height: 6),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Next',
                onPressed: isFirstPage ? null : () => _goTo(_pageIndex - 1),
                icon: const Icon(Icons.chevron_left),
              ),

              _NumberedIndicator(
                count: _pageCount,
                activeIndex: _pageIndex,
                onTap: _goTo,
              ),

              IconButton(
                tooltip: 'Prev',
                onPressed: isLastPage ? null : () => _goTo(_pageIndex + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ],
    );
  }
}



class _NumberedIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;
  final ValueChanged<int> onTap;

  final int maxSlots=4;

  const _NumberedIndicator({
    required this.count,
    required this.activeIndex,
    required this.onTap, 
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 1) return const SizedBox.shrink();

    final tokens = _paginationTokens(
      count: count,
      current: activeIndex,
      maxSlots: maxSlots,
    );

    return Wrap(
      spacing: 8,
      children: tokens.map((t) {
        if (t == -1) return _EllipsisPill();

        final selected = t == activeIndex;
        return InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => onTap(t),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.navy2
                  : AppColors.navy.withOpacity(0.10),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withOpacity(selected ? 0.8 : 0.25),
              ),
            ),
            child: Text(
              '${t + 1}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: selected ? Colors.white : AppColors.text,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  List<int> _paginationTokens({
    required int count,
    required int current,
    required int maxSlots,
  }) {
    if (count <= maxSlots) return List.generate(count, (i) => i);

    final last = count - 1;
    final window = maxSlots - 2;

    int start = current - (window ~/ 2);
    int end = start + window - 1;

    if (start < 1) {
      start = 1;
      end = start + window - 1;
    }
    if (end > last - 1) {
      end = last - 1;
      start = end - window + 1;
    }

    final res = <int>[0];

    if (start > 1) res.add(start == 2 ? 1 : -1);

    for (int i = start; i <= end; i++) {
      res.add(i);
    }

    if (end < last - 1) res.add(end == last - 2 ? last - 1 : -1);

    res.add(last);
    return res;
  }
}

class _EllipsisPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.navy.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: const Text(
        '…',
        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
      ),
    );
  }
}