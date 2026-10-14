import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/theme_controller.dart';
import '../../money/application/money_providers.dart';
import '../../money/data/money_excel_service.dart';
import '../../money/domain/money_models.dart';

const _cream = Color(0xFFFFF9F0);
const _ink = Color(0xFF111111);
const _yellow = Color(0xFFFFDF24);
const _setupKey = 'life_partner_setup_complete_v1';

class _Feature {
  const _Feature(
    this.title,
    this.description,
    this.asset,
    this.color, {
    this.imageScale = 1,
  });
  final String title, description, asset;
  final Color color;
  final double imageScale;
}

const _features = [
  _Feature(
    'Money Manager',
    'Track your income, expenses and budgets. Get clear insights and stay in control.',
    'assets/images/3.png',
    _cream,
    imageScale: .9,
  ),
  _Feature(
    'To-do Manager',
    'Turn plans into progress. Manage tasks, set reminders and never miss a thing.',
    'assets/images/4.png',
    _yellow,
    imageScale: .9,
  ),
  _Feature(
    'Places & Trips',
    'Save your favorite places, plan trips and remember amazing locations.',
    'assets/images/5.png',
    _cream,
    imageScale: .9,
  ),
  _Feature(
    'Grocery Basket',
    'Keep track of what you have at home and what you need to buy. Stay organized.',
    'assets/images/6.png',
    Color(0xFFFDF9ED),
  ),
  _Feature(
    'Budget Planner',
    'Plan your spending, set limits and reach your goals.',
    'assets/images/7.png',
    _cream,
    imageScale: .9,
  ),
  _Feature(
    'Everything Together',
    'All the important parts of your daily life in one simple, beautiful app.',
    'assets/images/8.png',
    _yellow,
    imageScale: .9,
  ),
];

Future<void> _completeSetup(WidgetRef ref) async {
  await ref.read(sharedPreferencesProvider).setBool(_setupKey, true);
}

class LaunchScreen extends ConsumerStatefulWidget {
  const LaunchScreen({super.key});
  @override
  ConsumerState<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends ConsumerState<LaunchScreen> {
  String? _error;
  bool _checking = false;
  double _progress = 0.2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveLaunch());
  }

  Future<void> _resolveLaunch() async {
    if (_checking) return;
    _checking = true;
    try {
      setState(() => _progress = 0.5);
      final done =
          ref.read(sharedPreferencesProvider).getBool(_setupKey) ?? false;
      await ref.read(moneyDatabaseProvider).customSelect('SELECT 1').get();
      setState(() => _progress = 1.0);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (mounted) context.go(done ? AppRoutes.startup : AppRoutes.welcome);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not prepare local data: $error');
      }
    } finally {
      _checking = false;
    }
  }

  @override
  Widget build(BuildContext context) => MiraiLoadingView(
    progress: _progress,
    error: _error,
    onRetry: _resolveLaunch,
  );
}

class MiraiLoadingView extends StatefulWidget {
  const MiraiLoadingView({
    required this.progress,
    this.error,
    this.onRetry,
    super.key,
  });

  final double progress;
  final String? error;
  final VoidCallback? onRetry;

  @override
  State<MiraiLoadingView> createState() => _MiraiLoadingViewState();
}

