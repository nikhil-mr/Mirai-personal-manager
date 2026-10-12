import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../money/application/money_providers.dart';
import '../../money/data/money_database.dart';
import '../data/grocery_repository.dart';

final groceryRepositoryProvider = Provider<GroceryRepository>(
  (ref) => GroceryRepository(ref.watch(moneyDatabaseProvider)),
);

final groceryListsProvider = StreamProvider<List<GroceryList>>(
  (ref) => ref.watch(groceryRepositoryProvider).watchLists(),
);

final groceryArchivedListsProvider = StreamProvider<List<GroceryList>>(
  (ref) => ref.watch(groceryRepositoryProvider).watchLists(archived: true),
);

final groceryItemsProvider = StreamProvider.family<List<GroceryItem>, String>(
  (ref, listId) => ref.watch(groceryRepositoryProvider).watchItems(listId),
);

final homeInventoryProvider = StreamProvider<List<HomeInventoryItem>>(
  (ref) => ref.watch(groceryRepositoryProvider).watchInventory(),
);
