import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:meeple_hearth/core/constants/app_colors.dart';
import 'package:meeple_hearth/core/constants/app_spacing.dart';
import 'package:meeple_hearth/core/constants/app_typography.dart';
import 'package:meeple_hearth/features/auth/presentation/widgets/auth_text_field.dart';
import 'package:meeple_hearth/features/events/data/event_repository.dart';
import 'package:meeple_hearth/shared/widgets/app_button.dart';
import 'package:omni_datetime_picker/omni_datetime_picker.dart';

class CreateEventScreen extends ConsumerStatefulWidget {
  const CreateEventScreen({super.key});

  @override
  ConsumerState<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends ConsumerState<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _locationDetailsController = TextEditingController();
  final _maxAttendeesController = TextEditingController();

  DateTime? _startTime;
  DateTime? _endTime;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _locationDetailsController.dispose();
    _maxAttendeesController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final picked = await showOmniDateTimePicker(
      context: context,
      initialDate: _startTime ?? DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startTime = picked);
  }

  Future<void> _pickEndTime() async {
    final initial = _endTime ??
        (_startTime != null
            ? _startTime!.add(const Duration(hours: 3))
            : DateTime.now().add(const Duration(days: 1, hours: 3)));
    final picked = await showOmniDateTimePicker(
      context: context,
      initialDate: initial,
      firstDate: _startTime ?? DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _endTime = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a start time.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final maxAttendees = _maxAttendeesController.text.trim().isEmpty
          ? null
          : int.tryParse(_maxAttendeesController.text.trim());

      await ref.read(eventRepositoryProvider).createEvent(
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            startTime: _startTime!,
            endTime: _endTime,
            location: _locationController.text.trim(),
            locationDetails: _locationDetailsController.text.trim().isEmpty
                ? null
                : _locationDetailsController.text.trim(),
            maxAttendees: maxAttendees,
          );

      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text('Create Event', style: AppTypography.titleMedium),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.pagePadding,
          children: [
            AuthTextField(
              label: 'Title',
              hint: 'Board Game Night at The Pub',
              controller: _titleController,
              prefixIcon: Icons.event_rounded,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            AppSpacing.vGapMd,
            AuthTextField(
              label: 'Description',
              hint: 'What will you play? Who should come?',
              controller: _descriptionController,
              prefixIcon: Icons.description_outlined,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            AppSpacing.vGapMd,
            AuthTextField(
              label: 'Location',
              hint: 'The Catan Café, 42 Board Street',
              controller: _locationController,
              prefixIcon: Icons.location_on_outlined,
              textInputAction: TextInputAction.next,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            AppSpacing.vGapMd,
            AuthTextField(
              label: 'Location details (optional)',
              hint: 'Room 2, ring the bell on arrival',
              controller: _locationDetailsController,
              prefixIcon: Icons.info_outline_rounded,
              textInputAction: TextInputAction.next,
            ),
            AppSpacing.vGapXl,
            Text('Date & Time', style: AppTypography.titleMedium),
            AppSpacing.vGapMd,
            _DateTimePickerTile(
              label: 'Start time',
              value: _startTime,
              onTap: _pickStartTime,
              required: true,
            ),
            AppSpacing.vGapSm,
            _DateTimePickerTile(
              label: 'End time (optional)',
              value: _endTime,
              onTap: _pickEndTime,
            ),
            AppSpacing.vGapXl,
            Text('Capacity (optional)', style: AppTypography.titleMedium),
            AppSpacing.vGapMd,
            AuthTextField(
              label: 'Max attendees',
              hint: 'Leave blank for unlimited',
              controller: _maxAttendeesController,
              prefixIcon: Icons.people_outline_rounded,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = int.tryParse(v.trim());
                if (n == null || n < 1) return 'Enter a valid number';
                return null;
              },
            ),
            AppSpacing.vGapXxl,
            AppButton(
              label: 'Create Event',
              onPressed: _isSubmitting ? null : _submit,
              isLoading: _isSubmitting,
            ),
            AppSpacing.vGapXl,
          ],
        ),
      ),
    );
  }
}

class _DateTimePickerTile extends StatelessWidget {
  const _DateTimePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
    this.required = false,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final hasValue = value != null;
    return InkWell(
      onTap: onTap,
      borderRadius: AppSpacing.borderRadiusMd,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainer,
          borderRadius: AppSpacing.borderRadiusMd,
        ),
        child: Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              size: 20,
              color: hasValue ? AppColors.primary : AppColors.onSurfaceVariant,
            ),
            AppSpacing.hGapMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    hasValue
                        ? _format(value!)
                        : required
                            ? 'Tap to select *'
                            : 'Tap to select',
                    style: AppTypography.bodyMedium.copyWith(
                      color: hasValue
                          ? AppColors.onSurface
                          : AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _format(DateTime dt) {
    final date = '${dt.day}/${dt.month}/${dt.year}';
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$date  $hour:$min';
  }
}
