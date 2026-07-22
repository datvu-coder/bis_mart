import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// App-wide pill-style tab selector with equal-width segments and a
/// sliding highlight. Used at every screen size (not just desktop) so the
/// tab-switch feel — the thing users notice most while navigating — is
/// the same everywhere, instead of falling back to a scrollable
/// [TabBar] on mobile that never quite filled its pill-shaped background.
///
/// The highlight tracks [TabController.animation] rather than
/// [TabController.index], so it slides continuously while the user swipes
/// the [TabBarView] (not just on tap), matching the swipe 1:1.
class WeightedTabSelector extends StatelessWidget {
  final TabController controller;
  final List<String> labels;
  final List<int>? flexes;

  const WeightedTabSelector({
    super.key,
    required this.controller,
    required this.labels,
    this.flexes,
  });

  List<int> _defaultFlexes() => List<int>.filled(labels.length, 1);

  @override
  Widget build(BuildContext context) {
    final f = flexes ?? _defaultFlexes();
    final totalFlex = f.fold<int>(0, (a, b) => a + b);
    // Cumulative flex fraction at the start of each segment, e.g. for 4
    // equal segments: [0, 0.25, 0.5, 0.75, 1.0].
    final starts = <double>[0];
    for (final flex in f) {
      starts.add(starts.last + flex / totalFlex);
    }

    return AnimatedBuilder(
      animation: controller.animation ?? controller,
      builder: (context, _) {
        final value = (controller.animation?.value ?? controller.index.toDouble())
            .clamp(0, labels.length - 1)
            .toDouble();
        final i = value.floor();
        final frac = value - i;
        final nextI = (i + 1).clamp(0, labels.length - 1);
        final left = starts[i] + (starts[nextI] - starts[i]) * frac;
        final width = (f[i] / totalFlex) + ((f[nextI] / totalFlex) - (f[i] / totalFlex)) * frac;

        // With 5+ equal-width segments, long Vietnamese labels ("Chấm công",
        // "Giờ công"...) don't fit on one line at the default size — shrink
        // the font and let them wrap to a 2nd line instead of silently
        // ellipsizing into unreadable "Chấm ...", "Giờ cô..." fragments.
        final isDense = labels.length >= 5;
        final fontSize = isDense ? 11.5 : 13.0;
        final height = isDense ? 44.0 : 40.0;

        return LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            return SizedBox(
              height: height,
              child: Stack(
                children: [
                  Positioned(
                    left: left * totalWidth,
                    width: width * totalWidth,
                    top: 0,
                    bottom: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.shadow,
                              blurRadius: 6,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: List.generate(labels.length, (idx) {
                      final selected = controller.index == idx;
                      return Expanded(
                        flex: idx < f.length ? f[idx] : 1,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          onTap: () => controller.animateTo(idx),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              labels[idx],
                              textAlign: TextAlign.center,
                              maxLines: isDense ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: fontSize,
                                height: 1.1,
                                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                color: selected ? AppColors.primary : AppColors.textGrey,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
