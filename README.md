# 🐈 Mirai — Personal Manager

**One app. Your money, tasks, trips, and everyday life.**

Mirai is a Flutter-based personal management application designed to bring everyday organization into one place. It combines personal finance tracking, budget planning, task management, places and trips, and grocery lists in a single application with a distinctive neo-brutalist user interface.

Built with Flutter and Dart, Mirai aims to provide a clean, practical, and intuitive experience for managing daily activities and understanding personal finances.

---

## 📌 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [UI and Design](#-ui-and-design)
- [Technology Stack](#-technology-stack)
- [Project Structure](#-project-structure)
- [Getting Started](#-getting-started)
- [Running the Application](#-running-the-application)
- [Building the APK](#-building-the-apk)
- [Data Management](#-data-management)
- [Development Roadmap](#-development-roadmap)
- [Contributing](#-contributing)
- [License](#-license)

---

## 🚀 Overview

Managing finances, remembering tasks, planning trips, and maintaining shopping lists often requires multiple applications. Mirai brings these activities together in a unified personal management experience.

The application is organized around five main navigation destinations:

| Module | Purpose |
|---|---|
| 🏠 Home | A daily overview of finances, tasks, and planned activities |
| 💰 Money | Track income, expenses, accounts, and financial activity |
| ✅ To-do | Organize tasks, reminders, and daily priorities |
| 📍 Places | Save places and organize trips |
| 🛒 Grocery | Manage grocery and shopping lists |

Additional functionality includes budget planning, settings, and a Quick Add interface for accessing common creation flows.

Mirai follows a local-first approach, prioritizing access to personal information stored on the device while allowing room for optional cloud synchronization.

## ✨ Features

### 🏠 1. Home Dashboard

The Home Page provides a central overview of daily activities and personal finances.

Key capabilities include:

- Personalized greeting and date display.
- Financial summaries for spending and income.
- Spending breakdown by category.
- Task progress overview.
- Summary of planned places and trips.
- Navigation to the relevant management modules.
- Floating Quick Add button for creating new entries.

The dashboard is designed to make important information accessible without requiring the user to navigate through multiple screens.

### 💰 2. Money Manager

The Money Manager helps users record and review their financial activity.

Core functionality includes:

- Recording income and expenses.
- Organizing transactions by category.
- Managing financial accounts.
- Viewing transaction history.
- Reviewing balances and financial summaries.
- Exploring spending patterns and category breakdowns.
- Accessing budget-related tools.
- Importing and exporting financial data where supported.

The financial interface is designed to provide a clear overview of money coming in, money going out, and how spending is distributed.

#### Transaction types

| Type | Description |
|---|---|
| Expense | Records money spent |
| Income | Records money received |
| Transfer | Represents movement of money between accounts, where supported |

Transfers should be distinguished from income and expenses to prevent misleading financial summaries.

### 📊 3. Budget Planner

The Budget Planner is intended to help users organize spending limits and monitor their finances.

Planned and applicable capabilities include:

- Creating budgets.
- Organizing budgets by category.
- Tracking spending against budget limits.
- Reviewing remaining budget amounts.
- Monitoring progress over a selected period.

Budget calculations should use actual transaction data rather than independently maintained totals.

### ✅ 4. To-do Manager

The To-do Manager helps users organize everyday responsibilities and activities.

Its intended capabilities include:

- Creating and managing tasks.
- Tracking task completion.
- Organizing daily priorities.
- Recording task-related details.
- Supporting due dates and reminders where implemented.
- Displaying task progress on the Home Page.

The goal is to keep personal tasks accessible alongside financial and planning information.

### 📍 5. Places & Trips

The Places module provides a place to save locations and organize travel plans.

Its intended capabilities include:

- Saving places of interest.
- Recording place details and notes.
- Organizing planned destinations.
- Associating dates with trips where supported.
- Accessing saved places from the dedicated module.

The module is designed to keep useful locations and travel plans organized within the same personal management application.

### 🛒 6. Grocery Basket

The Grocery module helps users maintain grocery and shopping lists.

Its intended capabilities include:

- Adding grocery or shopping items.
- Recording item details and quantities where supported.
- Organizing items in a list.
- Tracking completed or purchased items.
- Managing shopping information from a dedicated screen.

Quick Add provides a shortcut to the existing item creation flow.

### ⚡ 7. Quick Add

Mirai includes a floating yellow plus button that opens a dedicated Quick Add bottom sheet.

The interface uses a two-column, two-row grid containing four actions:

| Action | Purpose |
|---|---|
| Transaction | Add an expense, income, or supported transfer |
| Task | Create a task or reminder |
| Place | Save a location or plan a trip |
| Item | Add a grocery or shopping item |

The design uses distinct yellow, pink, purple, and cyan cards, bold typography, dark outlines, and hard offset shadows.

Quick Add is designed to make common actions accessible without requiring users to navigate to the relevant module first.

### 🎨 8. Settings and Customization

The Settings module provides a place for application preferences.

Depending on the implemented configuration, this may include:

- Display preferences.
- Currency settings.
- Theme preferences.
- Data-related options.
- Synchronization settings where supported.

Currency conversion and cloud synchronization require the appropriate implementation and configuration; changing a currency symbol alone does not perform an exchange-rate conversion.

---

## 🎨 UI and Design

Mirai uses a **neo-brutalist design language** with bold outlines, strong colours, simple icons, and hard shadows.

### Design principles

- **Clarity:** Present important information prominently.
- **Consistency:** Reuse common components and visual patterns.
- **Accessibility:** Keep text readable and interactive elements easy to use.
- **Efficiency:** Reduce the number of steps required for common actions.
- **Visual identity:** Use a playful cat mascot alongside a distinctive colour palette.

### Colour palette

| Colour | Hex value | Usage |
|---|---|---|
| Primary Yellow | `#FFDF24` | Primary actions and active navigation |
| Warm Cream | `#FFF9F0` | Main light-mode background |
| Soft Cream | `#FDF9ED` | Cards and surfaces |
| Near Black | `#111111` | Text, outlines, and shadows |
| Hot Pink | `#FF2D91` | Quick Add Task card |
| Purple | `#843CFF` | Quick Add Place card |
| Cyan | `#00BFF3` | Quick Add Item card |
| Orange | `#FF7900` | Transaction accent |

The design system can be extended with appropriate theme-aware surfaces and text colours for dark mode.

---

## 🛠️ Technology Stack

Mirai is built using the Flutter ecosystem.

| Technology | Purpose |
|---|---|
| Flutter | Cross-platform application framework |
| Dart | Application programming language |
| Riverpod | State management and reactive data flow |
| SQLite / Drift | Local relational data persistence, as configured in the project |
| fl_chart | Financial charts and visualizations |
| Supabase | Optional backend and synchronization integration, where configured |
| Git | Version control |
| GitHub | Source code hosting and collaboration |
| VS Code | Development environment |

The exact dependencies and versions are defined in `pubspec.yaml`.

---

## 🏗️ Project Structure

The following is a conceptual structure for organizing the application's code. Refer to the actual project files for the current implementation.

```text
mirai-personal-manager/
│
├── android/                 # Android platform configuration
├── ios/                     # iOS platform configuration
├── web/                     # Web platform configuration, if enabled
├── windows/                 # Windows platform configuration, if enabled
│
├── assets/
│   └── images/              # Mascot and application artwork
│
├── lib/
│   ├── main.dart            # Application entry point
│   ├── models/              # Application data models
│   ├── providers/           # State management and providers
│   ├── repositories/        # Data access and business operations
│   ├── database/            # Local database and migrations
│   ├── screens/             # Application screens
│   ├── widgets/             # Reusable UI components
│   ├── services/            # Supporting services
│   └── utils/               # Shared utilities and helpers
│
├── test/                    # Automated tests
├── pubspec.yaml             # Dependencies and asset configuration
├── pubspec.lock             # Resolved dependency versions
├── analysis_options.yaml    # Dart analysis configuration
└── README.md                # Project documentation
```

This is an illustrative structure, not a requirement to reorganize the existing codebase to match these folder names.

---

## ⚙️ Getting Started

### Prerequisites

Install the following tools before running the application:

- Flutter SDK.
- Dart SDK compatible with the installed Flutter version.
- Android Studio or Android SDK tools for Android development.
- Visual Studio Code or another compatible editor.
- Git.

Verify your Flutter installation:

```bash
flutter doctor
```

Resolve any required Android SDK, device, or toolchain issues reported by Flutter.

### 1. Clone the repository

Replace `YOUR_GITHUB_USERNAME` with your GitHub username.

```bash
git clone https://github.com/YOUR_GITHUB_USERNAME/mirai-personal-manager.git
```

### 2. Open the project

```bash
cd mirai-personal-manager
```

### 3. Install dependencies

```bash
flutter pub get
```

### 4. Check available devices

```bash
flutter devices
```

Connect an Android device with USB debugging enabled or start an Android emulator.

### 5. Run the application

```bash
flutter run
```

Flutter will compile the application and launch it on the selected device.

---

## 📱 Running on Android

To run Mirai on a connected Android phone:

1. Enable Developer Options on your device.
2. Enable USB debugging.
3. Connect the device to your computer.
4. Run `flutter devices` to verify that the device is detected.
5. Execute:

```bash
flutter run
```

If multiple devices are connected, specify the appropriate device ID:

```bash
flutter run -d DEVICE_ID
```

Replace `DEVICE_ID` with the ID returned by `flutter devices`.

---

## 📦 Building the Release APK

To generate an Android release APK:

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

The expected output path is:

```text
build/app/outputs/flutter-apk/app-release.apk
```

The generated APK can be copied to a compatible Android device for installation.

For a smaller distribution size, Flutter also supports building separate APKs for supported Android architectures:

```bash
flutter build apk --split-per-abi
```

Build success depends on the project's current configuration and the availability of the required Android toolchain.

---

## 💾 Data Management

Mirai is designed around local-first personal management.

### Local persistence

Local database storage is intended to keep personal information available across application launches.

Financial records, tasks, places, grocery items, and settings should use the existing persistence layer where implemented.

### Financial data integrity

Financial calculations require particular care:

- Expenses and income must be distinguished.
- Transfers must not be counted as income or expenses.
- Account balances must respect opening balances and account activity.
- Currency formatting must reflect the selected display currency.
- Original transaction amounts should be preserved when displaying converted values.
- Database migrations must preserve existing user data.

### Optional synchronization

Supabase may be used for cloud synchronization if the relevant integration is configured.

Cloud synchronization requires appropriate project configuration, credentials, access policies, and conflict-handling logic. It should not be assumed to be active simply because the dependency is present.

**Important:** Never commit API secrets, private keys, passwords, or sensitive environment files to a public repository.

---

## 🧪 Testing and Code Quality

Run static analysis:

```bash
flutter analyze
```

Run the automated test suite:

```bash
flutter test
```

Before submitting changes, verify the following where applicable:

- Transactions are saved and retrieved correctly.
- Income, expense, and transfer calculations are correct.
- Date filters handle day, week, month, and year boundaries.
- Account balances remain consistent.
- Tasks and grocery items persist correctly.
- Theme changes do not break text readability.
- Navigation and Quick Add actions open the expected screens.
- Existing data remains accessible after database migrations.

Only mark tests as passing after they have actually been executed successfully.

---

## 🗺️ Development Roadmap

Potential improvements for future development include:

- [ ] Refine the Home dashboard and date-navigation experience.
- [ ] Improve account-specific filtering throughout Money Manager.
- [ ] Expand financial analytics and spending visualizations.
- [ ] Strengthen budget tracking and progress reporting.
- [ ] Improve currency selection and reliable exchange-rate conversion.
- [ ] Expand Quick Add workflows.
- [ ] Improve theme consistency across all screens.
- [ ] Enhance data import and export.
- [ ] Add automated tests for financial calculations and database migrations.
- [ ] Improve optional cloud synchronization and conflict handling.
- [ ] Refine responsive layouts across Android devices.

The roadmap describes potential development work; individual items should be marked complete only after implementation and verification.

---

## 🤝 Contributing

Contributions, suggestions, and bug reports are welcome.

To propose a change:

1. Fork the repository.
2. Create a feature branch.
3. Implement your change.
4. Run `flutter analyze` and relevant tests.
5. Commit your changes with a clear message.
6. Open a pull request describing the change.

Example:

```bash
git checkout -b feature/improve-dashboard
git add .
git commit -m "Improve home dashboard layout"
git push origin feature/improve-dashboard
```

For larger changes, consider opening an issue first to discuss the design and implementation approach.

---

## 🔐 Security and Privacy

Personal finance applications handle sensitive information.

When contributing to or deploying Mirai:

- Never commit secrets or credentials.
- Validate user input.
- Handle imported files carefully.
- Protect cloud resources using appropriate access policies.
- Preserve user data during migrations.
- Avoid logging sensitive financial details unnecessarily.

Review the application's actual storage and synchronization implementation before making claims about encryption, backups, or cloud security.

---

## 📄 License

No license has been specified in this README.

Before publishing the repository, choose an appropriate license and add its corresponding `LICENSE` file. Until then, do not assume that the project is open source or that others have permission to redistribute or modify it.

---

## 💛 About Mirai

Mirai brings personal finance, daily tasks, trip planning, and shopping organization into one unified experience.

Its goal is simple: **make everyday personal management more organized, more accessible, and easier to understand.**

Built with Flutter and Dart, Mirai is an evolving project focused on usability, consistent design, and reliable personal data management.

---

**Repository:** `mirai-personal-manager`

**Primary technologies:** Flutter · Dart · Riverpod · SQLite/Drift

**Project status:** In development
