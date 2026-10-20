import 'package:flutter/material.dart';
import 'package:memora/core/theme/app_theme.dart';
import 'package:memora/core/theme/app_colors.dart';

// ── AppButton ──────────────────────────────────────────────────────────────

enum AppButtonVariant { primary, secondary, danger, large }

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final bool isLoading;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          )
        : icon != null
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 20),
                  const SizedBox(width: 8),
                  Text(label),
                ],
              )
            : Text(label);

    switch (variant) {
      case AppButtonVariant.danger:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.error,
            foregroundColor: AppColors.white,
            minimumSize: const Size(0, 56),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
          ),
          child: child,
        );
      case AppButtonVariant.secondary:
        return OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
      case AppButtonVariant.large:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: AppColors.white,
            minimumSize: const Size(0, 56),
            textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusButton)),
          ),
          child: child,
        );
      case AppButtonVariant.primary:
        return ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          child: child,
        );
    }
  }
}

// ── AppCard ────────────────────────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final Color? color;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Container(
          padding: padding ?? const EdgeInsets.all(AppTheme.sp16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            boxShadow: AppTheme.cardShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── StatusChip ────────────────────────────────────────────────────────────

enum StatusChipType { safe, warning, danger, neutral, info }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusChipType type;

  const StatusChip({super.key, required this.label, this.type = StatusChipType.neutral});

  Color get _bg {
    switch (type) {
      case StatusChipType.safe:    return AppTheme.success.withOpacity(0.12);
      case StatusChipType.warning: return AppTheme.warning.withOpacity(0.12);
      case StatusChipType.danger:  return AppTheme.errorSurface;
      case StatusChipType.info:    return AppTheme.primary.withOpacity(0.12);
      case StatusChipType.neutral: return AppTheme.surfaceVar;
    }
  }

  Color get _fg {
    switch (type) {
      case StatusChipType.safe:    return AppTheme.success;
      case StatusChipType.warning: return AppTheme.warning;
      case StatusChipType.danger:  return AppTheme.error;
      case StatusChipType.info:    return AppTheme.primary;
      case StatusChipType.neutral: return AppTheme.onSurfaceMid;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(AppTheme.radiusChip)),
      child: Text(
        label,
        style: TextStyle(color: _fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── SectionHeader ─────────────────────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurfaceMid,
              letterSpacing: 0.5,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ── EmptyState ────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppTheme.onSurfaceLow),
            const SizedBox(height: AppTheme.sp16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppTheme.sp8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppTheme.sp24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── LoadingView ───────────────────────────────────────────────────────────

class LoadingView extends StatelessWidget {
  final String? message;
  const LoadingView({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          if (message != null) ...[
            const SizedBox(height: AppTheme.sp16),
            Text(message!, style: const TextStyle(color: AppTheme.onSurfaceMid)),
          ],
        ],
      ),
    );
  }
}

// ── ErrorView ─────────────────────────────────────────────────────────────

class ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorView({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.sp32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline_rounded, size: 48, color: AppTheme.warning),
            const SizedBox(height: AppTheme.sp16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.sp24),
              AppButton(label: 'Try again', onPressed: onRetry, variant: AppButtonVariant.secondary),
            ],
          ],
        ),
      ),
    );
  }
}

// ── BigTile ───────────────────────────────────────────────────────────────
/// Large tappable tile used on the patient home screen.

class BigTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? color;
  final VoidCallback? onTap;
  final Widget? badge;

  const BigTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.color,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = color ?? AppTheme.primary;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppTheme.sp24),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tileColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: tileColor, size: 28),
          ),
          const SizedBox(width: AppTheme.sp16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
          if (badge != null) badge!,
          const SizedBox(width: AppTheme.sp8),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.onSurfaceLow),
        ],
      ),
    );
  }
}
