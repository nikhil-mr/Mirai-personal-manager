# Mirai

Mirai is a local-first personal management app built with Flutter and Material 3. The Money Manager stores accounts, categories, income, expenses, and transfers locally with SQLite/Drift. The Today dashboard reads daily money totals and due tasks from the local repositories.

## Run in VS Code

1. Open the `Personal-Maneger` folder in VS Code.
2. Install the Flutter extension and select the bundled Flutter SDK in `../flutter` if VS Code does not find it automatically.
3. In the integrated terminal, run `flutter pub get` from this folder.
4. Select Chrome, Windows, or another configured Flutter device in the status bar.
5. Press `F5` or run `flutter run -d chrome` / `flutter run -d windows`.

The database runs on Windows through Drift's native SQLite backend and in Chrome through Drift's SQLite WebAssembly backend. `web/sqlite3.wasm` and `web/drift_worker.js` are the matching runtime files from Drift 2.35.2. Flutter's development server serves WebAssembly with the required MIME type; deployments must serve `.wasm` as `application/wasm`. For Windows desktop builds, Flutter may require Windows Developer Mode to create plugin symlinks.

## Checks

```powershell
flutter analyze
flutter test
flutter build web
```

## Project layout

```text
lib/
  main.dart
  app/
    app.dart
    router/       # Named destinations and responsive navigation shell
    theme/        # Color, typography, Material 3 themes and appearance state
  core/widgets/   # Shared page, card, section and empty-state components
  features/
    today/
      application/  # Riverpod data and section-visibility providers
      data/         # Dashboard repository integration boundary
      domain/       # Dashboard projections and local-day calculations
      presentation/
    money/
    budgets/      # Monthly budgets, ledger-backed summaries, alerts and comparisons
    todos/
    explore/
    places/
    groceries/
    settings/
test/
  widget_test.dart
```

## Dependencies

- `flutter_riverpod` provides application state management.
- `go_router` provides named routes and the preserved four-branch navigation shell.
- `intl` formats currency amounts and local dates consistently.
- `shared_preferences` stores the selected appearance mode on the current device.
- `drift` and `drift_flutter` provide the transactional SQLite ledger for Windows and Chrome.
- `fl_chart` renders stored expense analytics; `uuid` provides stable account, category, and transaction IDs.

Money data is stored in `money_accounts`, `money_categories`, and `money_transactions`. Money is kept as integer paise. Transfers use one row with source and destination accounts and are excluded from income and expense totals. Balances are derived from each account's opening balance and ledger rows; archived account balances are excluded from the Money overview total but retained in account history. Accounts/categories are archived rather than deleting referenced history. Database schema version 3 adds task categories and task records through a Drift migration; existing ledger and budget rows are unchanged.

The Today dashboard uses the Money and To-do repositories as its projection sources. The Budget Planner stores one monthly limit per expense category and month, while spent amounts always come from canonical Money expense transactions. Positive carry-forward uses the previous month's remaining amount only when that previous budget opted in; deficits are never carried. Threshold alerts are shown in the Budget Planner as persisted in-app alerts.

## To-do Manager

Tasks support Today, Upcoming, All pending, Overdue, and Done views, title/notes/category search, category and priority filters, due dates with optional times, completion and restore, and daily progress. Undated tasks can be included in Today. Reminders are one-time notifications; recurring tasks are not currently supported.

Reminders use the operating system notification service. Android and Windows support scheduled notifications; Android may deliver less precisely when exact alarm access is unavailable. iOS/macOS ask for notification access when the user first enables a reminder. Browsers and the current Linux notification backend do not support future scheduling, so the app reports reminders as unsupported there. Windows toast cancellation and listing depend on packaged app identity; task data remains persisted if the operating system has already accepted a toast. Android notification sound behavior is controlled by notification channels and the user's system settings.

## Money Manager manual check

1. Open **Money** and create a bank account with an opening balance, then create a Cash Wallet.
2. Record an expense and income using different categories and inspect the balances and period summaries.
3. Transfer between accounts and confirm combined balance stays the same and the transfer is excluded from income and expense totals.
4. Open transaction history, search a note, filter by type/account/date, then edit and delete a transaction.
5. Change the period selector and inspect the category chart and spending trend. Archive and restore an account/category and confirm its past records remain.
6. Return to Today and confirm today's recorded income and expenses are shown there. Restart the app and confirm the ledger remains.

## Budget Planner manual check

1. Open **Money → Budgets**, choose a month, and add a budget for an existing expense category.
2. Record expenses until the category reaches 80% and 100%; confirm one in-app alert at each crossing. Income and transfers must not affect its progress.
3. Edit an expense's amount, category, or date, then confirm the affected budget updates. Delete a budget and confirm the ledger transaction remains.
4. Enable carry-forward on a month with unused budget, create the following month's budget, and inspect the base, carry-forward, and effective limits. Overspending must not create a negative carry.
5. Review the month comparison, select a previous month, and open a budget detail to inspect its contributing transactions and spending history.

## To-do manual check

1. Add tasks with a date, optional due time, different priorities, and a category; also add an undated task included in Today.
2. Check Today, Upcoming, All pending, Overdue, and Done. Search title/notes/category and combine category and priority filters.
3. Complete a task, inspect its completion time in Done, then restore it. Edit and delete tasks and confirm they persist after restarting.
4. Enable a future one-time reminder on a supported platform, change its time/sound, complete the task, and restore it. On web/Linux, confirm the app explains scheduling is unavailable.
5. Check that Today shows tasks due today and daily progress updates when a task is completed.
