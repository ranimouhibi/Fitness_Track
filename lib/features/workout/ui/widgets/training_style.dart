import 'package:flutter/material.dart';
import '../../../../core/media/media_store.dart';
import '../../../../core/theme/app_colors.dart';

/// Shared look for the Training section only.
class TrainStyle {
  static const navy = Color(0xFF0B1E3F);
  static const neon = Color(0xFF5AD8FF);
  static const pageBg = Color(0xFFF3F6FB);
  static const line = Color(0xFFDCE6F5);

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy, AppColors.deepBlue, AppColors.primary],
  );

  static const accent = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [AppColors.primary, neon],
  );

  static const surface = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Colors.white, Color(0xFFEAF2FF)],
  );

  static final softShadow = [
    BoxShadow(
      color: navy.withValues(alpha: 0.06),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];

  static final glowShadow = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.30),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];
}

/// Gradient header bar with back button and action button.
class TrainHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final String actionLabel;
  final VoidCallback onAction;

  const TrainHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 56, 12),
      padding: const EdgeInsets.fromLTRB(8, 10, 10, 10),
      decoration: BoxDecoration(
        gradient: TrainStyle.hero,
        borderRadius: BorderRadius.circular(22),
        boxShadow: TrainStyle.glowShadow,
      ),
      child: Row(
        children: [
          if (onBack != null)
            _CircleIcon(icon: Icons.arrow_back, onTap: onBack!)
          else
            const SizedBox(width: 12),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ActionButton(label: actionLabel, onTap: onAction),
        ],
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 18, color: AppColors.primary),
              const SizedBox(width: 4),
              Text(label,
                  style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

/// White rounded card with soft shadow and optional tap.
class TrainCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  const TrainCard({
    super.key,
    required this.child,
    this.onTap,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: TrainStyle.line),
        boxShadow: TrainStyle.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(12), child: child),
        ),
      ),
    );
  }
}

class TrainSectionTitle extends StatelessWidget {
  final String text;
  const TrainSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              gradient: TrainStyle.accent,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(text,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: TrainStyle.navy)),
        ],
      ),
    );
  }
}

class TrainPill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;

  const TrainPill(
    this.text, {
    super.key,
    this.icon,
    this.color = AppColors.deepBlue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ],
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class TrainStatus extends StatelessWidget {
  final String status;
  const TrainStatus(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('Approved', Colors.green),
      'refused' => ('Refused', Colors.red),
      _ => ('Pending', Colors.orange),
    };
    return TrainPill(label, color: color);
  }
}

class TrainThumb extends StatelessWidget {
  final String? path;
  final double size;
  const TrainThumb({super.key, this.path, this.size = 64});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(width: size, height: size, child: mediaImage(path)),
    );
  }
}

class TrainBadge extends StatelessWidget {
  final int number;
  const TrainBadge(this.number, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        gradient: TrainStyle.accent,
        shape: BoxShape.circle,
      ),
      child: Text('$number',
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
    );
  }
}

class TrainButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const TrainButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        gradient: TrainStyle.accent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: TrainStyle.glowShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TrainChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const TrainChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? TrainStyle.accent : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: selected ? null : Border.all(color: TrainStyle.line),
          boxShadow: selected ? TrainStyle.glowShadow : TrainStyle.softShadow,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class TrainStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const TrainStat({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: TrainStyle.line),
          boxShadow: TrainStyle.softShadow,
        ),
        child: Column(
          children: [
            ShaderMask(
              shaderCallback: (r) => TrainStyle.accent.createShader(r),
              child: Icon(icon, size: 22, color: Colors.white),
            ),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: TrainStyle.navy)),
            const SizedBox(height: 2),
            Text(label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class TrainEmpty extends StatelessWidget {
  final String text;
  const TrainEmpty(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: TrainStyle.navy.withValues(alpha: 0.25)),
            const SizedBox(height: 10),
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}

/// Gradient icon tile used at the start of list cards.
class TrainIconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  const TrainIconTile({super.key, required this.icon, this.size = 52});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: TrainStyle.accent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: TrainStyle.glowShadow,
      ),
      child: Icon(icon, color: Colors.white, size: size * 0.46),
    );
  }
}