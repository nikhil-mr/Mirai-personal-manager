import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../money/application/money_providers.dart';
import '../data/settings_data_service.dart';

final settingsDataServiceProvider = Provider<SettingsDataService>(
  (ref) => SettingsDataService(ref.watch(moneyDatabaseProvider)),
);
