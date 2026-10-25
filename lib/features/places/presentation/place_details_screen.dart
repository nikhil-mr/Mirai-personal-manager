import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/page_container.dart';
import '../../money/data/money_database.dart';
import '../application/places_providers.dart';
import '../domain/places_logic.dart';
import 'places_screen.dart';

class PlaceDetailsScreen extends ConsumerWidget {
  const PlaceDetailsScreen({required this.placeId, super.key});
  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final places = ref.watch(savedPlacesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Place Details'),
        actions: [
          IconButton(
            tooltip: 'Delete place',
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () => _confirmDelete(context, ref, placeId),
          ),
        ],
      ),
      body: PageContainer(
        child: places.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Could not load place details: $error')),
          data: (items) {
            final place = items.where((item) => item.id == placeId).firstOrNull;
            if (place == null) {
              return const Center(child: Text('This place no longer exists.'));
            }
            return _buildDetails(context, ref, place, isDark);
          },
        ),
      ),
    );
  }

  Widget _buildDetails(
    BuildContext context,
    WidgetRef ref,
    SavedPlace place,
    bool isDark,
  ) {
    final statusColor = switch (place.status) {
      'visited' => AppColors.success,
      'skipped' => AppColors.pink,
      _ => AppColors.brand,
    };

    final statusLabel = switch (place.status) {
      'visited' => 'Visited',
      'skipped' => 'Skipped',
      _ => 'Planned',
    };

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        // Name & Category/Status Badges
        Text(
          place.name,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              backgroundColor: AppColors.brand.withValues(alpha: 0.2),
              side: const BorderSide(color: AppColors.brand, width: 1.5),
              avatar: const Icon(Icons.place, size: 16, color: AppColors.brand),
              label: Text(
                place.category,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            Chip(
              backgroundColor: statusColor.withValues(alpha: 0.2),
              side: BorderSide(color: statusColor, width: 1.5),
              avatar: Icon(
                Icons.check_circle_outline,
                size: 16,
                color: statusColor,
              ),
              label: Text(
                statusLabel,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: statusColor,
                ),
              ),
            ),
            if (place.rating != null)
              Chip(
                backgroundColor: AppColors.brand.withValues(alpha: 0.2),
                side: const BorderSide(color: AppColors.brand, width: 1.5),
                avatar: const Icon(
                  Icons.star,
                  size: 16,
                  color: AppColors.brand,
                ),
                label: Text(
                  '${place.rating} / 5',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Main Details Card
        BrutalCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (place.address.isNotEmpty) ...[
                _buildDetailRow(
                  context,
                  'Address',
                  place.address,
                  Icons.location_on_outlined,
                  isDark,
                ),
                const SizedBox(height: 14),
              ],
              if (place.mapUrl.isNotEmpty) ...[
                _buildDetailRow(
                  context,
                  'Place Link',
                  place.mapUrl,
                  Icons.link_outlined,
                  isDark,
                ),
                const SizedBox(height: 14),
              ],
              if (place.plannedAt != null) ...[
                _buildDetailRow(
                  context,
                  'Planned Visit',
                  DateFormat.yMMMd().format(place.plannedAt!.toLocal()),
                  Icons.event_outlined,
                  isDark,
                ),
                const SizedBox(height: 14),
              ],
              if (place.visitedAt != null) ...[
                _buildDetailRow(
                  context,
                  'Visited On',
                  DateFormat.yMMMd().format(place.visitedAt!.toLocal()),
                  Icons.event_available_outlined,
                  isDark,
                ),
                const SizedBox(height: 14),
              ],
              if (place.notes.isNotEmpty) ...[
                _buildDetailRow(
                  context,
                  'Notes',
                  place.notes,
                  Icons.notes_outlined,
                  isDark,
                ),
                const SizedBox(height: 14),
              ],
              if (place.review.isNotEmpty) ...[
                _buildDetailRow(
                  context,
                  'Personal Review',
                  place.review,
                  Icons.rate_review_outlined,
                  isDark,
                ),
                const SizedBox(height: 14),
              ],
              _buildDetailRow(
                context,
                'Added Date',
                DateFormat.yMMMd().format(place.createdAt.toLocal()),
                Icons.calendar_today_outlined,
                isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons Row
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: AppColors.lightText,
                ),
                onPressed: () => _visit(context, place),
                icon: const Icon(Icons.directions_outlined),
                label: const Text('Visit'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => showAddOrEditPlaceForm(context, ref, place),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ),
            const SizedBox(width: 10),
            IconButton.filledTonal(
              tooltip: 'Share place',
              onPressed: () => _share(context, place),
              icon: const Icon(Icons.share_outlined),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark
              ? AppColors.darkSecondaryText
              : AppColors.lightSecondaryText,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.darkSecondaryText
                      : AppColors.lightSecondaryText,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _visit(BuildContext context, SavedPlace place) async {
    final uri = placeVisitUri(
      name: place.name,
      address: place.address,
      mapUrl: place.mapUrl,
      latitude: place.latitude,
      longitude: place.longitude,
    );
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this place in Google Maps.'),
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open this place in Google Maps.'),
          ),
        );
      }
    }
  }

  Future<void> _share(BuildContext context, SavedPlace place) async {
    final textBuffer = StringBuffer();
    textBuffer.write(place.name);
    if (place.address.isNotEmpty) {
      textBuffer.write('\nAddress: ${place.address}');
    }
    if (place.mapUrl.isNotEmpty) {
      textBuffer.write('\n${place.mapUrl}');
    }

    final shareText = textBuffer.toString();
    final uri = Uri.parse(
      'mailto:?subject=${Uri.encodeComponent(place.name)}&body=${Uri.encodeComponent(shareText)}',
    );

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Share: $shareText')));
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String placeId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Place?'),
        content: const Text(
          'Are you sure you want to delete this saved place?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(placesRepositoryProvider).deletePlace(placeId);
      if (context.mounted) Navigator.pop(context);
    }
  }
}
