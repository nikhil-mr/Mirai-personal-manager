import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/widgets/page_container.dart';
import '../../money/data/money_database.dart';
import '../application/places_providers.dart';
import '../domain/places_logic.dart';

class PlaceDetailsScreen extends ConsumerWidget {
  const PlaceDetailsScreen({required this.placeId, super.key});
  final String placeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final places = ref.watch(savedPlacesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Place details')),
      body: PageContainer(
        child: places.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('Could not load place: $error')),
          data: (items) {
            final place = items.where((item) => item.id == placeId).firstOrNull;
            if (place == null) {
              return const Center(child: Text('This place no longer exists.'));
            }
            return _details(context, place);
          },
        ),
      ),
    );
  }

  Widget _details(BuildContext context, SavedPlace place) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      children: [
        Text(place.name, style: theme.textTheme.headlineMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _line(context, 'Category', place.category),
                _line(context, 'Status', _statusLabel(place.status)),
                if (place.address.isNotEmpty)
                  _line(context, 'Address', place.address),
                if (place.latitude != null && place.longitude != null)
                  _line(
                    context,
                    'Coordinates',
                    '${place.latitude}, ${place.longitude}',
                  ),
                if (place.mapUrl.isNotEmpty)
                  _line(context, 'Place link', place.mapUrl),
                if (place.plannedAt != null)
                  _line(
                    context,
                    'Planned visit',
                    DateFormat.yMMMd().format(place.plannedAt!.toLocal()),
                  ),
                if (place.visitedAt != null)
                  _line(
                    context,
                    'Visited',
                    DateFormat.yMMMd().format(place.visitedAt!.toLocal()),
                  ),
                if (place.rating != null)
                  _line(
                    context,
                    'Rating',
                    '${'★' * place.rating!} (${place.rating}/5)',
                  ),
                if (place.notes.isNotEmpty)
                  _line(context, 'Notes', place.notes),
                if (place.review.isNotEmpty)
                  _line(context, 'Review', place.review),
                _line(
                  context,
                  'Added',
                  DateFormat.yMMMd().format(place.createdAt.toLocal()),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _visit(context, place),
          icon: const Icon(Icons.directions_outlined),
          label: const Text('Visit'),
        ),
      ],
    );
  }

  Widget _line(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        SelectableText(value),
      ],
    ),
  );

  String _statusLabel(String value) => switch (value) {
    'visited' => 'Visited',
    'skipped' => 'Skipped',
    _ => 'Planned',
  };

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
}