class _MiraiLoadingViewState extends State<MiraiLoadingView>
    with TickerProviderStateMixin {
  late final AnimationController _floatController;
  late final AnimationController _fadeController;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _shapesFloat;
  late final Animation<double> _pulseFade;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _shapesFloat = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _pulseFade = Tween<double>(begin: 0.35, end: 0.85).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0.0, 0.2), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
          ),
        );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
      ),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandYellow = Color(0xFFFFDF24);
    const brandCream = Color(0xFFFFF9F0);
    const brandInk = Color(0xFF111111);
    const trackYellow = Color(0xFFE0C220);

    return Scaffold(
      backgroundColor: brandYellow,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Stack(
                children: [
                  Positioned(
                    top: -60 + _shapesFloat.value,
                    right: -50 + _shapesFloat.value,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: const BoxDecoration(
                        color: brandCream,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -40 - _shapesFloat.value,
                    left: -40 + _shapesFloat.value,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        color: brandCream,
                        borderRadius: BorderRadius.circular(90),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 100 + (_shapesFloat.value * 0.5),
                    left: 40,
                    child: Opacity(
                      opacity: _pulseFade.value,
                      child: Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: brandInk,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 240 - (_shapesFloat.value * 0.5),
                    right: 36,
                    child: Opacity(
                      opacity: _pulseFade.value,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: brandCream,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 120 + (_shapesFloat.value * 0.5),
                    right: 60,
                    child: Opacity(
                      opacity: _pulseFade.value,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: brandInk,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const SizedBox(height: 48),
                      FadeTransition(
                        opacity: _titleFade,
                        child: SlideTransition(
                          position: _titleSlide,
                          child: const Text(
                            'Mirai',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: brandInk,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      FadeTransition(
                        opacity: _taglineFade,
                        child: const Text(
                          'Organize today.\nBuild a better tomorrow.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: brandInk,
                            height: 1.3,
                          ),
                        ),
                      ),
                      if (widget.error != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: brandCream,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: brandInk, width: 1.5),
                          ),
                          child: Column(
                            children: [
                              Text(
                                widget.error!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: brandInk,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (widget.onRetry != null) ...[
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: brandInk,
                                    foregroundColor: brandCream,
                                  ),
                                  onPressed: widget.onRetry,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      SizedBox(
                        height: (constraints.maxHeight * 0.28).clamp(
                          120.0,
                          220.0,
                        ),
                        child: Image.asset(
                          'assets/images/0.png',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.pets,
                            size: 100,
                            color: brandInk,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 220,
                        height: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Stack(
                            children: [
                              Container(color: trackYellow),
                              FractionallySizedBox(
                                widthFactor: widget.progress.clamp(0.0, 1.0),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  color: brandInk,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'LOADING...',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                          color: brandInk,
                        ),
                      ),
                      const SizedBox(height: 36),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => _IntroScaffold(
    background: const Color(0xFFFDF9ED),
    waveColor: const Color(0xFF956EFD),
    topAction: TextButton(
      onPressed: () async {
        await _completeSetup(ref);
        if (context.mounted) context.go(AppRoutes.startup);
      },
      child: const Text('Skip'),
    ),
    description: 'Your all-in-one companion to manage money, tasks, places, groceries and more.',
    asset: 'assets/images/2.png',
    button: 'Get Started',
    onPressed: () => context.go(AppRoutes.onboarding),
  );
}

class FeatureOnboardingScreen extends StatefulWidget {
  const FeatureOnboardingScreen({super.key});
  @override
  State<FeatureOnboardingScreen> createState() =>
      _FeatureOnboardingScreenState();
}

class _FeatureOnboardingScreenState extends State<FeatureOnboardingScreen> {
  final _controller = PageController();
  int _index = 0;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int next) {
    if (next < 0 || next >= _features.length) return;
    setState(() => _index = next);
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 230),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final feature = _features[_index];
    return Scaffold(
      backgroundColor: feature.color,
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (_index == 0) {
                            context.go(AppRoutes.welcome);
                          } else {
                            _go(_index - 1);
                          }
                        },
                        icon: const Icon(Icons.arrow_back),
                      ),
                      const Spacer(),
                      Text(
                        '${_index + 1}/6',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _features.length,
                      onPageChanged: (i) => setState(() => _index = i),
                      itemBuilder: (_, i) =>
                          _FeaturePanel(feature: _features[i]),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      4,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == (_index * 4 ~/ 6).clamp(0, 3) ? 23 : 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: i == (_index * 4 ~/ 6).clamp(0, 3)
                              ? _ink
                              : Colors.transparent,
                          border: Border.all(color: _ink, width: 1.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _PrimaryButton(
                    label: _index == 5 ? 'Continue' : 'Next',
                    onPressed: () => _index == 5
                        ? context.go(AppRoutes.excelImport)
                        : _go(_index + 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturePanel extends StatelessWidget {
  const _FeaturePanel({required this.feature});
  final _Feature feature;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Expanded(
        flex: 6,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: FractionallySizedBox(
            widthFactor: feature.imageScale,
            heightFactor: feature.imageScale,
            child: Image.asset(
              feature.asset,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.auto_awesome, size: 100),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      Text(
        feature.title,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 29,
          color: _ink,
        ),
      ),
      const SizedBox(height: 10),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Text(
          feature.description,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, height: 1.45, color: _ink),
        ),
      ),
      const SizedBox(height: 22),
    ],
  );
}

class _WelcomeWavePainter extends CustomPainter {
  const _WelcomeWavePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, size.height * .08)
      ..cubicTo(
        size.width * .16,
        size.height * -.04,
        size.width * .3,
        size.height * .18,
        size.width * .48,
        size.height * .08,
      )
      ..cubicTo(
        size.width * .66,
        size.height * -.02,
        size.width * .82,
        size.height * .16,
        size.width,
        size.height * .06,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _WelcomeWavePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _IntroScaffold extends StatelessWidget {
  const _IntroScaffold({
    required this.background,
    required this.description,
    required this.asset,
    required this.button,
    required this.onPressed,
    this.waveColor,
    this.topAction,
  });
  final Color background;
  final String description, asset, button;
  final VoidCallback onPressed;
  final Color? waveColor;
  final Widget? topAction;
  Widget get _heading => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text(
        'Welcome to',
        style: TextStyle(
          fontSize: 29,
          height: 1,
          fontWeight: FontWeight.w900,
          color: _ink,
        ),
      ),
      const SizedBox(height: 4),
      Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mirai!',
            style: TextStyle(
              fontSize: 40,
              height: 1,
              fontWeight: FontWeight.w900,
              color: _ink,
              letterSpacing: -1.4,
            ),
          ),
          const SizedBox(width: 6),
          Transform.rotate(
            angle: -.12,
            child: Container(
              margin: const EdgeInsets.only(top: 1),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.pink,
                border: Border.all(color: _ink, width: 2),
                borderRadius: BorderRadius.circular(7),
                boxShadow: const [BoxShadow(color: _ink, offset: Offset(2, 2))],
              ),
              child: const Text(
                'HEY!',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: _ink,
                ),
              ),
            ),
          ),
        ],
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: background,
    body: Stack(
      children: [
        if (waveColor != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: MediaQuery.sizeOf(context).height / 3,
            child: CustomPaint(painter: _WelcomeWavePainter(color: waveColor!)),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
            child: Column(
              children: [
                SizedBox(
                  height: 44,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: topAction,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  label: 'Welcome to Mirai!',
                  child: FittedBox(fit: BoxFit.scaleDown, child: _heading),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, height: 1.4),
                ),
                Expanded(
                  child: FractionallySizedBox(
                    widthFactor: .75,
                    heightFactor: .75,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Image.asset(
                        asset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.pets, size: 120),
                      ),
                    ),
                  ),
                ),
                _PrimaryButton(label: button, onPressed: onPressed),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class ImportPreviewData {
  const ImportPreviewData({
    required this.preview,
    required this.bytes,
    required this.newAccounts,
    required this.newCategories,
    required this.possibleDuplicates,
  });
  final MoneyExcelPreview preview;
  final Uint8List bytes;
  final int newAccounts;
  final int newCategories;
  final int possibleDuplicates;
}

class ExcelImportScreen extends ConsumerStatefulWidget {
  const ExcelImportScreen({super.key});
  @override
  ConsumerState<ExcelImportScreen> createState() => _ExcelImportScreenState();
}

class _ExcelImportScreenState extends ConsumerState<ExcelImportScreen> {
  Uint8List? _bytes;
  String? _fileName, _error;
  bool _busy = false;
  Future<void> _pick() async {
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
      );
      if (picked == null) return;
      final name = picked.name;
      if (!name.toLowerCase().endsWith('.xlsx')) {
        throw const FormatException('Choose an .xlsx workbook.');
      }
      final bytes = await picked.readAsBytes();
      if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
        throw const FormatException('This file is not a valid Excel workbook.');
      }
      final preview = MoneyExcelService().parse(bytes);
      final repository = ref.read(moneyRepositoryProvider);
      final accountRows = await repository.accounts(includeArchived: true);
      final categoryRows = await repository.categories(includeArchived: true);
      final transactions = await repository.transactions();
      final accountNames = accountRows
          .map((row) => row.name.trim().toLowerCase())
          .toSet();
      final categoryNames = categoryRows
          .map((row) => '${row.type}:${row.name.trim().toLowerCase()}')
          .toSet();
      final accountsById = {for (final row in accountRows) row.id: row.name};
      final categoriesById = {
        for (final row in categoryRows)
          row.id: '${row.type}:${row.name.trim().toLowerCase()}',
      };
      final validRows = preview.rows.where((row) => row.valid).toList();
      final importedRefs = transactions
          .where((row) => row.sourceModule == 'excel_import')
          .map((row) => row.sourceReferenceId)
          .whereType<String>()
          .toSet();
      final possibleDuplicates = validRows.where((row) {
        if (importedRefs.contains(row.fingerprint)) return true;
        return transactions.any(
          (existing) =>
              existing.type == row.type!.name &&
              existing.occurredAt.isAtSameMomentAs(row.date!) &&
              existing.amountMinor == row.amountMinor &&
              accountsById[existing.accountId]?.trim().toLowerCase() ==
                  row.account.trim().toLowerCase() &&
              (existing.destinationAccountId == null
                  ? row.destination == null
                  : accountsById[existing.destinationAccountId]
                            ?.trim()
                            .toLowerCase() ==
                        row.destination?.trim().toLowerCase()) &&
              (existing.categoryId == null
                  ? row.category == null
                  : categoriesById[existing.categoryId] ==
                        '${row.type!.name}:${row.category!.trim().toLowerCase()}') &&
              existing.note.trim() == row.note.trim(),
        );
      }).length;
      final importedAccountNames = <String>{
        for (final row in validRows) row.account.trim().toLowerCase(),
        for (final row in validRows)
          if (row.destination != null) row.destination!.trim().toLowerCase(),
      };
      final importedCategoryNames = <String>{
        for (final row in validRows)
          if (row.category != null)
            '${row.type!.name}:${row.category!.trim().toLowerCase()}',
      };
      if (!mounted) return;
      setState(() {
        _bytes = Uint8List.fromList(bytes);
        _fileName = name;
        _error = null;
      });
      context.go(
        AppRoutes.importPreview,
        extra: ImportPreviewData(
          preview: preview,
          bytes: _bytes!,
          newAccounts: importedAccountNames.difference(accountNames).length,
          newCategories: importedCategoryNames.difference(categoryNames).length,
          possibleDuplicates: possibleDuplicates,
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not read this workbook: $error');
      }
    }
  }

  Future<void> _finishSkip() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _completeSetup(ref);
    if (mounted) context.go(AppRoutes.startup);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _cream,
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.go(AppRoutes.onboarding),
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              const Text(
                'Optional',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'Import Your Existing Data',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 30),
          ),
          const SizedBox(height: 10),
          const Text(
            'Already using a spreadsheet? Import your transactions, accounts and categories from an Excel file.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.4),
          ),
          InkWell(
            onTap: _pick,
            child: CustomPaint(
              foregroundPainter: _DashedBorderPainter(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: Image.asset(
                        'assets/images/0.png',
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.table_view, size: 90),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _fileName ?? 'Choose an Excel file',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    const Text('Supported format: .xlsx'),
                  ],
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                _error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 18),
          _PrimaryButton(label: 'Select & Review', onPressed: _pick),
          Center(
            child: TextButton(
              onPressed: _finishSkip,
              child: const Text(
                'Skip for now',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class ImportPreviewScreen extends StatelessWidget {
  const ImportPreviewScreen({required this.data, super.key});
  final ImportPreviewData data;
  @override
  Widget build(BuildContext context) {
    final valid = data.preview.rows.where((r) => r.valid).toList();
    int count(MoneyType type) => valid.where((row) => row.type == type).length;
    final accounts = <String>{};
    for (final row in valid) {
      accounts.add(row.account);
      if (row.destination != null) accounts.add(row.destination!);
    }
    final categories = <String>{
      for (final r in valid)
        if (r.category != null) '${r.type!.name}: ${r.category}',
    };
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.go(AppRoutes.excelImport),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Review & Import',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                children: [
                  const Text(
                    'We analysed your workbook. Review the records before adding them to Money Manager.',
                  ),
                  const SizedBox(height: 14),
                  _CountCard(
                    'Expenses',
                    count(MoneyType.expense),
                    AppColors.pink,
                  ),
                  _CountCard(
                    'Income',
                    count(MoneyType.income),
                    AppColors.green,
                  ),
                  _CountCard(
                    'Transfers',
                    count(MoneyType.transfer),
                    AppColors.blue,
                  ),
                  _InfoCard(
                    title: 'Accounts',
                    body:
                        '${data.newAccounts} new account(s) will be created. ${accounts.length} unique account(s) are referenced.',
                  ),
                  _InfoCard(
                    title: 'Categories',
                    body:
                        '${data.newCategories} new categories will be created. ${categories.length} category(ies) are referenced.',
                  ),
                  if (data.possibleDuplicates > 0)
                    _InfoCard(
                      title: 'Possible duplicates',
                      body:
                          '${data.possibleDuplicates} record(s) match existing transactions and will be skipped by the importer.',
                      color: const Color(0xFFFFE7B3),
                    ),
                  if (data.preview.invalidCount > 0)
                    _InfoCard(
                      title: 'Skipped for review',
                      body:
                          '${data.preview.invalidCount} invalid or unsupported row(s) will not be imported.',
                    ),
                  if (valid.isEmpty)
                    const _InfoCard(
                      title: 'Nothing ready to import',
                      body: 'The workbook has no valid transaction rows. Go back and choose another file.',
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: _PrimaryButton(
                label: 'Import Data',
                onPressed: valid.isEmpty
                    ? null
                    : () => context.go(
                        AppRoutes.importProgress,
                        extra: valid.map((r) => r.toRecord()).toList(),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImportProgressScreen extends ConsumerStatefulWidget {
  const ImportProgressScreen({required this.records, super.key});
  final List<MoneyImportRecord> records;
  @override
  ConsumerState<ImportProgressScreen> createState() =>
      _ImportProgressScreenState();
}

class _ImportProgressScreenState extends ConsumerState<ImportProgressScreen> {
  bool _started = false, _done = false;
  String? _error;
  MoneyImportProgress? _progress;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_started) return;
    _started = true;
    try {
      final repository = ref.read(moneyRepositoryProvider);
      await repository.importTransactions(
        widget.records,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
      );
      await _completeSetup(ref);
      if (mounted) setState(() => _done = true);
      if (mounted) context.go(AppRoutes.startup);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = 'Import could not be completed: $error';
          _started = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: _cream,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                const Text(
                  'Importing Data',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Please don't close the app.",
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 26),
                _BrutalCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _progress?.stage == MoneyImportStage.validating
                            ? 'Validating transaction records'
                            : 'Saving transactions and related records',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: _done
                            ? 1
                            : _progress == null || _progress!.total == 0
                            ? null
                            : _progress!.processed / _progress!.total,
                        minHeight: 12,
                        color: _yellow,
                        backgroundColor: const Color(0xFFECE7DD),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _done
                            ? '${widget.records.length} records processed'
                            : _progress == null
                            ? 'Preparing the import…'
                            : '${_progress!.processed} of ${_progress!.total} records',
                      ),
                      const SizedBox(height: 18),
                      for (final item in [
                        'Validate workbook records',
                        'Commit transactions and related records',
                        'Refresh workspace summaries',
                      ])
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Icon(_stageIcon(item), size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text(item)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PrimaryButton(label: 'Retry', onPressed: _run),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.excelImport),
                    child: const Text('Return to file selection'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );

  IconData _stageIcon(String item) {
    if (_done) return Icons.check_circle;
    if (item.startsWith('Validate')) {
      if (_progress?.stage == MoneyImportStage.validating) {
        return Icons.sync;
      }
      if (_progress?.stage == MoneyImportStage.importing ||
          _progress?.stage == MoneyImportStage.complete) {
        return Icons.check_circle;
      }
    }
    if (item.startsWith('Commit') &&
        _progress?.stage == MoneyImportStage.importing) {
      return Icons.sync;
    }
    return Icons.circle_outlined;
  }
}

class StartupScreen extends ConsumerStatefulWidget {
  const StartupScreen({super.key});
  @override
  ConsumerState<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends ConsumerState<StartupScreen> {
  String? _error;
  bool _running = false;
  int _startupStage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    if (_running) return;
    _running = true;
    setState(() => _error = null);
    try {
      final repository = ref.read(moneyRepositoryProvider);
      setState(() => _startupStage = 0);
      await repository.seedDefaults();
      setState(() => _startupStage = 1);
      await repository.accounts(includeArchived: true);
      await repository.transactions();
      setState(() => _startupStage = 2);
      await repository.calculateBalances();
      setState(() => _startupStage = 3);
      await Future<void>.delayed(const Duration(milliseconds: 150));
      if (mounted) context.go(AppRoutes.today);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Your workspace could not be loaded: $error');
      }
    } finally {
      _running = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_startupStage + 1) / 4.0;
    return MiraiLoadingView(
      progress: progress,
      error: _error,
      onRetry: _initialize,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});
  final String label;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 56,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Transform.translate(
        offset: const Offset(-4, -4),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: _yellow,
            foregroundColor: _ink,
            elevation: 0,
            side: const BorderSide(color: _ink, width: 2.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    ),
  );
}

class _BrutalCard extends StatelessWidget {
  const _BrutalCard({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: _ink, width: 2.5),
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: _ink, offset: Offset(5, 5))],
    ),
    child: child,
  );
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      );
    final paint = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + 7).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance = end + 4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CountCard extends StatelessWidget {
  const _CountCard(this.label, this.count, this.color);
  final String label;
  final int count;
  final Color color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: _InfoCard(title: label, body: '$count transaction(s)', color: color),
  );
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.body,
    this.color = Colors.white,
  });
  final String title, body;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: _ink, width: 2),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(body),
      ],
    ),
  );
}
