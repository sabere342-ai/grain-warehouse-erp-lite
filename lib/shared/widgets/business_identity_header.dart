import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:grain_warehouse_erp_lite/app/app_repositories.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity.dart';
import 'package:grain_warehouse_erp_lite/core/business_identity/business_identity_controller.dart';
import 'package:grain_warehouse_erp_lite/core/theme/app_tokens.dart';

class BusinessIdentityHeader extends StatelessWidget {
  const BusinessIdentityHeader({
    super.key,
    this.identity,
    this.subtitle,
    this.compact = false,
    this.showLogo = true,
  });

  final BusinessIdentity? identity;
  final String? subtitle;
  final bool compact;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    final effectiveIdentity =
        identity ?? BusinessIdentityScope.maybeOf(context)?.identity;
    final displayName =
        effectiveIdentity?.displayName ?? BusinessIdentity.defaultDisplayName;
    final hasLogo = showLogo && (effectiveIdentity?.hasLogo ?? false);
    final logoFileName = effectiveIdentity?.logo?.managedFileName ?? '';
    final theme = Theme.of(context);

    if (compact) {
      return _CompactIdentity(
        displayName: displayName,
        hasLogo: hasLogo,
        logoFileName: logoFileName,
        theme: theme,
      );
    }

    return _StandardIdentity(
      displayName: displayName,
      subtitle: subtitle,
      hasLogo: hasLogo,
      logoFileName: logoFileName,
      theme: theme,
    );
  }
}

class _CompactIdentity extends StatelessWidget {
  const _CompactIdentity({
    required this.displayName,
    required this.hasLogo,
    required this.logoFileName,
    required this.theme,
  });

  final String displayName;
  final bool hasLogo;
  final String logoFileName;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasLogo) ...[
          _IdentityLogo(
            managedFileName: logoFileName,
            maxHeight: AppIconSizes.md,
            maxWidth: AppIconSizes.lg,
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Flexible(
          child: Text(
            displayName,
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StandardIdentity extends StatelessWidget {
  const _StandardIdentity({
    required this.displayName,
    required this.hasLogo,
    required this.logoFileName,
    required this.theme,
    this.subtitle,
  });

  final String displayName;
  final String? subtitle;
  final bool hasLogo;
  final String logoFileName;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasLogo)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _IdentityLogo(
              managedFileName: logoFileName,
              maxHeight: AppIconSizes.hero,
              maxWidth: 120,
            ),
          ),
        Text(
          displayName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _IdentityLogo extends StatelessWidget {
  const _IdentityLogo({
    required this.managedFileName,
    required this.maxHeight,
    required this.maxWidth,
  });

  final String managedFileName;
  final double maxHeight;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _loadBytes(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: maxWidth),
          child: Image.memory(
            snapshot.data!,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  Future<Uint8List?> _loadBytes() async {
    if (managedFileName.isEmpty) return null;
    try {
      return await AppRepositories.businessIdentityRepository
          .loadLogoBytes(managedFileName);
    } catch (_) {
      return null;
    }
  }
}
