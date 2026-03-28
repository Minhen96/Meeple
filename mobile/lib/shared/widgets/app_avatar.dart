import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';

/// Circular avatar with CachedNetworkImage + initials fallback.
///
/// Sizes: xs(24) / sm(32) / md(40) / lg(56) / xl(80) / xxl(120)
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    this.imageUrl,
    this.displayName,
    this.size = 40,
    this.showOnlineIndicator = false,
    this.isOnline = false,
    this.onTap,
    this.borderColor,
  });

  final String? imageUrl;
  final String? displayName;
  final double size;
  final bool showOnlineIndicator;
  final bool isOnline;
  final VoidCallback? onTap;
  final Color? borderColor;

  String get _initials {
    if (displayName == null || displayName!.isEmpty) return '?';
    final parts = displayName!.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return displayName![0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          _buildAvatar(),
          if (showOnlineIndicator)
            Positioned(
              bottom: 1,
              right: 1,
              child: _OnlineIndicator(
                isOnline: isOnline,
                size: size * 0.26,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final hasBorder = borderColor != null;

    Widget avatar;
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      avatar = CachedNetworkImage(
        imageUrl: imageUrl!,
        imageBuilder: (context, imageProvider) => CircleAvatar(
          radius: size / 2,
          backgroundImage: imageProvider,
        ),
        placeholder: (context, url) => _InitialsAvatar(
          initials: _initials,
          size: size,
        ),
        errorWidget: (context, url, error) => _InitialsAvatar(
          initials: _initials,
          size: size,
        ),
      );
    } else {
      avatar = _InitialsAvatar(initials: _initials, size: size);
    }

    if (hasBorder) {
      return Container(
        width: size + 4,
        height: size + 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: borderColor!, width: 2),
        ),
        child: avatar,
      );
    }
    return avatar;
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.primaryFixed,
      child: Text(
        initials,
        style: AppTypography.labelLarge.copyWith(
          color: AppColors.onPrimaryFixed,
          fontSize: size * 0.35,
        ),
      ),
    );
  }
}

class _OnlineIndicator extends StatelessWidget {
  const _OnlineIndicator({required this.isOnline, required this.size});

  final bool isOnline;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? AppColors.tertiary : AppColors.surfaceContainerHigh,
        border: Border.all(
          color: AppColors.surfaceContainerLowest,
          width: 1.5,
        ),
      ),
    );
  }
}

extension AppAvatarSizes on AppAvatar {
  static const double xs = 24;
  static const double sm = 32;
  static const double md = 40;
  static const double lg = 56;
  static const double xl = 80;
  static const double xxl = 120;
}
