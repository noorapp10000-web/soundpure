import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme.dart';

enum StageState { pending, active, done }

class StageItem extends StatelessWidget {
  final String label;
  final StageState state;
  final int index;

  const StageItem({
    super.key,
    required this.label,
    required this.state,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      StageState.done   => kSuccess,
      StageState.active => kAccent,
      StageState.pending => kBorder,
    };

    final icon = switch (state) {
      StageState.done   => Icons.check_circle_rounded,
      StageState.active => Icons.radio_button_checked,
      StageState.pending => Icons.circle_outlined,
    };

    final labelColor = switch (state) {
      StageState.done   => kText,
      StageState.active => kAccent,
      StageState.pending => kTextSub,
    };

    Widget iconWidget = Icon(icon, color: color, size: 22);

    if (state == StageState.active) {
      iconWidget = iconWidget
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: kAccent.withOpacity(0.4));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Connector line
          Column(
            children: [
              if (index > 0)
                Container(width: 2, height: 6,
                    color: state == StageState.pending ? kBorder : color),
            ],
          ),
          const SizedBox(width: 12),
          iconWidget,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontSize: 13,
                fontWeight: state == StageState.active
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
