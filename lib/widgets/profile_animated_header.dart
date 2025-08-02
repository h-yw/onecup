import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileAnimatedHeader extends StatelessWidget {
  final double scrollProgress;
  final User user;
  final String displayName;
  final String? avatarUrl;

  const ProfileAnimatedHeader({
    super.key,
    required this.scrollProgress,
    required this.user,
    required this.displayName,
    this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final double topPadding = MediaQuery.of(context).padding.top;
    final double collapsedHeight = kToolbarHeight;
    const double expandedHeight = 220.0 - 80;

    final baseExpandedStyle = theme.textTheme.headlineSmall ?? const TextStyle();
    final baseCollapsedStyle = theme.appBarTheme.titleTextStyle ?? const TextStyle();
    final expandedStyle = baseExpandedStyle.copyWith(inherit: false);
    final collapsedStyle = baseCollapsedStyle.copyWith(inherit: false);

    final double avatarStartSize = 80.0;
    final double avatarEndSize = 36.0;
    final double avatarStartTop = 40.0;
    final double avatarEndTop = topPadding + (collapsedHeight - avatarEndSize) / 2;
    final double avatarStartLeft = (MediaQuery.of(context).size.width - avatarStartSize) / 2;
    final double avatarEndLeft = 16.0;

    final double titleStartTop = avatarStartTop + avatarStartSize + 8;
    final double titleEndTop = topPadding;
    final double titleStartLeft = 0;
    final double titleEndLeft = avatarEndLeft + avatarEndSize + 12;

    final double currentAvatarSize = lerpDouble(avatarStartSize, avatarEndSize, 1 - scrollProgress)!;
    final double currentAvatarTop = lerpDouble(avatarStartTop, avatarEndTop, 1 - scrollProgress)!;
    final double currentAvatarLeft = lerpDouble(avatarStartLeft, avatarEndLeft, 1 - scrollProgress)!;
    final double currentTitleTop = lerpDouble(titleStartTop, titleEndTop, 1 - scrollProgress)!;
    final double currentTitleLeft = lerpDouble(titleStartLeft, titleEndLeft, 1 - scrollProgress)!;
    final double currentTitleContainerWidth = lerpDouble(MediaQuery.of(context).size.width, MediaQuery.of(context).size.width - titleEndLeft - 16, 1 - scrollProgress)!;

    Widget avatarWidget;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      avatarWidget = CircleAvatar(
        radius: currentAvatarSize / 2,
        backgroundImage: NetworkImage(avatarUrl!),
        backgroundColor: theme.primaryColor.withOpacity(0.1),
      );
    } else {
      avatarWidget = CircleAvatar(
        radius: currentAvatarSize / 2,
        backgroundColor: theme.primaryColor.withOpacity(0.1),
        child: Icon(Icons.person_outline, size: currentAvatarSize * 0.5, color: theme.primaryColor),
      );
    }

    return Stack(
      children: [
        Positioned(
          top: currentAvatarTop,
          left: currentAvatarLeft,
          child:  avatarWidget,
        ),
        Positioned(
          top: currentTitleTop,
          left: currentTitleLeft,
          width: currentTitleContainerWidth,
          height: kToolbarHeight,
          child: Row(
            mainAxisAlignment: scrollProgress > 0.5 ? MainAxisAlignment.center : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  displayName,
                  style: TextStyle.lerp(expandedStyle, collapsedStyle, 1 - scrollProgress),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
