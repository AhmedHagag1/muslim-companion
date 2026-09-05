import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

class DesignAssetCard extends StatelessWidget {
  const DesignAssetCard({
    super.key,
    required this.asset,
    required this.child,
    this.onTap,
    this.height,
    this.alignment = Alignment.center,
    this.fit = BoxFit.cover,
    this.overlay = const [Color(0xE6092421), Color(0x9910322E)],
    this.semanticLabel,
  });

  final String asset;
  final Widget child;
  final VoidCallback? onTap;
  final double? height;
  final Alignment alignment;
  final BoxFit fit;
  final List<Color> overlay;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    button: onTap != null,
    label: semanticLabel,
    child: Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.large),
        side: BorderSide(color: AppColors.accentGold.withValues(alpha: 0.34)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ExcludeSemantics(
                child: Image.asset(
                  asset,
                  fit: fit,
                  alignment: alignment,
                  filterQuality: FilterQuality.medium,
                  cacheWidth: 900,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: overlay,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: child,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class IllustratedHubTile extends StatelessWidget {
  const IllustratedHubTile({
    super.key,
    required this.asset,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.keyName,
  });

  final String asset;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final String? keyName;

  @override
  Widget build(BuildContext context) => Material(
    key: keyName == null ? null : ValueKey(keyName),
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
    ),
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: Image.asset(
                  asset,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  cacheWidth: 480,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
