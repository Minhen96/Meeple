import 'package:flutter/material.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/shared/widgets/empty_state.dart';

/// Search screen — Phase 1 stub.
///
/// Full implementation searches users, games, and events in one unified bar.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _SearchAppBar(
        controller: _controller,
        onChanged: (q) => setState(() => _query = q),
        onClose: () => Navigator.of(context).pop(),
      ),
      body: _query.isEmpty ? const _SearchPrompt() : const _SearchResults(),
    );
  }
}

class _SearchAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _SearchAppBar({
    required this.controller,
    required this.onChanged,
    required this.onClose,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: TextField(
        controller: controller,
        autofocus: true,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: AppTypography.bodyLarge,
        decoration: InputDecoration(
          hintText: 'Search games, people, events…',
          hintStyle: AppTypography.bodyLarge.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.onSurfaceVariant,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) => value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    color: AppColors.onSurfaceVariant,
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: onClose,
          child: Text(
            'Cancel',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SearchPrompt extends StatelessWidget {
  const _SearchPrompt();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: AppSpacing.pagePadding,
      children: [
        AppSpacing.vGapLg,
        Text('Search by', style: AppTypography.titleMedium),
        AppSpacing.vGapMd,
        _SearchCategoryChip(
          icon: Icons.casino_rounded,
          label: 'Games',
        ),
        AppSpacing.vGapSm,
        _SearchCategoryChip(
          icon: Icons.person_outline_rounded,
          label: 'People',
        ),
        AppSpacing.vGapSm,
        _SearchCategoryChip(
          icon: Icons.event_outlined,
          label: 'Events',
        ),
      ],
    );
  }
}

class _SearchCategoryChip extends StatelessWidget {
  const _SearchCategoryChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppSpacing.borderRadiusMd,
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: AppColors.onSurfaceVariant),
            AppSpacing.hGapMd,
            Text(label, style: AppTypography.bodyLarge),
          ],
        ),
      ),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.search_off_rounded,
      title: 'No results',
      subtitle: 'Try a different search term.',
    );
  }
}
