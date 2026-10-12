import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../money/data/money_database.dart';
import '../../money/data/money_repository.dart';
import '../domain/budget_models.dart';

class BudgetRepository {
  BudgetRepository(this.db, this.money);
  final MoneyDatabase db;
  final MoneyRepository money;
  static const _uuid = Uuid();

  Future<List<BudgetPlan>> plans() => db.select(db.budgetPlans).get();

  Future<void> save({
    String? id,
    required String categoryId,
    required int baseAmountMinor,
    required DateTime month,
    required bool rolloverEnabled,
    required bool alert80Enabled,
    required bool alert100Enabled,
  }) async {
    if (baseAmountMinor <= 0) {
      throw ArgumentError('Budget amount must be greater than zero.');
    }
    final category = await (db.select(
      db.moneyCategories,
    )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
    if (category == null || category.type != 'expense') {
      throw ArgumentError('Choose an expense category.');
    }
    final period = budgetMonth(month);
    final duplicate =
        await (db.select(db.budgetPlans)..where(
              (b) =>
                  b.categoryId.equals(categoryId) &
                  b.periodStart.equals(period),
            ))
            .getSingleOrNull();
    if (duplicate != null && duplicate.id != id) {
      throw ArgumentError(
        'A budget already exists for this category and month.',
      );
    }
    final now = DateTime.now();
    if (id == null) {
      await db
          .into(db.budgetPlans)
          .insert(
            BudgetPlansCompanion.insert(
              id: _uuid.v4(),
              categoryId: categoryId,
              baseAmountMinor: baseAmountMinor,
              periodStart: period,
              rolloverEnabled: Value(rolloverEnabled),
              alert80Enabled: Value(alert80Enabled),
              alert100Enabled: Value(alert100Enabled),
              createdAt: now,
              updatedAt: now,
            ),
          );
    } else {
      final existing = await (db.select(
        db.budgetPlans,
      )..where((b) => b.id.equals(id))).getSingleOrNull();
      if (existing == null) throw StateError('Budget no longer exists.');
      await db.transaction(() async {
        if (existing.categoryId != categoryId ||
            existing.periodStart != period) {
          await (db.delete(
            db.budgetAlertStates,
          )..where((a) => a.budgetId.equals(id))).go();
        }
        await (db.update(db.budgetPlans)..where((b) => b.id.equals(id))).write(
          BudgetPlansCompanion(
            categoryId: Value(categoryId),
            baseAmountMinor: Value(baseAmountMinor),
            periodStart: Value(period),
            rolloverEnabled: Value(rolloverEnabled),
            alert80Enabled: Value(alert80Enabled),
            alert100Enabled: Value(alert100Enabled),
            updatedAt: Value(now),
          ),
        );
      });
    }
  }

  Future<void> delete(String id) async {
    await db.transaction(() async {
      await (db.delete(
        db.budgetAlertStates,
      )..where((a) => a.budgetId.equals(id))).go();
      await (db.delete(db.budgetPlans)..where((b) => b.id.equals(id))).go();
    });
  }

  Future<BudgetMonthSnapshot> snapshot(
    DateTime selectedMonth, {
    bool evaluateAlerts = true,
  }) async {
    final month = budgetMonth(selectedMonth);
    final allPlans = await plans();
    final categories = {
      for (final c in await money.categories(includeArchived: true)) c.id: c,
    };
    final allTransactions = await money.transactions();
    final expenseByMonthCategory = <(int, int, String), int>{};
    final allExpenseByMonth = <(int, int), int>{};
    for (final tx in allTransactions.where(
      (t) => t.type == 'expense' && t.categoryId != null,
    )) {
      final m = budgetMonth(tx.occurredAt.toLocal());
      expenseByMonthCategory.update(
        (m.year, m.month, tx.categoryId!),
        (v) => v + tx.amountMinor,
        ifAbsent: () => tx.amountMinor,
      );
      allExpenseByMonth.update(
        (m.year, m.month),
        (v) => v + tx.amountMinor,
        ifAbsent: () => tx.amountMinor,
      );
    }
    final planMap = {
      for (final p in allPlans)
        (p.categoryId, p.periodStart.year, p.periodStart.month): p,
    };
    final effective = <String, ({int carry, int total})>{};
    ({int carry, int total}) calculation(BudgetPlan plan, [int depth = 0]) {
      final cached = effective[plan.id];
      if (cached != null) return cached;
      var carry = 0;
      if (depth < allPlans.length) {
        final prev = DateTime(
          plan.periodStart.year,
          plan.periodStart.month - 1,
        );
        final prior = planMap[(plan.categoryId, prev.year, prev.month)];
        if (prior != null && prior.rolloverEnabled) {
          final priorValues = calculation(prior, depth + 1);
          final spent =
              expenseByMonthCategory[(
                prev.year,
                prev.month,
                plan.categoryId,
              )] ??
              0;
          carry = (priorValues.total - spent).clamp(0, 1 << 62);
        }
      }
      final result = (carry: carry, total: plan.baseAmountMinor + carry);
      effective[plan.id] = result;
      return result;
    }

    final monthPlans = allPlans
        .where(
          (p) =>
              p.periodStart.year == month.year &&
              p.periodStart.month == month.month,
        )
        .toList();
    final lines = <BudgetLine>[];
    for (final plan in monthPlans) {
      final category = categories[plan.categoryId];
      if (category == null) continue;
      final values = calculation(plan);
      lines.add(
        BudgetLine(
          plan: plan,
          category: category,
          spentMinor:
              expenseByMonthCategory[(
                month.year,
                month.month,
                plan.categoryId,
              )] ??
              0,
          carryMinor: values.carry,
          effectiveMinor: values.total,
        ),
      );
    }
    lines.sort(
      (a, b) => a.category.name.toLowerCase().compareTo(
        b.category.name.toLowerCase(),
      ),
    );
    final spentInMonth = allExpenseByMonth[(month.year, month.month)] ?? 0;
    final budgeted = lines.fold<int>(0, (sum, line) => sum + line.spentMinor);
    final alerts = evaluateAlerts
        ? await _evaluate(lines, month)
        : const <BudgetAlert>[];
    return BudgetMonthSnapshot(
      month: month,
      lines: lines,
      unbudgetedSpendMinor: spentInMonth - budgeted,
      allExpenseMinor: spentInMonth,
      transactions: allTransactions
          .where(
            (t) =>
                t.type == 'expense' &&
                t.occurredAt.year == month.year &&
                t.occurredAt.month == month.month,
          )
          .toList(),
      alerts: alerts,
    );
  }

  Future<List<BudgetAlert>> _evaluate(
    List<BudgetLine> lines,
    DateTime month,
  ) async {
    final created = <BudgetAlert>[];
    for (final line in lines) {
      for (final threshold in [80, 100]) {
        final enabled = threshold == 80
            ? line.plan.alert80Enabled
            : line.plan.alert100Enabled;
        final above =
            line.effectiveMinor > 0 &&
            line.spentMinor * 100 >= line.effectiveMinor * threshold;
        final state =
            await (db.select(db.budgetAlertStates)..where(
                  (a) =>
                      a.budgetId.equals(line.plan.id) &
                      a.periodStart.equals(month) &
                      a.threshold.equals(threshold),
                ))
                .getSingleOrNull();
        if (!enabled) {
          if (state != null) {
            await (db.update(db.budgetAlertStates)
                  ..where((a) => a.id.equals(state.id)))
                .write(const BudgetAlertStatesCompanion(isAbove: Value(false)));
          }
          continue;
        }
        if (state == null) {
          final now = DateTime.now();
          final shouldTrigger = above;
          await db
              .into(db.budgetAlertStates)
              .insert(
                BudgetAlertStatesCompanion.insert(
                  id: _uuid.v4(),
                  budgetId: line.plan.id,
                  periodStart: month,
                  threshold: threshold,
                  isAbove: Value(above),
                  lastTriggeredAt: Value(shouldTrigger ? now : null),
                ),
              );
          if (shouldTrigger) {
            created.add(BudgetAlert(line.category.name, threshold));
          }
        } else if (above != state.isAbove) {
          final now = DateTime.now();
          await (db.update(
            db.budgetAlertStates,
          )..where((a) => a.id.equals(state.id))).write(
            BudgetAlertStatesCompanion(
              isAbove: Value(above),
              lastTriggeredAt: Value(above ? now : state.lastTriggeredAt),
            ),
          );
          if (above) created.add(BudgetAlert(line.category.name, threshold));
        }
      }
    }
    return created;
  }
}
