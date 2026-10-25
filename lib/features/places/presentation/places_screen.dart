import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/page_container.dart';
import '../../../core/widgets/section_header.dart';
import '../../money/data/money_database.dart';
import '../application/places_providers.dart';
import '../data/places_repository.dart';

IconData placeIconForCodePoint(int? codePoint) {
  const icons = <IconData>[
    Icons.local_dining_outlined,
    Icons.local_cafe_outlined,
    Icons.restaurant_outlined,
    Icons.park_outlined,
    Icons.hotel_outlined,
    Icons.shopping_bag_outlined,
    Icons.work_outline,
    Icons.temple_hindu_outlined,
    Icons.place_outlined,
    Icons.explore_outlined,
    Icons.museum_outlined,
    Icons.beach_access_outlined,
    Icons.attractions_outlined,
    Icons.flight_outlined,
  ];
  return icons.firstWhere(
    (icon) => icon.codePoint == codePoint,
    orElse: () => Icons.place_outlined,
  );
}

class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({this.quickAdd, super.key});
  final String? quickAdd;

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  int _section = 0; // 0 = Saved Places, 1 = My Trips
  String _query = '';
  String _categoryFilter = 'All';
  String _visitStatus = 'All';
  String _placeSort = 'Recently added';
  String _tripStatus = 'All';
  String _tripSort = 'Start date';
  bool _quickAddHandled = false;

  @override
  void initState() {
    super.initState();
    _checkQuickAdd();
  }

  @override
  void didUpdateWidget(PlacesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.quickAdd != oldWidget.quickAdd) {
      _quickAddHandled = false;
    }
    _checkQuickAdd();
  }

  void _checkQuickAdd() {
    if (widget.quickAdd != null && !_quickAddHandled) {
      _quickAddHandled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.quickAdd) {
          case 'place':
            showAddOrEditPlaceForm(context, ref);
          case 'trip':
            _editTrip();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final placesAsync = ref.watch(savedPlacesProvider);
    final tripsAsync = ref.watch(tripsProvider);
    final categoriesAsync = ref.watch(placeCategoriesProvider);

    final places = placesAsync.asData?.value ?? const <SavedPlace>[];
    final trips = tripsAsync.asData?.value ?? const <TravelTrip>[];
    final categories = categoriesAsync.asData?.value ?? const <PlaceCategory>[];

    final query = _query.trim().toLowerCase();

    // Filtered Places
    final visiblePlaces =
        places.where((p) {
          final matchesStatus =
              _visitStatus == 'All' || p.status == _visitStatus.toLowerCase();
          final matchesCategory =
              _categoryFilter == 'All' ||
              p.category.toLowerCase() == _categoryFilter.toLowerCase();
          return matchesStatus &&
              matchesCategory &&
              (query.isEmpty ||
                  '${p.name} ${p.address} ${p.notes} ${p.category}'
                      .toLowerCase()
                      .contains(query));
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

    // Filtered Trips
    final visibleTrips =
        trips.where((t) {
          final matchesStatus =
              _tripStatus == 'All' || t.status == _tripStatus.toLowerCase();
          return matchesStatus &&
              (query.isEmpty ||
                  '${t.name} ${t.destination} ${t.description}'
                      .toLowerCase()
                      .contains(query));
        }).toList()..sort(
          (a, b) => switch (_tripSort) {
            'Name' => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            _ => _nullableDateCompare(a.startAt, b.startAt),
          },
        );

    return PageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Places & Trips',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Save destinations and plan the journey.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.darkSecondaryText
                            : AppColors.lightSecondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Manage categories',
                icon: const Icon(Icons.category_outlined),
                onPressed: () => showCategoryManagementSheet(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Segmented Selector (Saved Places / My Trips)
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
                icon: Icon(Icons.card_travel_outlined),
              ),
            ],
            selected: {_section},
            onSelectionChanged: (val) => setState(() => _section = val.first),
          ),
          const SizedBox(height: 14),

          // Search Field
          TextField(
            decoration: InputDecoration(
              hintText: _section == 0
                  ? 'Search place names, addresses, or notes...'
                  : 'Search trip names or destinations...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() => _query = ''),
                    )
                  : null,
              isDense: true,
            ),
            onChanged: (val) => setState(() => _query = val),
          ),
          const SizedBox(height: 12),

          if (_section == 0) ...[
            // Category Filter Chips Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _categoryFilter == 'All',
                    onSelected: (selected) {
                      if (selected) setState(() => _categoryFilter = 'All');
                    },
                  ),
                  const SizedBox(width: 6),
                  for (final cat in categories) ...[
                    ChoiceChip(
                      avatar: Icon(
                        placeIconForCodePoint(cat.iconCodePoint),
                        size: 16,
                        color: Color(cat.colorValue),
                      ),
                      label: Text(cat.name),
                      selected:
                          _categoryFilter.toLowerCase() ==
                          cat.name.toLowerCase(),
                      onSelected: (selected) {
                        if (selected) {
                          setState(() => _categoryFilter = cat.name);
                        }
                      },
                    ),
                    const SizedBox(width: 6),
                  ],
                  ActionChip(
                    avatar: const Icon(Icons.settings_outlined, size: 16),
                    label: const Text('Manage'),
                    onPressed: () => showCategoryManagementSheet(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Filters Row (Visit Status & Sort)
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _visitStatus,
                    decoration: const InputDecoration(
                      labelText: 'Visit status',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All status')),
                      DropdownMenuItem(
                        value: 'Planned',
                        child: Text('Planned'),
                      ),
                      DropdownMenuItem(
                        value: 'Visited',
                        child: Text('Visited'),
                      ),
                      DropdownMenuItem(
                        value: 'Skipped',
                        child: Text('Skipped'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _visitStatus = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _placeSort,
                    decoration: const InputDecoration(
                      labelText: 'Sort by',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Recently added',
                        child: Text('Recently added'),
                      ),
                      DropdownMenuItem(value: 'Name', child: Text('Name')),
                      DropdownMenuItem(
                        value: 'Planned date',
                        child: Text('Planned date'),
                      ),
                      DropdownMenuItem(
                        value: 'Recently visited',
                        child: Text('Recently visited'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _placeSort = v);
                    },
                  ),
                ),
              ],
            ),
          ] else ...[
            // Trips Filter & Sort Row
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _tripStatus,
                    decoration: const InputDecoration(
                      labelText: 'Trip status',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All trips')),
                      DropdownMenuItem(
                        value: 'Planned',
                        child: Text('Planned'),
                      ),
                      DropdownMenuItem(
                        value: 'Ongoing',
                        child: Text('Ongoing'),
                      ),
                      DropdownMenuItem(
                        value: 'Completed',
                        child: Text('Completed'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _tripStatus = v);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _tripSort,
                    decoration: const InputDecoration(
                      labelText: 'Sort by',
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Start date',
                        child: Text('Start date'),
                      ),
                      DropdownMenuItem(value: 'Name', child: Text('Name')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _tripSort = v);
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),

          // Content List
          Expanded(
            child: _section == 0
                ? _buildPlacesList(context, visiblePlaces, categories, isDark)
                : _buildTripsList(context, visibleTrips, isDark),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SAVED PLACES LIST
  // ---------------------------------------------------------------------------
  Widget _buildPlacesList(
    BuildContext context,
    List<SavedPlace> visiblePlaces,
    List<PlaceCategory> categories,
    bool isDark,
  ) {
    if (visiblePlaces.isEmpty) {
      return EmptyState(
        icon: Icons.place_outlined,
        title: 'No places found',
        message: 'Save destinations you want to visit.',
        action: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: AppColors.lightText,
          ),
          onPressed: () => showAddOrEditPlaceForm(context, ref),
          icon: const Icon(Icons.add),
          label: const Text('Add Place'),
        ),
      );
    }

    final catMap = {for (final c in categories) c.name.toLowerCase(): c};

    return ListView.builder(
      itemCount: visiblePlaces.length,
      itemBuilder: (context, index) {
        final place = visiblePlaces[index];
        final catObj = catMap[place.category.toLowerCase()];
        final catColor = catObj != null
            ? Color(catObj.colorValue)
            : AppColors.brand;
        final catIcon = catObj != null
            ? placeIconForCodePoint(catObj.iconCodePoint)
            : Icons.place_outlined;

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

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BrutalCard(
            padding: const EdgeInsets.all(12),
            onTap: () => context.push('/places/${place.id}'),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: catColor,
                  child: Icon(
                    catIcon,
                    color: const Color(0xFF111111),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: catColor.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              place.category,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (place.address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          place.address,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.darkSecondaryText
                                : AppColors.lightSecondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (action) async {
                    if (action == 'details') {
                      context.push('/places/${place.id}');
                    } else if (action == 'edit') {
                      showAddOrEditPlaceForm(context, ref, place);
                    } else if (action == 'delete') {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Place?'),
                          content: Text(
                            'Remove "${place.name}" from saved places?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.error,
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        await ref
                            .read(placesRepositoryProvider)
                            .deletePlace(place.id);
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'details',
                      child: Text('View details'),
                    ),
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // MY TRIPS LIST
  // ---------------------------------------------------------------------------
  Widget _buildTripsList(
    BuildContext context,
    List<TravelTrip> visibleTrips,
    bool isDark,
  ) {
    if (visibleTrips.isEmpty) {
      return EmptyState(
        icon: Icons.card_travel_outlined,
        title: 'No trips planned',
        message: 'Organize your travel destinations and itinerary.',
        action: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.brand,
            foregroundColor: AppColors.lightText,
          ),
          onPressed: () => _editTrip(),
          icon: const Icon(Icons.add),
          label: const Text('New Trip'),
        ),
      );
    }

    return ListView.builder(
      itemCount: visibleTrips.length,
      itemBuilder: (context, index) {
        final trip = visibleTrips[index];
        final statusColor = switch (trip.status) {
          'completed' => AppColors.success,
          'ongoing' => AppColors.brand,
          _ => AppColors.warning,
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: BrutalCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const CircleAvatar(
                  backgroundColor: AppColors.brand,
                  child: Icon(
                    Icons.card_travel,
                    color: Color(0xFF111111),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        trip.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        trip.destination.isNotEmpty
                            ? trip.destination
                            : 'No destination set',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkSecondaryText
                              : AppColors.lightSecondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trip.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _editTrip([TravelTrip? trip]) async {
    final name = TextEditingController(text: trip?.name ?? '');
    final destination = TextEditingController(text: trip?.destination ?? '');
    final description = TextEditingController(text: trip?.description ?? '');
    final notes = TextEditingController(text: trip?.notes ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(trip == null ? 'New Trip' : 'Edit Trip'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Trip Name *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: destination,
                decoration: const InputDecoration(labelText: 'Destination'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: notes,
                decoration: const InputDecoration(labelText: 'Notes'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isNotEmpty) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await ref
          .read(placesRepositoryProvider)
          .saveTrip(
            id: trip?.id,
            name: name.text,
            destination: destination.text,
            description: description.text,
            notes: notes.text,
          );
    }
  }

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
}

// -----------------------------------------------------------------------------
// ADD / EDIT PLACE FORM
// -----------------------------------------------------------------------------
Future<void> showAddOrEditPlaceForm(
  BuildContext context,
  WidgetRef ref, [
  SavedPlace? place,
  String? initialName,
  String? initialLink,
]) async {
  final repo = ref.read(placesRepositoryProvider);
  await repo.seedDefaultCategories();

  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AddPlaceFormSheet(
      editPlace: place,
      initialName: initialName,
      initialLink: initialLink,
    ),
  );
}

class _AddPlaceFormSheet extends ConsumerStatefulWidget {
  const _AddPlaceFormSheet({
    this.editPlace,
    this.initialName,
    this.initialLink,
  });

  final SavedPlace? editPlace;
  final String? initialName;
  final String? initialLink;

  @override
  ConsumerState<_AddPlaceFormSheet> createState() => _AddPlaceFormSheetState();
}

class _AddPlaceFormSheetState extends ConsumerState<_AddPlaceFormSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _addressController;
  late final TextEditingController _mapUrlController;
  late final TextEditingController _notesController;

  PlaceCategory? _selectedCategory;
  String _status = 'planned';
  int? _rating;
  DateTime? _plannedAt;

  @override
  void initState() {
    super.initState();
    final p = widget.editPlace;
    _nameController = TextEditingController(
      text: p?.name ?? widget.initialName ?? '',
    );
    _addressController = TextEditingController(text: p?.address ?? '');
    _mapUrlController = TextEditingController(
      text: p?.mapUrl ?? widget.initialLink ?? '',
    );
    _notesController = TextEditingController(text: p?.notes ?? '');

    _status = p?.status ?? 'planned';
    _rating = p?.rating;
    _plannedAt = p?.plannedAt;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _mapUrlController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(placeCategoriesProvider).asData?.value ?? [];

    if (_selectedCategory == null && categories.isNotEmpty) {
      if (widget.editPlace != null) {
        _selectedCategory =
            categories
                .where(
                  (c) =>
                      c.name.toLowerCase() ==
                      widget.editPlace!.category.toLowerCase(),
                )
                .firstOrNull ??
            categories.firstOrNull;
      } else {
        _selectedCategory = categories.firstOrNull;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    widget.editPlace == null ? 'Add Place' : 'Edit Place',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Place Name (Required)
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Place Name *',
                  hintText: 'e.g. Midtown Restaurant',
                  isDense: true,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a place name' : null,
              ),
              const SizedBox(height: 12),

              // Category Dropdown
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<PlaceCategory>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        isDense: true,
                      ),
                      items: categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Row(
                                children: [
                                  Icon(
                                    placeIconForCodePoint(c.iconCodePoint),
                                    size: 18,
                                    color: Color(c.colorValue),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(c.name),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedCategory = val),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Manage categories',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () {
                      Navigator.pop(context);
                      showCategoryManagementSheet(context, ref);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Address (Optional)
              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address',
                  hintText: 'e.g. Main Street, Kottayam',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),

              // Place Link (Optional)
              TextFormField(
                controller: _mapUrlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Place Link',
                  hintText: 'e.g. https://maps.app.goo.gl/...',
                  isDense: true,
                ),
                validator: (val) {
                  final text = val?.trim() ?? '';
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
              const SizedBox(height: 12),

              // Visit Status & Personal Rating
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(
                        labelText: 'Visit Status',
                        isDense: true,
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
                        if (v != null) setState(() => _status = v);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int?>(
                      initialValue: _rating,
                      decoration: const InputDecoration(
                        labelText: 'Rating',
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Not rated'),
                        ),
                        DropdownMenuItem(value: 1, child: Text('1 ★')),
                        DropdownMenuItem(value: 2, child: Text('2 ★')),
                        DropdownMenuItem(value: 3, child: Text('3 ★')),
                        DropdownMenuItem(value: 4, child: Text('4 ★')),
                        DropdownMenuItem(value: 5, child: Text('5 ★')),
                      ],
                      onChanged: (v) => setState(() => _rating = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Planned Visit Date Picker
              OutlinedButton.icon(
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _plannedAt ?? DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _plannedAt = picked);
                  }
                },
                icon: const Icon(Icons.event_outlined, size: 16),
                label: Text(
                  _plannedAt != null
                      ? 'Planned: ${DateFormat.yMMMd().format(_plannedAt!)}'
                      : 'Set Planned Visit Date',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Notes (Optional)
              TextField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),

              // BOTTOM ACTION AREA: Save Place Button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: AppColors.lightText,
                  ),
                  onPressed: () async {
                    if (!_formKey.currentState!.validate()) return;

                    final name = _nameController.text.trim();
                    try {
                      await ref
                          .read(placesRepositoryProvider)
                          .savePlace(
                            id: widget.editPlace?.id,
                            name: name,
                            category: _selectedCategory?.name ?? 'Other',
                            address: _addressController.text.trim(),
                            mapUrl: _mapUrlController.text.trim(),
                            notes: _notesController.text.trim(),
                            status: _status,
                            rating: _rating,
                            plannedAt: _plannedAt,
                          );
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not save place: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Save Place'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PLACE CATEGORY MANAGEMENT SHEET
// -----------------------------------------------------------------------------
void showCategoryManagementSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final categories =
            ref.watch(placeCategoriesProvider).asData?.value ?? [];
        final places = ref.watch(savedPlacesProvider).asData?.value ?? [];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'Manage Categories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add category',
                    onPressed: () => _showCategoryEditDialog(context, ref),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: categories.length,
                  itemBuilder: (context, i) {
                    final cat = categories[i];
                    final catPlaces = places
                        .where(
                          (p) =>
                              p.category.toLowerCase() ==
                              cat.name.toLowerCase(),
                        )
                        .toList();

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Color(cat.colorValue),
                          child: Icon(
                            placeIconForCodePoint(cat.iconCodePoint),
                            color: const Color(0xFF111111),
                            size: 20,
                          ),
                        ),
                        title: Text(cat.name),
                        subtitle: Text('${catPlaces.length} places'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              onPressed: () => _showCategoryEditDialog(
                                context,
                                ref,
                                category: cat,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColors.error,
                              ),
                              onPressed: () => _confirmCategoryDeletion(
                                context,
                                ref,
                                cat,
                                catPlaces,
                                categories,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

void _showCategoryEditDialog(
  BuildContext context,
  WidgetRef ref, {
  PlaceCategory? category,
}) {
  final nameController = TextEditingController(text: category?.name ?? '');

  final colors = [
    0xFFFFD0AE, // Light orange
    0xFFFFF2CC, // Light yellow
    0xFFAEEBDD, // Light green
    0xFFB5E8D4, // Teal
    0xFFBFE0FF, // Light blue
    0xFFFFC5D8, // Light pink
    0xFFC9D4FF, // Soft indigo
    0xFFE5C9FF, // Light purple
    0xFFD7DEDE, // Muted grey
  ];

  final icons = [
    0xe25a, // local_dining_outlined
    0xe395, // local_cafe_outlined
    0xe532, // restaurant_outlined
    0xe471, // park_outlined
    0xe318, // hotel_outlined
    0xe59c, // shopping_bag_outlined
    0xe6f5, // work_outline
    0xf01da, // temple_hindu_outlined
    0xe4c6, // place_outlined
    0xe25a, // explore_outlined
  ];

  int selectedColor = category?.colorValue ?? colors.first;
  int selectedIcon = category?.iconCodePoint ?? icons.first;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDlgState) => AlertDialog(
        title: Text(category == null ? 'Add Category' : 'Edit Category'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Category Name',
                  hintText: 'e.g. Beaches, Viewpoints',
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Icon',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final icon in icons)
                    InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setDlgState(() => selectedIcon = icon),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: selectedIcon == icon
                              ? Theme.of(context).colorScheme.primaryContainer
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selectedIcon == icon
                                ? AppColors.brand
                                : Colors.transparent,
                          ),
                        ),
                        child: Icon(placeIconForCodePoint(icon), size: 20),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Color',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in colors)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => setDlgState(() => selectedColor = color),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Color(color),
                        child: selectedColor == color
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Color(0xFF111111),
                              )
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              try {
                await ref
                    .read(placesRepositoryProvider)
                    .saveCategory(
                      id: category?.id,
                      name: name,
                      iconCodePoint: selectedIcon,
                      colorValue: selectedColor,
                    );
                if (ctx.mounted) Navigator.pop(ctx);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Could not save category: $e')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

void _confirmCategoryDeletion(
  BuildContext context,
  WidgetRef ref,
  PlaceCategory category,
  List<SavedPlace> catPlaces,
  List<PlaceCategory> allCategories,
) {
  if (catPlaces.isEmpty) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: const Text('This category has no places assigned.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ref
                  .read(placesRepositoryProvider)
                  .deleteCategory(category.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    return;
  }

  final otherCategories = allCategories
      .where((c) => c.id != category.id)
      .toList();
  PlaceCategory? reassignCat = otherCategories.firstOrNull;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (context, setDlgState) => AlertDialog(
        title: Text('Delete "${category.name}"?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This category is used by ${catPlaces.length} saved places. Reassign them before deleting.',
            ),
            const SizedBox(height: 12),
            if (otherCategories.isNotEmpty) ...[
              DropdownButtonFormField<PlaceCategory>(
                value: reassignCat,
                decoration: const InputDecoration(
                  labelText: 'Reassign to Category',
                ),
                items: otherCategories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                    .toList(),
                onChanged: (val) => setDlgState(() => reassignCat = val),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ref
                  .read(placesRepositoryProvider)
                  .deleteCategory(
                    category.id,
                    reassignToCategoryName: reassignCat?.name ?? 'Other',
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Reassign & Delete'),
          ),
        ],
      ),
    ),
  );
}
