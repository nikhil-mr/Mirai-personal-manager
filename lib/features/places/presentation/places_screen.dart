import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_container.dart';
import '../../money/application/money_providers.dart';
import '../../money/data/money_database.dart';
import '../../money/domain/money_models.dart';
import '../application/places_providers.dart';
import '../domain/places_logic.dart';

class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({this.quickAdd, super.key});
  final String? quickAdd;
  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  int _section = 0;
  String _query = '';
  String _category = 'All';
  String _visitStatus = 'All';
  String _placeSort = 'Recently added';
  String _tripStatus = 'All';
  String _tripSort = 'Start date';
  DateTimeRange? _tripDateRange;

  @override
  void initState() {
    super.initState();
    if (widget.quickAdd != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.quickAdd) {
          case 'place':
            _editPlace();
          case 'trip':
            _editTrip();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(savedPlacesProvider);
    final tripsAsync = ref.watch(tripsProvider);
    final places = placesAsync.asData?.value ?? const <SavedPlace>[];
    final trips = tripsAsync.asData?.value ?? const <TravelTrip>[];
    final categories = places.map((p) => p.category).toSet().toList()..sort();
    if (_category != 'All' && !categories.contains(_category)) {
      _category = 'All';
    }
    final visiblePlaces =
        places.where((p) {
          final matchesStatus =
              _visitStatus == 'All' || p.status == _visitStatus.toLowerCase();
          final matchesCategory = _category == 'All' || p.category == _category;
          final q = _query.trim().toLowerCase();
          return matchesStatus &&
              matchesCategory &&
              (q.isEmpty ||
                  '${p.name} ${p.address} ${p.notes} ${p.category}'
                      .toLowerCase()
                      .contains(q));
        }).toList()..sort(
          (a, b) => switch (_placeSort) {
            'Name' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            'Planned date' => _nullableDateCompare(a.plannedAt, b.plannedAt),
            'Recently visited' => _nullableDateDescendingCompare(
              a.visitedAt,
              b.visitedAt,
            ),
            _ => b.createdAt.compareTo(a.createdAt),
          },
        );
    final recentlyVisited =
        places
            .where((p) => p.status == 'visited' && p.visitedAt != null)
            .toList()
          ..sort((a, b) => b.visitedAt!.compareTo(a.visitedAt!));
    final visibleTrips =
        trips.where((t) {
          final matchesStatus =
              _tripStatus == 'All' || t.status == _tripStatus.toLowerCase();
          final range = _tripDateRange;
          final tripStart = t.startAt ?? t.endAt;
          final tripEnd = t.endAt ?? t.startAt;
          final matchesDate =
              range == null ||
              (tripStart != null && !tripStart.isAfter(range.end)) &&
                  (tripEnd != null && !tripEnd.isBefore(range.start));
          final q = _query.trim().toLowerCase();
          return matchesStatus &&
              matchesDate &&
              (q.isEmpty ||
                  '${t.name} ${t.destination} ${t.description}'
                      .toLowerCase()
                      .contains(q));
        }).toList()..sort(
          (a, b) => switch (_tripSort) {
            'Name' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            _ => _nullableDateCompare(a.startAt, b.startAt),
          },
        );

    return PageContainer(
      child: ListView(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Places & Trips',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Save destinations and plan the journey.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (_section == 0)
                FilledButton.icon(
                  onPressed: () => _editPlace(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add place'),
                )
              else
                FilledButton.icon(
                  onPressed: () => _editTrip(),
                  icon: const Icon(Icons.add),
                  label: const Text('New trip'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Saved Places'),
                icon: Icon(Icons.place_outlined),
              ),
              ButtonSegment(
                value: 1,
                label: Text('My Trips'),
                icon: Icon(Icons.luggage_outlined),
              ),
            ],
            selected: {_section},
            onSelectionChanged: (value) => setState(() {
              _section = value.first;
              _query = '';
            }),
          ),
          const SizedBox(height: 14),
          TextField(
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: _section == 0
                  ? 'Search places, addresses, notes'
                  : 'Search trips and destinations',
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _query = ''),
                    ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 10),
          if (_section == 0) ...[
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final value in ['All', ...categories])
                  ChoiceChip(
                    label: Text(value),
                    selected: _category == value,
                    onSelected: (_) => setState(() => _category = value),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            _FilterDropdown(
              value: _visitStatus,
              label: 'Visit status',
              values: const ['All', 'Planned', 'Visited', 'Skipped'],
              onChanged: (v) => setState(() => _visitStatus = v),
            ),
            const SizedBox(height: 8),
            _FilterDropdown(
              value: _placeSort,
              label: 'Sort places',
              values: const [
                'Recently added',
                'Name',
                'Planned date',
                'Recently visited',
              ],
              onChanged: (v) => setState(() => _placeSort = v),
            ),
            const SizedBox(height: 12),
            _sectionHeader('Saved places', '${places.length} saved'),
            if (placesAsync.isLoading && places.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (placesAsync.hasError)
              _errorCard('Could not load places: ${placesAsync.error}')
            else if (visiblePlaces.isEmpty)
              EmptyState(
                icon: Icons.place_outlined,
                title: places.isEmpty
                    ? 'No saved places yet'
                    : 'No places match',
                message: places.isEmpty
                    ? 'Add a destination to start a collection.'
                    : 'Change the search or filters to see more places.',
                action: places.isEmpty
                    ? FilledButton.icon(
                        onPressed: () => _editPlace(),
                        icon: const Icon(Icons.add),
                        label: const Text('Add a place'),
                      )
                    : null,
              )
            else
              for (final place in visiblePlaces) _placeCard(place),
            if (_visitStatus == 'All' &&
                _category == 'All' &&
                _query.isEmpty &&
                recentlyVisited.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sectionHeader('Recently visited', 'Latest visits'),
              for (final place in recentlyVisited.take(3)) _placeCard(place),
            ],
          ] else ...[
            _FilterDropdown(
              value: _tripStatus,
              label: 'Trip status',
              values: const ['All', 'Planned', 'Ongoing', 'Completed'],
              onChanged: (v) => setState(() => _tripStatus = v),
            ),
            const SizedBox(height: 8),
            _FilterDropdown(
              value: _tripSort,
              label: 'Sort trips',
              values: const ['Start date', 'Name'],
              onChanged: (v) => setState(() => _tripSort = v),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _pickTripDateRange,
                icon: const Icon(Icons.date_range_outlined),
                label: Text(
                  _tripDateRange == null
                      ? 'Filter by trip dates'
                      : '${DateFormat.yMMMd().format(_tripDateRange!.start)} – ${DateFormat.yMMMd().format(_tripDateRange!.end)}',
                ),
              ),
            ),
            if (_tripDateRange != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _tripDateRange = null),
                  child: const Text('Clear date filter'),
                ),
              ),
            const SizedBox(height: 12),
            _sectionHeader('My trips', '${trips.length} trips'),
            if (tripsAsync.isLoading && trips.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (tripsAsync.hasError)
              _errorCard('Could not load trips: ${tripsAsync.error}')
            else if (visibleTrips.isEmpty)
              EmptyState(
                icon: Icons.luggage_outlined,
                title: trips.isEmpty
                    ? 'No trips planned yet'
                    : 'No trips match',
                message: trips.isEmpty
                    ? 'Create a trip, then add saved places to its itinerary.'
                    : 'Change the search or filters to see more trips.',
                action: trips.isEmpty
                    ? FilledButton.icon(
                        onPressed: () => _editTrip(),
                        icon: const Icon(Icons.add),
                        label: const Text('Create a trip'),
                      )
                    : null,
              )
            else
              for (final trip in visibleTrips) _tripCard(trip),
          ],
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );

  Widget _errorCard(String message) => Card(
    child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
  );

  Widget _placeCard(SavedPlace place) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: CircleAvatar(child: Icon(_categoryIcon(place.category))),
      title: Text(place.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          place.category,
          if (place.address.isNotEmpty) place.address,
          _visitStatusLabel(place.status),
          if (place.plannedAt != null)
            DateFormat.yMMMd().format(place.plannedAt!.toLocal()),
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => context.push('/places/${Uri.encodeComponent(place.id)}'),
      trailing: PopupMenuButton<String>(
        tooltip: 'Place actions',
        onSelected: (action) async {
          if (action == 'edit') await _editPlace(place);
          if (action == 'map') await _openMap(place);
          if (action == 'delete') await _deletePlace(place);
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('Edit')),
          PopupMenuItem(value: 'map', child: Text('Open in Maps')),
          PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    ),
  );

  Widget _tripCard(TravelTrip trip) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: ListTile(
      leading: const CircleAvatar(child: Icon(Icons.luggage_outlined)),
      title: Text(trip.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (trip.destination.isNotEmpty) trip.destination,
          _tripStatusLabel(trip.status),
          if (trip.startAt != null)
            DateFormat.yMMMd().format(trip.startAt!.toLocal()),
          if (trip.endAt != null)
            DateFormat.yMMMd().format(trip.endAt!.toLocal()),
        ].join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: () => _showTripDetails(trip),
      trailing: PopupMenuButton<String>(
        tooltip: 'Trip actions',
        onSelected: (action) async {
          if (action == 'edit') await _editTrip(trip);
          if (action == 'delete') await _deleteTrip(trip);
          if (action == 'complete') {
            await ref
                .read(placesRepositoryProvider)
                .saveTrip(
                  id: trip.id,
                  name: trip.name,
                  description: trip.description,
                  destination: trip.destination,
                  startAt: trip.startAt,
                  endAt: trip.endAt,
                  status: 'completed',
                  budgetMinor: trip.budgetMinor,
                  currencyCode: trip.currencyCode,
                  notes: trip.notes,
                );
          }
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          if (trip.status != 'completed')
            const PopupMenuItem(
              value: 'complete',
              child: Text('Mark completed'),
            ),
          const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    ),
  );

  Future<void> _editPlace([SavedPlace? place]) async {
    final name = TextEditingController(text: place?.name ?? '');
    final category = TextEditingController(text: place?.category ?? 'Other');
    final address = TextEditingController(text: place?.address ?? '');
    final mapUrl = TextEditingController(text: place?.mapUrl ?? '');
    final notes = TextEditingController(text: place?.notes ?? '');
    final review = TextEditingController(text: place?.review ?? '');
    final rating = ValueNotifier<int?>(place?.rating);
    final state =
        ValueNotifier<({DateTime? planned, String status, DateTime? visited})>((
          planned: place?.plannedAt,
          status: place?.status ?? 'planned',
          visited: place?.visitedAt,
        ));
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(place == null ? 'Save a place' : 'Edit place'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    maxLength: 160,
                    decoration: const InputDecoration(
                      labelText: 'Place name *',
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Enter a name' : null,
                  ),
                  TextField(
                    controller: category,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      helperText: 'Use a suggested or custom category',
                    ),
                  ),
                  TextField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Address'),
                  ),
                  TextFormField(
                    controller: mapUrl,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Place link',
                      hintText: 'Paste a Google Maps link',
                      helperText: 'Visit opens this link. Leave blank to search Google Maps.',
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return null;
                      final uri = Uri.tryParse(text);
                      if (uri == null ||
                          !{'http', 'https'}.contains(uri.scheme) ||
                          uri.host.isEmpty) {
                        return 'Enter a valid http or https link';
                      }
                      return null;
                    },
                  ),
                  TextField(
                    controller: notes,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                  ValueListenableBuilder(
                    valueListenable: state,
                    builder: (_, value, _) => Column(
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: value.status,
                          decoration: const InputDecoration(
                            labelText: 'Visit status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'planned',
                              child: Text('Planned'),
                            ),
                            DropdownMenuItem(
                              value: 'visited',
                              child: Text('Visited'),
                            ),
                            DropdownMenuItem(
                              value: 'skipped',
                              child: Text('Skipped'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              state.value = (
                                planned: value.planned,
                                status: v,
                                visited: v == 'visited'
                                    ? (value.visited ?? DateTime.now())
                                    : value.visited,
                              );
                            }
                          },
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: dialogContext,
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                                initialDate: value.planned ?? DateTime.now(),
                              );
                              if (d != null) {
                                state.value = (
                                  planned: d,
                                  status: state.value.status,
                                  visited: state.value.visited,
                                );
                              }
                            },
                            icon: const Icon(Icons.event_outlined),
                            label: Text(
                              value.planned == null
                                  ? 'Plan a visit'
                                  : 'Planned ${DateFormat.yMMMd().format(value.planned!)}',
                            ),
                          ),
                        ),
                        if (value.planned != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: () => state.value = (
                                planned: null,
                                status: value.status,
                                visited: value.visited,
                              ),
                              child: const Text('Clear planned date'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  ValueListenableBuilder<int?>(
                    valueListenable: rating,
                    builder: (_, value, _) => DropdownButtonFormField<int?>(
                      initialValue: value,
                      decoration: const InputDecoration(
                        labelText: 'Personal rating',
                      ),
                      items: const [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Not rated'),
                        ),
                        DropdownMenuItem(value: 1, child: Text('1 star')),
                        DropdownMenuItem(value: 2, child: Text('2 stars')),
                        DropdownMenuItem(value: 3, child: Text('3 stars')),
                        DropdownMenuItem(value: 4, child: Text('4 stars')),
                        DropdownMenuItem(value: 5, child: Text('5 stars')),
                      ],
                      onChanged: (v) => rating.value = v,
                    ),
                  ),
                  TextField(
                    controller: review,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Personal review',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save place'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      try {
        await ref
            .read(placesRepositoryProvider)
            .savePlace(
              id: place?.id,
              name: name.text,
              category: category.text,
              address: address.text,
              mapUrl: mapUrl.text,
              latitude: place?.latitude,
              longitude: place?.longitude,
              notes: notes.text,
              plannedAt: state.value.planned,
              status: state.value.status,
              rating: rating.value,
              review: review.text,
              visitedAt: state.value.visited,
            );
      } catch (error) {
        _showMessage(error.toString());
      }
    }
    for (final controller in [name, category, address, mapUrl, notes, review]) {
      controller.dispose();
    }
    rating.dispose();
    state.dispose();
  }

  Future<void> _openMap(SavedPlace place) async {
    final uri = mapsSearchUri(
      name: place.name,
      address: place.address,
      latitude: place.latitude,
      longitude: place.longitude,
    );
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _showMessage('Could not open a map for ${place.name}.');
      }
    } catch (_) {
      _showMessage(
        'Could not open a map. Please check a browser or maps app is available.',
      );
    }
  }

  Future<void> _deletePlace(SavedPlace place) async {
    final yes = await _confirm(
      'Delete place?',
      'Remove ${place.name} from saved places? Trip stops using it will also be removed.',
    );
    if (yes) await ref.read(placesRepositoryProvider).deletePlace(place.id);
  }

  Future<void> _editTrip([TravelTrip? trip]) async {
    final name = TextEditingController(text: trip?.name ?? '');
    final destination = TextEditingController(text: trip?.destination ?? '');
    final description = TextEditingController(text: trip?.description ?? '');
    final notes = TextEditingController(text: trip?.notes ?? '');
    final budget = TextEditingController(
      text: trip?.budgetMinor == null
          ? ''
          : (trip!.budgetMinor! / 100).toStringAsFixed(2),
    );
    final state =
        ValueNotifier<({DateTime? start, DateTime? end, String status})>((
          start: trip?.startAt,
          end: trip?.endAt,
          status: trip?.status ?? 'planned',
        ));
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trip == null ? 'Create a trip' : 'Edit trip'),
        content: SizedBox(
          width: 460,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'Trip name *'),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Enter a trip name'
                        : null,
                  ),
                  TextField(
                    controller: destination,
                    decoration: const InputDecoration(labelText: 'Destination'),
                  ),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  ValueListenableBuilder(
                    valueListenable: state,
                    builder: (_, value, _) => Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () async {
                                  final d = await showDatePicker(
                                    context: ctx,
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2100),
                                    initialDate: value.start ?? DateTime.now(),
                                  );
                                  if (d != null) {
                                    state.value = (
                                      start: d,
                                      end: value.end,
                                      status: value.status,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.calendar_today),
                                label: Text(
                                  value.start == null
                                      ? 'Start date'
                                      : DateFormat.yMMMd().format(value.start!),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextButton.icon(
                                onPressed: () async {
                                  final d = await showDatePicker(
                                    context: ctx,
                                    firstDate: value.start ?? DateTime(2000),
                                    lastDate: DateTime(2100),
                                    initialDate:
                                        value.end ??
                                        value.start ??
                                        DateTime.now(),
                                  );
                                  if (d != null) {
                                    state.value = (
                                      start: value.start,
                                      end: d,
                                      status: value.status,
                                    );
                                  }
                                },
                                icon: const Icon(Icons.event_available),
                                label: Text(
                                  value.end == null
                                      ? 'End date'
                                      : DateFormat.yMMMd().format(value.end!),
                                ),
                              ),
                            ),
                          ],
                        ),
                        DropdownButtonFormField<String>(
                          initialValue: value.status,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'planned',
                              child: Text('Planned'),
                            ),
                            DropdownMenuItem(
                              value: 'ongoing',
                              child: Text('Ongoing'),
                            ),
                            DropdownMenuItem(
                              value: 'completed',
                              child: Text('Completed'),
                            ),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              state.value = (
                                start: value.start,
                                end: value.end,
                                status: v,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: budget,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Estimated budget (₹)',
                      helperText: 'Optional total budget',
                    ),
                  ),
                  TextField(
                    controller: notes,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: const Text('Save trip'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      try {
        final parsed = budget.text.trim().isEmpty
            ? null
            : parseMinorUnits(budget.text);
        if (budget.text.trim().isNotEmpty && parsed == null) {
          throw ArgumentError('Enter the budget as an amount, e.g. 1200.00.');
        }
        await ref
            .read(placesRepositoryProvider)
            .saveTrip(
              id: trip?.id,
              name: name.text,
              destination: destination.text,
              description: description.text,
              startAt: state.value.start,
              endAt: state.value.end,
              status: state.value.status,
              budgetMinor: parsed,
              notes: notes.text,
            );
      } catch (error) {
        _showMessage(error.toString());
      }
    }
    for (final controller in [name, destination, description, notes, budget]) {
      controller.dispose();
    }
    state.dispose();
  }

  Future<void> _deleteTrip(TravelTrip trip) async {
    final yes = await _confirm(
      'Delete trip?',
      'Delete ${trip.name} and its estimates and itinerary? Saved places and Money Manager expenses will remain.',
    );
    if (yes) await ref.read(placesRepositoryProvider).deleteTrip(trip.id);
  }

  Future<void> _pickTripDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _tripDateRange,
      currentDate: DateTime.now(),
    );
    if (selected != null && mounted) {
      setState(() => _tripDateRange = selected);
    }
  }

  void _showTripDetails(TravelTrip trip) {
    final repo = ref.read(placesRepositoryProvider);
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(trip.name),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    [
                      if (trip.destination.isNotEmpty) trip.destination,
                      _tripStatusLabel(trip.status),
                      if (trip.startAt != null)
                        DateFormat.yMMMd().format(trip.startAt!.toLocal()),
                      if (trip.endAt != null)
                        DateFormat.yMMMd().format(trip.endAt!.toLocal()),
                    ].join(' · '),
                  ),
                  if (trip.description.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(trip.description),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Itinerary',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add saved place',
                        onPressed: () async {
                          await _choosePlaceForTrip(trip);
                          setDialog(() {});
                        },
                        icon: const Icon(Icons.add_location_alt_outlined),
                      ),
                    ],
                  ),
                  FutureBuilder<List<TripPlace>>(
                    future: repo.itinerary(trip.id),
                    builder: (_, snapshot) => snapshot.data == null
                        ? const LinearProgressIndicator()
                        : snapshot.data!.isEmpty
                        ? const Text('Add saved places to build the itinerary.')
                        : Column(
                            children: [
                              for (var i = 0; i < snapshot.data!.length; i++)
                                _itineraryRow(
                                  trip,
                                  snapshot.data![i],
                                  i,
                                  snapshot.data!.length,
                                  setDialog,
                                ),
                            ],
                          ),
                  ),
                  const Divider(height: 26),
                  Text(
                    'Trip costs',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  FutureBuilder<List<TripEstimate>>(
                    future: repo.estimates(trip.id),
                    builder: (_, snapshot) {
                      final estimates = snapshot.data ?? const <TripEstimate>[];
                      final estimated = estimates.fold<int>(
                        0,
                        (sum, e) => sum + e.amountMinor,
                      );
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Estimates: ${formatMinorUnits(estimated)}'),
                          if (trip.budgetMinor != null)
                            Text(
                              'Budget: ${formatMinorUnits(trip.budgetMinor!)} · Remaining: ${formatMinorUnits(trip.budgetMinor! - estimated)}',
                            ),
                          if (trip.budgetMinor != null &&
                              trip.budgetMinor! > 0) ...[
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: (estimated / trip.budgetMinor!).clamp(
                                0,
                                1,
                              ),
                            ),
                            Text(
                              'Estimated budget used: ${(estimated * 100 / trip.budgetMinor!).round()}%',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          for (final estimate in estimates)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(estimate.description),
                              subtitle: Text(
                                '${estimate.category}${estimate.notes.isEmpty ? '' : ' · ${estimate.notes}'}',
                              ),
                              trailing: Text(
                                formatMinorUnits(estimate.amountMinor),
                              ),
                            ),
                          TextButton.icon(
                            onPressed: () async {
                              await _addEstimate(trip);
                              setDialog(() {});
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('Add estimate'),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<int>(
                    future: repo.actualTotal(trip.id),
                    builder: (_, snapshot) => Text(
                      'Actual linked spending: ${snapshot.data == null ? '…' : formatMinorUnits(snapshot.data!)}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  FutureBuilder<List<MoneyTransaction>>(
                    future: repo.watchActualExpenses(trip.id).first,
                    builder: (_, snapshot) => Column(
                      children: [
                        for (final txn
                            in snapshot.data ?? const <MoneyTransaction>[])
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            onTap: () async {
                              await _addActualExpense(trip, txn);
                              setDialog(() {});
                            },
                            title: Text(
                              txn.note.isEmpty ? 'Trip expense' : txn.note,
                            ),
                            subtitle: Text(
                              DateFormat.yMMMd().format(
                                txn.occurredAt.toLocal(),
                              ),
                            ),
                            trailing: Text(formatMinorUnits(txn.amountMinor)),
                          ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await _addActualExpense(trip);
                      setDialog(() {});
                    },
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Record actual expense in Money Manager'),
                  ),
                  if (trip.notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Notes: ${trip.notes}'),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _editTrip(trip);
              },
              child: const Text('Edit trip'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itineraryRow(
    TravelTrip trip,
    TripPlace entry,
    int index,
    int length,
    StateSetter refresh,
  ) => FutureBuilder<SavedPlace?>(
    future: ref.read(placesRepositoryProvider).place(entry.placeId),
    builder: (ctx, snapshot) {
      final place = snapshot.data;
      if (place == null) return const SizedBox.shrink();
      return ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(radius: 14, child: Text('${index + 1}')),
        title: Text(place.name),
        subtitle: Text(
          [
            place.address,
            _visitStatusLabel(entry.status),
            if (entry.plannedAt != null)
              DateFormat.yMMMd().add_jm().format(entry.plannedAt!.toLocal()),
            if (entry.notes.isNotEmpty) entry.notes,
          ].where((s) => s.isNotEmpty).join(' · '),
        ),
        trailing: Wrap(
          spacing: 0,
          children: [
            IconButton(
              tooltip: 'Edit stop details',
              onPressed: () async {
                await _editItineraryStop(entry);
                refresh(() {});
              },
              icon: const Icon(Icons.edit_note_outlined),
            ),
            IconButton(
              tooltip: 'Move up',
              onPressed: index == 0
                  ? null
                  : () async {
                      await ref
                          .read(placesRepositoryProvider)
                          .moveItineraryStop(trip.id, place.id, -1);
                      refresh(() {});
                    },
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton(
              tooltip: 'Move down',
              onPressed: index == length - 1
                  ? null
                  : () async {
                      await ref
                          .read(placesRepositoryProvider)
                          .moveItineraryStop(trip.id, place.id, 1);
                      refresh(() {});
                    },
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton(
              tooltip: 'Open in Maps',
              onPressed: () => _openMap(place),
              icon: const Icon(Icons.map_outlined),
            ),
            IconButton(
              tooltip: 'Remove from trip',
              onPressed: () async {
                await ref
                    .read(placesRepositoryProvider)
                    .removePlaceFromTrip(trip.id, place.id);
                refresh(() {});
              },
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ],
        ),
      );
    },
  );

  Future<void> _editItineraryStop(TripPlace entry) async {
    final notes = TextEditingController(text: entry.notes);
    final state = ValueNotifier<({DateTime? plannedAt, String status})>((
      plannedAt: entry.plannedAt,
      status: entry.status,
    ));
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Itinerary stop'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ValueListenableBuilder(
                valueListenable: state,
                builder: (_, value, _) => Column(
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: value.status,
                      decoration: const InputDecoration(
                        labelText: 'Visit status',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'planned',
                          child: Text('Planned'),
                        ),
                        DropdownMenuItem(
                          value: 'visited',
                          child: Text('Visited'),
                        ),
                        DropdownMenuItem(
                          value: 'skipped',
                          child: Text('Skipped'),
                        ),
                      ],
                      onChanged: (status) {
                        if (status != null) {
                          state.value = (
                            plannedAt: value.plannedAt,
                            status: status,
                          );
                        }
                      },
                    ),
                    TextButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                          initialDate: value.plannedAt ?? DateTime.now(),
                        );
                        if (date == null || !ctx.mounted) return;
                        final time = await showTimePicker(
                          context: ctx,
                          initialTime: value.plannedAt == null
                              ? TimeOfDay(hour: 9, minute: 0)
                              : TimeOfDay.fromDateTime(value.plannedAt!),
                        );
                        if (time != null) {
                          state.value = (
                            plannedAt: DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            ),
                            status: state.value.status,
                          );
                        }
                      },
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(
                        value.plannedAt == null
                            ? 'Plan date and time'
                            : DateFormat.yMMMd().add_jm().format(
                                value.plannedAt!.toLocal(),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Stop notes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save stop'),
          ),
        ],
      ),
    );
    if (save == true) {
      await ref
          .read(placesRepositoryProvider)
          .updateItineraryStop(
            entryId: entry.id,
            plannedAt: state.value.plannedAt,
            status: state.value.status,
            notes: notes.text,
          );
    }
    notes.dispose();
    state.dispose();
  }

  Future<void> _choosePlaceForTrip(TravelTrip trip) async {
    final places = await ref.read(placesRepositoryProvider).places();
    if (!mounted) return;
    final chosen = await showDialog<SavedPlace>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add a saved place'),
        children: [
          if (places.isEmpty)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('Save a place first.'),
            ),
          for (final place in places)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, place),
              child: Text(place.name),
            ),
        ],
      ),
    );
    if (chosen != null) {
      await ref
          .read(placesRepositoryProvider)
          .addPlaceToTrip(trip.id, chosen.id);
    }
  }

  Future<void> _addEstimate(TravelTrip trip) async {
    final description = TextEditingController();
    final amount = TextEditingController();
    final notes = TextEditingController();
    String category = 'Other';
    DateTime? occurredAt;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Estimate trip cost'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Amount (₹)'),
              ),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Category'),
                items:
                    const [
                          'Transport',
                          'Accommodation',
                          'Food',
                          'Tickets and activities',
                          'Shopping',
                          'Other',
                        ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (v) {
                  if (v != null) setDialog(() => category = v);
                },
              ),
              TextButton.icon(
                onPressed: () async {
                  final selected = await showDatePicker(
                    context: ctx,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    initialDate: occurredAt ?? DateTime.now(),
                  );
                  if (selected != null) {
                    setDialog(() => occurredAt = selected);
                  }
                },
                icon: const Icon(Icons.event_outlined),
                label: Text(
                  occurredAt == null
                      ? 'Add expense date (optional)'
                      : DateFormat.yMMMd().format(occurredAt!),
                ),
              ),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result == true) {
      final parsed = parseMinorUnits(amount.text);
      if (parsed == null) {
        _showMessage('Enter an amount such as 120.00.');
      } else {
        await ref
            .read(placesRepositoryProvider)
            .saveEstimate(
              tripId: trip.id,
              description: description.text,
              amountMinor: parsed,
              category: category,
              occurredAt: occurredAt,
              notes: notes.text,
            );
      }
    }
    description.dispose();
    amount.dispose();
    notes.dispose();
  }

  Future<void> _addActualExpense(
    TravelTrip trip, [
    MoneyTransaction? existing,
  ]) async {
    final money = ref.read(moneyRepositoryProvider);
    await money.seedDefaults();
    final accounts = await money.accounts();
    final categories = (await money.categories())
        .where((c) => c.type == 'expense' && c.archivedAt == null)
        .toList();
    if (!mounted) return;
    if (accounts.isEmpty || categories.isEmpty) {
      _showMessage(
        'Add an active Money Manager account and expense category first.',
      );
      return;
    }
    final amount = TextEditingController(
      text: existing == null
          ? ''
          : (existing.amountMinor / 100).toStringAsFixed(2),
    );
    final note = TextEditingController(text: existing?.note ?? '');
    final transactionId = existing?.id ?? const Uuid().v4();
    String accountId = existing?.accountId ?? accounts.first.id;
    String categoryId = existing?.categoryId ?? categories.first.id;
    DateTime date = existing?.occurredAt ?? DateTime.now();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: Text(
            existing == null ? 'Record trip expense' : 'Edit trip expense',
          ),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amount,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: 'Amount (₹)'),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: accountId,
                    decoration: const InputDecoration(
                      labelText: 'Money Manager account',
                    ),
                    items: accounts
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialog(() => accountId = v);
                    },
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: categoryId,
                    decoration: const InputDecoration(
                      labelText: 'Expense category',
                    ),
                    items: categories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialog(() => categoryId = v);
                    },
                  ),
                  TextField(
                    controller: note,
                    decoration: const InputDecoration(labelText: 'Note'),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                        initialDate: date,
                      );
                      if (d != null) setDialog(() => date = d);
                    },
                    icon: const Icon(Icons.event),
                    label: Text(DateFormat.yMMMd().format(date)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save expense'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      final parsed = parseMinorUnits(amount.text);
      if (parsed == null || parsed <= 0) {
        _showMessage('Enter an amount greater than zero.');
      } else {
        try {
          await ref
              .read(placesRepositoryProvider)
              .saveActualExpense(
                transactionId: transactionId,
                tripId: trip.id,
                amountMinor: parsed,
                accountId: accountId,
                categoryId: categoryId,
                occurredAt: date,
                note: note.text,
              );
        } catch (error) {
          _showMessage(error.toString());
        }
      }
    }
    amount.dispose();
    note.dispose();
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      ) ??
      false;
  void _showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.value,
    required this.label,
    required this.values,
    required this.onChanged,
  });
  final String value;
  final String label;
  final List<String> values;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: InputDecoration(labelText: label),
    items: values
        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
        .toList(),
    onChanged: (v) {
      if (v != null) onChanged(v);
    },
  );
}

String _visitStatusLabel(String value) =>
    value[0].toUpperCase() + value.substring(1);
String _tripStatusLabel(String value) =>
    value[0].toUpperCase() + value.substring(1);
int _nullableDateCompare(DateTime? first, DateTime? second) {
  if (first == null) return second == null ? 0 : 1;
  if (second == null) return -1;
  return first.compareTo(second);
}

int _nullableDateDescendingCompare(DateTime? first, DateTime? second) {
  if (first == null) return second == null ? 0 : 1;
  if (second == null) return -1;
  return second.compareTo(first);
}

IconData _categoryIcon(String category) => switch (category.toLowerCase()) {
  'restaurant' || 'restaurants' || 'cafes' => Icons.restaurant_outlined,
  'nature' || 'parks' => Icons.park_outlined,
  'museums' || 'heritage' || 'palaces' => Icons.museum_outlined,
  'shopping' => Icons.shopping_bag_outlined,
  _ => Icons.place_outlined,
};
