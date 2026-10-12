import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_manager/features/money/data/money_database.dart';
import 'package:personal_manager/features/money/data/money_repository.dart';
import 'package:personal_manager/features/money/domain/money_models.dart';
import 'package:personal_manager/features/places/data/places_repository.dart';
import 'package:personal_manager/features/places/domain/places_logic.dart';
import 'package:personal_manager/features/today/data/today_dashboard_repository.dart';

void main() {
  late MoneyDatabase database;
  late PlacesRepository places;

  setUp(() async {
    database = MoneyDatabase(NativeDatabase.memory());
    places = PlacesRepository(database);
  });

  tearDown(() => database.close());

  test('saves custom places and status with validated coordinates', () async {
    await places.savePlace(
      name: 'Riverside garden',
      category: 'Quiet places',
      latitude: 18.5,
      longitude: 73.8,
      status: 'visited',
      rating: 5,
      review: 'Lovely walk',
    );
    final saved = (await places.places()).single;
    expect(saved.category, 'Quiet places');
    expect(saved.status, 'visited');
    expect(saved.visitedAt, isNotNull);
    expect(saved.latitude, 18.5);
    expect(saved.rating, 5);
    await expectLater(
      places.savePlace(name: 'Invalid', latitude: 91, longitude: 10),
      throwsArgumentError,
    );
  });

  test(
    'deleting a linked Money Manager transaction removes its trip total',
    () async {
      final money = MoneyRepository(database);
      await money.seedDefaults();
      await money.saveAccount(
        name: 'Card',
        type: AccountType.bank,
        openingBalanceMinor: 0,
      );
      await places.saveTrip(name: 'Day trip');
      final trip = (await places.trips()).single;
      final account = (await money.accounts()).single;
      final category = (await money.categories()).firstWhere(
        (c) => c.type == 'expense',
      );
      await places.saveActualExpense(
        transactionId: 'stable-expense-id',
        tripId: trip.id,
        amountMinor: 800,
        accountId: account.id,
        categoryId: category.id,
        occurredAt: DateTime(2026, 8, 3),
        note: 'Entry ticket',
      );
      expect(await places.actualTotal(trip.id), 800);
      await money.deleteTransaction('stable-expense-id');
      expect(await places.actualTotal(trip.id), 0);
      expect(await places.watchActualExpenses(trip.id).first, isEmpty);
    },
  );

  test(
    'one saved place can be reused and reordered in two trip itineraries',
    () async {
      await places.savePlace(name: 'Gallery');
      await places.savePlace(name: 'Garden');
      final savedPlaces = await places.places();
      final place = savedPlaces.last;
      await places.saveTrip(name: 'Weekend one');
      await places.saveTrip(name: 'Weekend two');
      final trips = await places.trips();
      await places.addPlaceToTrip(trips[0].id, place.id);
      await places.addPlaceToTrip(trips[0].id, savedPlaces.first.id);
      await places.addPlaceToTrip(trips[1].id, place.id);
      await places.addPlaceToTrip(trips[0].id, place.id);
      expect(await places.placesForTrip(trips[0].id), hasLength(2));
      await places.moveItineraryStop(trips[0].id, savedPlaces.first.id, -1);
      var itinerary = await places.itinerary(trips[0].id);
      expect(itinerary.first.placeId, savedPlaces.first.id);
      await places.updateItineraryStop(
        entryId: itinerary.first.id,
        plannedAt: DateTime(2026, 8, 4, 10),
        status: 'visited',
        notes: 'Use the side entrance',
      );
      itinerary = await places.itinerary(trips[0].id);
      expect(itinerary.first.status, 'visited');
      expect(itinerary.first.notes, 'Use the side entrance');
      expect(await places.placesForTrip(trips[1].id), hasLength(1));
      await places.deleteTrip(trips[0].id);
      expect(await places.place(place.id), isNotNull);
      expect(await places.placesForTrip(trips[1].id), hasLength(1));
    },
  );

  test(
    'rejects invalid trip dates and stores estimates as minor units',
    () async {
      await expectLater(
        places.saveTrip(
          name: 'Bad dates',
          startAt: DateTime(2026, 8, 2),
          endAt: DateTime(2026, 8, 1),
        ),
        throwsArgumentError,
      );
      await places.saveTrip(name: 'Coast trip', budgetMinor: 250000);
      final trip = (await places.trips()).single;
      await places.saveEstimate(
        tripId: trip.id,
        description: 'Train',
        amountMinor: 12550,
        category: 'Transport',
      );
      expect(await places.estimateTotal(trip.id), 12550);
    },
  );

  test('links and edits one trip expense transaction; deleting trip preserves money row', () async {
    final money = MoneyRepository(database);
    await money.seedDefaults();
    await money.saveAccount(
      name: 'Wallet',
      type: AccountType.cash,
      openingBalanceMinor: 0,
    );
    await places.saveTrip(name: 'City break');
    final trip = (await places.trips()).single;
    final account = (await money.accounts()).single;
    final category = (await money.categories()).firstWhere(
      (c) => c.type == 'expense',
    );
    await places.saveActualExpense(
      tripId: trip.id,
      amountMinor: 2450,
      accountId: account.id,
      categoryId: category.id,
      occurredAt: DateTime(2026, 8, 3),
      note: 'Museum entry',
    );
    final first = (await places.watchActualExpenses(trip.id).first).single;
    await places.saveActualExpense(
      tripId: trip.id,
      transactionId: first.id,
      amountMinor: 3000,
      accountId: account.id,
      categoryId: category.id,
      occurredAt: DateTime(2026, 8, 3),
      note: 'Museum and audio guide',
    );
    expect(await places.actualTotal(trip.id), 3000);
    expect(
      (await money.transactions()).where((t) => t.sourceModule == 'trip'),
      hasLength(1),
    );
    await places.deleteTrip(trip.id);
    expect(
      (await money.transactions()).where((t) => t.id == first.id),
      hasLength(1),
    );
  });

  test('maps URL prefers coordinates then address then name', () {
    expect(
      mapsSearchUri(
        name: 'Museum',
        address: 'Main Street',
        latitude: 12.3,
        longitude: 45.6,
      ).queryParameters['query'],
      '12.3,45.6',
    );
    expect(
      mapsSearchUri(
        name: 'Museum',
        address: 'Main Street',
      ).queryParameters['query'],
      'Main Street',
    );
    expect(mapsSearchUri(name: 'Museum').queryParameters['query'], 'Museum');
  });

  test(
    'today dashboard receives only the planned places for its local day',
    () async {
      final day = DateTime(2026, 8, 3);
      await places.savePlace(name: 'Today', plannedAt: day);
      await places.savePlace(
        name: 'Tomorrow',
        plannedAt: day.add(const Duration(days: 1)),
      );
      final snapshot = await MoneyTodayDashboardRepository(
        MoneyRepository(database),
        placesRepository: places,
      ).loadForDay(day);
      expect(snapshot.places, hasLength(1));
      expect(snapshot.places!.single.name, 'Today');
      expect(snapshot.places!.single.id, isNotNull);
    },
  );
}
