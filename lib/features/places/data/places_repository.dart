import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../money/data/money_database.dart';

class PlacesRepository {
  PlacesRepository(this.db);
  final MoneyDatabase db;
  static const _uuid = Uuid();

  Stream<List<SavedPlace>> watchPlaces() => (db.select(
    db.savedPlaces,
  )..orderBy([(p) => OrderingTerm.desc(p.updatedAt)])).watch();

  Future<List<SavedPlace>> places() => (db.select(
    db.savedPlaces,
  )..orderBy([(p) => OrderingTerm.desc(p.updatedAt)])).get();

  Future<SavedPlace?> place(String id) => (db.select(
    db.savedPlaces,
  )..where((p) => p.id.equals(id))).getSingleOrNull();

  Stream<List<TravelTrip>> watchTrips() => (db.select(
    db.travelTrips,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).watch();

  Future<List<TravelTrip>> trips() => (db.select(
    db.travelTrips,
  )..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])).get();

  Future<List<TripPlace>> itinerary(String tripId) =>
      (db.select(db.tripPlaces)
            ..where((entry) => entry.tripId.equals(tripId))
            ..orderBy([(entry) => OrderingTerm.asc(entry.itineraryOrder)]))
          .get();

  Future<List<SavedPlace>> placesForTrip(String tripId) async {
    final entries = await itinerary(tripId);
    final results = <SavedPlace>[];
    for (final entry in entries) {
      final place = await this.place(entry.placeId);
      if (place != null) results.add(place);
    }
    return results;
  }

  Future<void> seedDefaultCategories() async {
    final existing = await db.select(db.placeCategories).get();
    if (existing.isNotEmpty) return;

    final now = DateTime.now();
    final defaults = [
      PlaceCategoriesCompanion.insert(
        id: 'cat_food_stop',
        name: 'Food stop',
        iconCodePoint: 0xe25a, // Icons.local_dining_outlined
        colorValue: 0xFFFFD0AE,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      PlaceCategoriesCompanion.insert(
        id: 'cat_cafe',
        name: 'Cafe',
        iconCodePoint: 0xe395, // Icons.local_cafe_outlined
        colorValue: 0xFFFFF2CC,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      PlaceCategoriesCompanion.insert(
        id: 'cat_restaurant',
        name: 'Restaurant',
        iconCodePoint: 0xe532, // Icons.restaurant_outlined
        colorValue: 0xFFAEEBDD,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      PlaceCategoriesCompanion.insert(
        id: 'cat_nature',
        name: 'Nature',
        iconCodePoint: 0xe471, // Icons.park_outlined
        colorValue: 0xFFB5E8D4,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      PlaceCategoriesCompanion.insert(
        id: 'cat_stay',
        name: 'Stay',
        iconCodePoint: 0xe318, // Icons.hotel_outlined
        colorValue: 0xFFBFE0FF,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      PlaceCategoriesCompanion.insert(
        id: 'cat_shopping',
        name: 'Shopping',
        iconCodePoint: 0xe59c, // Icons.shopping_bag_outlined
        colorValue: 0xFFFFC5D8,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      PlaceCategoriesCompanion.insert(
        id: 'cat_work',
        name: 'Work',
        iconCodePoint: 0xe6f5, // Icons.work_outline
        colorValue: 0xFFC9D4FF,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      PlaceCategoriesCompanion.insert(
        id: 'cat_temple',
        name: 'Temple',
        iconCodePoint: 0xf01da, // Icons.temple_hindu_outlined
        colorValue: 0xFFE5C9FF,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
      PlaceCategoriesCompanion.insert(
        id: 'cat_other',
        name: 'Other',
        iconCodePoint: 0xe4c6, // Icons.place_outlined
        colorValue: 0xFFD7DEDE,
        isDefault: const Value(true),
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await db.batch((batch) {
      batch.insertAll(db.placeCategories, defaults);
    });
  }

  Stream<List<PlaceCategory>> watchCategories() {
    return (db.select(
      db.placeCategories,
    )..orderBy([(c) => OrderingTerm.asc(c.name)])).watch();
  }

  Future<List<PlaceCategory>> categoriesList() {
    return (db.select(
      db.placeCategories,
    )..orderBy([(c) => OrderingTerm.asc(c.name)])).get();
  }

  Future<void> saveCategory({
    String? id,
    required String name,
    required int iconCodePoint,
    required int colorValue,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty || cleanName.length > 80) {
      throw ArgumentError('Enter a category name between 1 and 80 characters.');
    }

    final all = await categoriesList();
    final duplicate = all.where(
      (c) => c.id != id && c.name.toLowerCase() == cleanName.toLowerCase(),
    );
    if (duplicate.isNotEmpty) {
      throw ArgumentError('A category with that name already exists.');
    }

    final now = DateTime.now();
    final categoryId = id ?? _uuid.v4();
    await db
        .into(db.placeCategories)
        .insertOnConflictUpdate(
          PlaceCategoriesCompanion(
            id: Value(categoryId),
            name: Value(cleanName),
            iconCodePoint: Value(iconCodePoint),
            colorValue: Value(colorValue),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> deleteCategory(
    String id, {
    String? reassignToCategoryName,
  }) async {
    final cat = await (db.select(
      db.placeCategories,
    )..where((c) => c.id.equals(id))).getSingleOrNull();
    if (cat == null) return;

    await db.transaction(() async {
      final targetCategoryName = (reassignToCategoryName ?? 'Other').trim();
      await (db.update(
        db.savedPlaces,
      )..where((p) => p.category.equals(cat.name))).write(
        SavedPlacesCompanion(
          category: Value(targetCategoryName),
          updatedAt: Value(DateTime.now()),
        ),
      );
      await (db.delete(db.placeCategories)..where((c) => c.id.equals(id))).go();
    });
  }

  Future<void> savePlace({
    String? id,
    required String name,
    String category = 'Other',
    String address = '',
    String mapUrl = '',
    double? latitude,
    double? longitude,
    String notes = '',
    DateTime? plannedAt,
    String status = 'planned',
    int? rating,
    String review = '',
    DateTime? visitedAt,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 160) {
      throw ArgumentError('Enter a place name (up to 160 characters).');
    }
    if ((latitude == null) != (longitude == null) ||
        (latitude != null && (latitude < -90 || latitude > 90)) ||
        (longitude != null && (longitude < -180 || longitude > 180))) {
      throw ArgumentError('Enter valid latitude and longitude together.');
    }
    if (rating != null && (rating < 1 || rating > 5)) {
      throw ArgumentError('Rating must be from 1 to 5.');
    }
    final cleanMapUrl = mapUrl.trim();
    if (cleanMapUrl.isNotEmpty) {
      final uri = Uri.tryParse(cleanMapUrl);
      if (uri == null ||
          !{'http', 'https'}.contains(uri.scheme) ||
          uri.host.isEmpty) {
        throw ArgumentError('Enter a valid web link for the place.');
      }
    }
    if (!{'planned', 'visited', 'skipped'}.contains(status)) {
      throw ArgumentError('Choose a valid visit status.');
    }
    final previous = id == null ? null : await place(id);
    if (id != null && previous == null) {
      throw StateError('Place no longer exists.');
    }
    final now = DateTime.now();
    final values = SavedPlacesCompanion(
      id: Value(id ?? _uuid.v4()),
      name: Value(clean),
      category: Value(category.trim().isEmpty ? 'Other' : category.trim()),
      address: Value(address.trim()),
      mapUrl: Value(cleanMapUrl),
      latitude: Value(latitude),
      longitude: Value(longitude),
      notes: Value(notes.trim()),
      plannedAt: Value(plannedAt?.toLocal()),
      status: Value(status),
      rating: Value(rating),
      review: Value(review.trim()),
      visitedAt: Value(
        status == 'visited'
            ? (visitedAt ?? previous?.visitedAt ?? now)
            : visitedAt,
      ),
      createdAt: Value(previous?.createdAt ?? now),
      updatedAt: Value(now),
    );
    if (previous == null) {
      await db.into(db.savedPlaces).insert(values);
    } else {
      await (db.update(
        db.savedPlaces,
      )..where((p) => p.id.equals(id!))).write(values);
    }
  }

  Future<void> deletePlace(String id) =>
      (db.delete(db.savedPlaces)..where((p) => p.id.equals(id))).go();

  Future<void> saveTrip({
    String? id,
    required String name,
    String description = '',
    String destination = '',
    DateTime? startAt,
    DateTime? endAt,
    String status = 'planned',
    int? budgetMinor,
    String currencyCode = 'INR',
    String notes = '',
  }) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 160) {
      throw ArgumentError('Enter a trip name.');
    }
    if (startAt != null && endAt != null && endAt.isBefore(startAt)) {
      throw ArgumentError('Trip end date cannot be before its start date.');
    }
    if (budgetMinor != null && budgetMinor < 0) {
      throw ArgumentError('Budget cannot be negative.');
    }
    if (!{'planned', 'ongoing', 'completed'}.contains(status)) {
      throw ArgumentError('Choose a valid trip status.');
    }
    final previous = id == null
        ? null
        : await (db.select(
            db.travelTrips,
          )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (id != null && previous == null) {
      throw StateError('Trip no longer exists.');
    }
    final now = DateTime.now();
    final values = TravelTripsCompanion(
      id: Value(id ?? _uuid.v4()),
      name: Value(clean),
      description: Value(description.trim()),
      destination: Value(destination.trim()),
      startAt: Value(
        startAt == null
            ? null
            : DateTime(startAt.year, startAt.month, startAt.day),
      ),
      endAt: Value(
        endAt == null ? null : DateTime(endAt.year, endAt.month, endAt.day),
      ),
      status: Value(status),
      budgetMinor: Value(budgetMinor),
      currencyCode: Value(currencyCode),
      notes: Value(notes.trim()),
      createdAt: Value(previous?.createdAt ?? now),
      updatedAt: Value(now),
    );
    if (previous == null) {
      await db.into(db.travelTrips).insert(values);
    } else {
      await (db.update(
        db.travelTrips,
      )..where((t) => t.id.equals(id!))).write(values);
    }
  }

  Future<void> deleteTrip(String id) =>
      (db.delete(db.travelTrips)..where((t) => t.id.equals(id))).go();

  Future<void> addPlaceToTrip(String tripId, String placeId) async {
    final existing = await itinerary(tripId);
    if (existing.any((e) => e.placeId == placeId)) return;
    await db
        .into(db.tripPlaces)
        .insert(
          TripPlacesCompanion.insert(
            id: _uuid.v4(),
            tripId: tripId,
            placeId: placeId,
            itineraryOrder: Value(existing.length),
          ),
        );
  }

  Future<void> removePlaceFromTrip(String tripId, String placeId) => (db.delete(
    db.tripPlaces,
  )..where((e) => e.tripId.equals(tripId) & e.placeId.equals(placeId))).go();

  Future<void> updateItineraryStop({
    required String entryId,
    DateTime? plannedAt,
    required String status,
    String notes = '',
  }) async {
    if (!{'planned', 'visited', 'skipped'}.contains(status)) {
      throw ArgumentError('Choose a valid stop status.');
    }
    await (db.update(db.tripPlaces)..where((e) => e.id.equals(entryId))).write(
      TripPlacesCompanion(
        plannedAt: Value(plannedAt?.toLocal()),
        status: Value(status),
        notes: Value(notes.trim()),
      ),
    );
  }

  Future<void> moveItineraryStop(
    String tripId,
    String placeId,
    int delta,
  ) async {
    final entries = await itinerary(tripId);
    final index = entries.indexWhere((e) => e.placeId == placeId);
    final next = index + delta;
    if (index < 0 || next < 0 || next >= entries.length) return;
    await db.transaction(() async {
      final first = entries[index];
      final second = entries[next];
      await (db.update(db.tripPlaces)..where((e) => e.id.equals(first.id)))
          .write(TripPlacesCompanion(itineraryOrder: Value(-1)));
      await (db.update(
        db.tripPlaces,
      )..where((e) => e.id.equals(second.id))).write(
        TripPlacesCompanion(itineraryOrder: Value(first.itineraryOrder)),
      );
      await (db.update(
        db.tripPlaces,
      )..where((e) => e.id.equals(first.id))).write(
        TripPlacesCompanion(itineraryOrder: Value(second.itineraryOrder)),
      );
    });
  }

  Future<void> saveEstimate({
    String? id,
    required String tripId,
    required String description,
    required int amountMinor,
    String category = 'Other',
    DateTime? occurredAt,
    String notes = '',
  }) async {
    if (description.trim().isEmpty || amountMinor < 0) {
      throw ArgumentError('Enter a description and a non-negative amount.');
    }
    await db
        .into(db.tripEstimates)
        .insertOnConflictUpdate(
          TripEstimatesCompanion(
            id: Value(id ?? _uuid.v4()),
            tripId: Value(tripId),
            description: Value(description.trim()),
            amountMinor: Value(amountMinor),
            category: Value(category),
            occurredAt: Value(occurredAt?.toLocal()),
            notes: Value(notes.trim()),
            createdAt: Value(DateTime.now()),
          ),
        );
  }

  Future<List<TripEstimate>> estimates(String tripId) =>
      (db.select(db.tripEstimates)
            ..where((e) => e.tripId.equals(tripId))
            ..orderBy([(e) => OrderingTerm.asc(e.occurredAt)]))
          .get();

  Future<int> estimateTotal(String tripId) async {
    final rows = await estimates(tripId);
    return rows.fold<int>(0, (sum, row) => sum + row.amountMinor);
  }

  Future<int> actualTotal(String tripId) async {
    final query = db.selectOnly(db.tripExpenseLinks)
      ..addColumns([db.moneyTransactions.amountMinor.sum()])
      ..join([
        innerJoin(
          db.moneyTransactions,
          db.moneyTransactions.id.equalsExp(db.tripExpenseLinks.transactionId),
        ),
      ])
      ..where(
        db.tripExpenseLinks.tripId.equals(tripId) &
            db.moneyTransactions.type.equals('expense'),
      );
    final row = await query.getSingle();
    return row.read(db.moneyTransactions.amountMinor.sum()) ?? 0;
  }

  Future<void> saveActualExpense({
    String? transactionId,
    required String tripId,
    required int amountMinor,
    required String accountId,
    required String categoryId,
    required DateTime occurredAt,
    required String note,
  }) async {
    if (amountMinor <= 0) {
      throw ArgumentError('Amount must be greater than zero.');
    }
    await db.transaction(() async {
      final accounts = await (db.select(
        db.moneyAccounts,
      )..where((a) => a.id.equals(accountId) & a.archivedAt.isNull())).get();
      if (accounts.isEmpty) {
        throw ArgumentError('Choose an active Money Manager account.');
      }
      final categories =
          await (db.select(db.moneyCategories)..where(
                (c) =>
                    c.id.equals(categoryId) &
                    c.type.equals('expense') &
                    c.archivedAt.isNull(),
              ))
              .get();
      if (categories.isEmpty) {
        throw ArgumentError('Choose an active expense category.');
      }
      final txnId = transactionId ?? _uuid.v4();
      final now = DateTime.now();
      final existing = await (db.select(
        db.moneyTransactions,
      )..where((t) => t.id.equals(txnId))).getSingleOrNull();
      final companion = MoneyTransactionsCompanion(
        id: Value(txnId),
        type: const Value('expense'),
        amountMinor: Value(amountMinor),
        accountId: Value(accountId),
        destinationAccountId: const Value(null),
        categoryId: Value(categoryId),
        note: Value(note.trim()),
        occurredAt: Value(occurredAt.toLocal()),
        createdAt: Value(existing?.createdAt ?? now),
        updatedAt: Value(now),
        sourceModule: const Value('trip'),
        sourceReferenceId: Value(tripId),
      );
      if (existing == null) {
        await db.into(db.moneyTransactions).insert(companion);
        await db
            .into(db.tripExpenseLinks)
            .insert(
              TripExpenseLinksCompanion.insert(
                id: txnId,
                tripId: tripId,
                transactionId: txnId,
                createdAt: now,
              ),
            );
      } else {
        final link = await (db.select(
          db.tripExpenseLinks,
        )..where((l) => l.transactionId.equals(txnId))).getSingleOrNull();
        if (link == null || link.tripId != tripId) {
          throw StateError('Transaction is not linked to this trip.');
        }
        await (db.update(
          db.moneyTransactions,
        )..where((t) => t.id.equals(txnId))).write(companion);
      }
    });
  }

  Stream<List<MoneyTransaction>> watchActualExpenses(String tripId) {
    final query =
        db.select(db.moneyTransactions).join([
          innerJoin(
            db.tripExpenseLinks,
            db.tripExpenseLinks.transactionId.equalsExp(
              db.moneyTransactions.id,
            ),
          ),
        ])..where(
          db.tripExpenseLinks.tripId.equals(tripId) &
              db.moneyTransactions.type.equals('expense'),
        );
    return query.watch().map(
      (rows) => rows.map((row) => row.readTable(db.moneyTransactions)).toList(),
    );
  }

  Future<List<SavedPlace>> placesPlannedFor(DateTime day) =>
      (db.select(db.savedPlaces)
            ..where(
              (p) =>
                  p.status.equals('planned') &
                  p.plannedAt.isBiggerOrEqualValue(
                    DateTime(day.year, day.month, day.day),
                  ) &
                  p.plannedAt.isSmallerThanValue(
                    DateTime(day.year, day.month, day.day + 1),
                  ),
            )
            ..orderBy([(p) => OrderingTerm.asc(p.plannedAt)]))
          .get();
}
