import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

/// Soft white surface used as the base for all web console cards.
class WebCard extends StatelessWidget {
  const WebCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.webSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor ?? AppColors.webBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Section header used above panels (title + optional trailing action).
class WebSectionHeader extends StatelessWidget {
  const WebSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.lexend(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.webInk,
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: GoogleFonts.lexend(
                      fontSize: 12,
                      color: AppColors.webInkMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Large soft pastel hero card used at the top of a dashboard.
/// Shows a title, supporting line and an optional pill stat, with a friendly
/// decorative cluster of soft circles to keep it kid-friendly.
class WebHeroCard extends StatelessWidget {
  const WebHeroCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.tag,
    this.tint = AppColors.tintLavender,
    this.accent = AppColors.hueLavender,
    this.illustrationEmoji = '🌈',
  });

  final String title;
  final String subtitle;
  final String? tag;
  final Color tint;
  final Color accent;
  final String illustrationEmoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 24, 24, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint, Colors.white.withValues(alpha: 0.5)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            right: -10,
            top: -30,
            child: _SoftBlob(color: accent.withValues(alpha: 0.18), size: 140),
          ),
          Positioned(
            right: 60,
            bottom: -30,
            child: _SoftBlob(color: accent.withValues(alpha: 0.10), size: 90),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tag != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          tag!,
                          style: GoogleFonts.lexend(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: accent,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    if (tag != null) const SizedBox(height: 12),
                    Text(
                      title,
                      style: GoogleFonts.lexend(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.webInk,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        color: AppColors.webInkMuted,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: accent.withValues(alpha: 0.3),
                  ),
                ),
                child: Center(
                  child: Text(
                    illustrationEmoji,
                    style: const TextStyle(fontSize: 38),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SoftBlob extends StatelessWidget {
  const _SoftBlob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Compact pastel stat tile used in a 4-up grid on the dashboard.
class WebStatTile extends StatefulWidget {
  const WebStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
    required this.hue,
    this.helper,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? helper;
  final Color tint;
  final Color hue;
  final VoidCallback? onTap;

  @override
  State<WebStatTile> createState() => _WebStatTileState();
}

class _WebStatTileState extends State<WebStatTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.webSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hover ? widget.hue.withValues(alpha: 0.4) : AppColors.webBorder,
            ),
            boxShadow: [
              BoxShadow(
                color: _hover
                    ? widget.hue.withValues(alpha: 0.12)
                    : const Color(0x0A000000),
                blurRadius: _hover ? 18 : 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.hue, size: 22),
              ),
              const SizedBox(height: 18),
              Text(
                widget.value,
                style: GoogleFonts.lexend(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: AppColors.webInk,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.label,
                style: GoogleFonts.lexend(
                  fontSize: 12,
                  color: AppColors.webInkMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.helper != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: widget.tint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    widget.helper!,
                    style: GoogleFonts.lexend(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: widget.hue,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Responsive grid that lays out tiles as 4-up on wide, 2-up on narrow.
class WebStatGrid extends StatelessWidget {
  const WebStatGrid({super.key, required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final crossAxis = c.maxWidth >= 900 ? 4 : (c.maxWidth >= 600 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossAxis,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.25,
          children: tiles,
        );
      },
    );
  }
}

/// Action tile used in the "Quick actions" row — pastel tinted, friendly icon.
class WebActionTile extends StatefulWidget {
  const WebActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.tint,
    required this.hue,
    required this.onTap,
    this.helper,
  });

  final IconData icon;
  final String label;
  final String? helper;
  final Color tint;
  final Color hue;
  final VoidCallback onTap;

  @override
  State<WebActionTile> createState() => _WebActionTileState();
}

class _WebActionTileState extends State<WebActionTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            color: _hover ? widget.tint : AppColors.webSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: _hover
                  ? widget.hue.withValues(alpha: 0.35)
                  : AppColors.webBorder,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.tint,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(widget.icon, color: widget.hue, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.label,
                      style: GoogleFonts.lexend(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.webInk,
                      ),
                    ),
                    if (widget.helper != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.helper!,
                        style: GoogleFonts.lexend(
                          fontSize: 11,
                          color: AppColors.webInkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 16,
                color: widget.hue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grid laying out action tiles (responsive 3/2/1).
class WebActionGrid extends StatelessWidget {
  const WebActionGrid({super.key, required this.tiles});
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final crossAxis = c.maxWidth >= 900 ? 3 : (c.maxWidth >= 600 ? 2 : 1);
        return GridView.count(
          crossAxisCount: crossAxis,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          childAspectRatio: 3.6,
          children: tiles,
        );
      },
    );
  }
}

/// Tiny inline empty-state shown inside a panel.
class WebEmptyState extends StatelessWidget {
  const WebEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.compact = false,
  });

  final IconData icon;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 16 : 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 28 : 36, color: AppColors.webBorder),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.lexend(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.webInkMuted,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
