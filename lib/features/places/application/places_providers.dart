import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../money/application/money_providers.dart';
import '../../money/data/money_database.dart';
import '../data/places_repository.dart';

final placesRepositoryProvider = Provider<PlacesRepository>(
  (ref) => PlacesRepository(ref.watch(moneyDatabaseProvider)),
);

final savedPlacesProvider = StreamProvider<List<SavedPlace>>(
  (ref) => ref.watch(placesRepositoryProvider).watchPlaces(),
);

final tripsProvider = StreamProvider<List<TravelTrip>>(
  (ref) => ref.watch(placesRepositoryProvider).watchTrips(),
);

final placeCategoriesProvider = StreamProvider<List<PlaceCategory>>((ref) {
  final repo = ref.watch(placesRepositoryProvider);
  repo.seedDefaultCategories();
  return repo.watchCategories();
});
