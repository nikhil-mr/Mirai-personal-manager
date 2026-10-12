import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_manager/features/money/data/money_database.dart';
import 'package:personal_manager/features/money/data/money_repository.dart';
import 'package:personal_manager/features/money/domain/money_models.dart';
import 'package:personal_manager/features/settings/data/settings_data_service.dart';

void main() {
  late MoneyDatabase database;
  late SettingsDataService service;

  setUp(() {
    database = MoneyDatabase(NativeDatabase.memory());
    service = SettingsDataService(database);
  });

  tearDown(() => database.close());

  test(
    'JSON export preserves account IDs and merge skips duplicates',
    () async {
      final repository = MoneyRepository(database);
      await repository.saveAccount(
        id: 'stable-account-id',
        name: 'Everyday',
        type: AccountType.bank,
        openingBalanceMinor: 12345,
      );
      final backup = await service.exportJson();

      final target = MoneyDatabase(NativeDatabase.memory());
      addTearDown(target.close);
      final targetService = SettingsDataService(target);
      expect(await targetService.restoreMerge(backup), 1);
      expect(await targetService.restoreMerge(backup), 0);
      final account = await (target.select(
        target.moneyAccounts,
      )..where((row) => row.id.equals('stable-account-id'))).getSingle();
      expect(account.name, 'Everyday');
      expect(account.openingBalanceMinor, 12345);
    },
  );

  test('invalid backup leaves local records unchanged', () async {
    final repository = MoneyRepository(database);
    await repository.saveAccount(
      id: 'keep-me',
      name: 'Keep me',
      type: AccountType.cash,
      openingBalanceMinor: 100,
    );

    await expectLater(
      service.restoreMerge('{"format":"wrong"}'),
      throwsFormatException,
    );
    expect((await repository.accounts()).single.id, 'keep-me');
  });

  test('clear removes local records', () async {
    final repository = MoneyRepository(database);
    await repository.saveAccount(
      name: 'Temporary',
      type: AccountType.other,
      openingBalanceMinor: 0,
    );
    await service.clearRecords();
    expect(await repository.accounts(includeArchived: true), isEmpty);
  });
}
