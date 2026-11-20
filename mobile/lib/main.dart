import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/theme/personal_yellow_theme.dart';
import 'campus/campus_calendar.dart';
import 'campus/campus_events.dart';
import 'core/widgets/personal_glass_nav_dock.dart';
import 'design.dart';
import 'documents/personal_documents.dart';
import 'pages/assistant_page.dart';
import 'pages/campus_events_page.dart';
import 'pages/home_page.dart';
import 'pages/materials_page.dart';
import 'pages/plan_page.dart';
import 'pages/settings_page.dart';
import 'pages/study_coach_page.dart';
import 'pages/timetable_page.dart';
import 'reminders/reminder_plan.dart';
import 'reminders/reminders.dart';
import 'study_data.dart';
import 'ui/desk_launch.dart';
import 'ui/desk_motion.dart';
import 'ui/welcome_voice.dart';
import 'workspace.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Plus Jakarta Sans'], license);
  });
  runApp(const StudyDeskApp());
}

class StudyDeskApp extends StatelessWidget {
  const StudyDeskApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'StudyDesk · Mwijay',
    theme: deskTheme(),
    home: const _BootPage(),
  );
}

class _BootPage extends StatefulWidget {
  const _BootPage();

  @override
  State<_BootPage> createState() => _BootPageState();
}

class _BootPageState extends State<_BootPage> {
  late final Future<StudyData> _load;
  Workspace? _workspace;
  ReminderController? _reminders;
  CampusEventBook? _campusEvents;
  WelcomeVoice? _welcomeVoice;

  @override
  void initState() {
    super.initState();
    _load = _start();
  }

  Future<StudyData> _start() async {
    final data = await StudyData.load(rootBundle);
    final android = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
    final eventsReady = android
        ? CampusEventBook.load(const AndroidCampusPlatform())
        : null;
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance().timeout(
        const Duration(seconds: 3),
      );
    } catch (_) {
      // A failed preference store doesn't block the bundled timetable.
    }
    final events = await eventsReady;
    if (mounted) {
      _workspace = Workspace(prefs);
      _campusEvents = events;
      if (android) {
        _welcomeVoice = WelcomeVoice(prefs, const AndroidWelcomePlayer());
        _reminders = ReminderController(
          plan: ClassReminderPlan(data),
          platform: AndroidReminderPlatform(),
          campusEvents: events,
        );
      }
    } else {
      events?.dispose();
    }
    return data;
  }

  @override
  void dispose() {
    _reminders?.dispose();
    _campusEvents?.dispose();
    _welcomeVoice?.dispose();
    _workspace?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<StudyData>(
    future: _load,
    builder: (context, snapshot) => DeskLaunchStage(
      failed: snapshot.hasError,
      ready: snapshot.hasData && _workspace != null
          ? DeskHome(
              data: snapshot.data!,
              workspace: _workspace!,
              reminders: _reminders,
              welcomeVoice: _welcomeVoice,
              documents:
                  !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                  ? const AndroidDocumentLibrary()
                  : null,
            )
          : null,
    ),
  );
}

class DeskHome extends StatefulWidget {
  const DeskHome({
    super.key,
    required this.data,
    required this.workspace,
    this.reminders,
    this.documents,
    this.welcomeVoice,
    this.now = DateTime.now,
  });
  final StudyData data;
  final Workspace workspace;
  final ReminderController? reminders;
  final DocumentLibrary? documents;
  final WelcomeVoice? welcomeVoice;
  final DateTime Function() now;

  @override
  State<DeskHome> createState() => _DeskHomeState();
}

enum _PlanSection { timetable, checklist }

class _DeskHomeState extends State<DeskHome> with WidgetsBindingObserver {
  var _tab = PersonalTab.home;
  var _planSection = _PlanSection.timetable;
  var _folder = '';
  late CampusClock _clock;
  Timer? _timer;
  StreamSubscription<void>? _reminderTaps;

  @override
  void initState() {
    super.initState();
    _clock = CampusClock.at(widget.now());
    WidgetsBinding.instance.addObserver(this);
    _startClockUpdates();
    _reminderTaps = widget.reminders?.opened.listen((_) => _openReminderTap());
    _syncReminders();
    if (widget.welcomeVoice != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.welcomeVoice?.ready(
          WidgetsBinding.instance.lifecycleState,
          widget.now(),
        );
      });
    }
  }

  void _syncReminders() {
    final reminders = widget.reminders;
    if (reminders == null) return;
    unawaited(reminders.refresh());
    unawaited(_openReminderTap());
  }

  Future<void> _openReminderTap() async {
    final reminders = widget.reminders;
    if (reminders == null) return;
    final opened = await reminders.takeOpenedReminder();
    if (opened == null || !mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _tab = opened.event == null ? PersonalTab.plan : PersonalTab.settings;
      if (opened.event == null) _planSection = _PlanSection.timetable;
    });
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final event = opened.event;
    final events = reminders.campusEvents;
    if (event != null && events != null) {
      unawaited(
        Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => CampusEventDetail(
              eventId: event.id,
              book: events,
              reminders: reminders,
              use24Hour: widget.workspace.use24Hour,
            ),
          ),
        ),
      );
      return;
    }
    final occurrence = opened.classDate;
    if (occurrence == null) return;
    unawaited(
      showTimetableSession(
        context,
        data: widget.data,
        session: occurrence.session,
        workspace: widget.workspace,
        openFolder: _openFolder,
        reminders: reminders,
        confirmedDay: occurrence.campusDay,
      ),
    );
  }

  void _startClockUpdates() {
    _timer ??= Timer.periodic(
      const Duration(seconds: 15),
      (_) => _refreshTime(),
    );
  }

  void _refreshTime() {
    final fresh = CampusClock.at(widget.now());
    if (fresh.weekday != _clock.weekday ||
        fresh.minute != _clock.minute ||
        fresh.weekKey != _clock.weekKey) {
      if (mounted) setState(() => _clock = fresh);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.welcomeVoice?.lifecycle(state, widget.now());
    if (state == AppLifecycleState.resumed) {
      _refreshTime();
      _startClockUpdates();
      _syncReminders();
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  void _openFolder(String code) {
    _unfocus();
    setState(() {
      _folder = code;
      _tab = PersonalTab.materials;
    });
  }

  void _selectDestination(PersonalTab next) {
    if (next == _tab && (next != PersonalTab.materials || _folder.isEmpty))
      return;
    _unfocus();
    setState(() {
      _tab = next;
      if (next == PersonalTab.materials) _folder = '';
    });
  }

  void _openPlan(_PlanSection section) {
    _unfocus();
    setState(() {
      _planSection = section;
      _tab = PersonalTab.plan;
    });
  }

  void _openCoach([String? source]) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => StudyCoachPage(
        data: widget.data,
        journal: widget.workspace.studyJournal,
        now: widget.now,
        initialSource: source,
      ),
    ),
  );

  void _openAiSettings() => _openAiRoute(
    (_) => AiSettingsPage(
      preferences: widget.workspace.assistant,
      now: widget.now,
    ),
  );

  void _openAssistant([String query = '']) => _openAiRoute(
    (route) => AssistantPage(
      data: widget.data,
      workspace: widget.workspace,
      now: widget.now,
      initialQuery: query,
      openSettings: _openAiSettings,
      openCoach: _openCoach,
      openSchedule: () {
        Navigator.of(route).pop();
        _openPlan(_PlanSection.timetable);
      },
      openFinance: () {
        Navigator.of(route).pop();
        _openFolder('FN200');
      },
    ),
  );

  void _openAiRoute(WidgetBuilder builder) {
    _unfocus();
    Navigator.of(context).push<void>(
      PageRouteBuilder(
        transitionDuration: DeskMotion.durationOf(
          context,
          const Duration(milliseconds: 360),
        ),
        reverseTransitionDuration: DeskMotion.durationOf(
          context,
          DeskMotion.launch,
        ),
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          if (MediaQuery.disableAnimationsOf(context)) return child;
          final ease = animation.drive(CurveTween(curve: DeskMotion.solar));
          return FadeTransition(
            opacity: ease,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, .06),
                end: Offset.zero,
              ).animate(ease),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _plan() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 7, 12, 0),
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 3,
            children: [
              for (final (section, label, icon) in [
                (
                  _PlanSection.timetable,
                  'Timetable',
                  Icons.calendar_month_outlined,
                ),
                (
                  _PlanSection.checklist,
                  'Study checklist',
                  Icons.checklist_rounded,
                ),
              ])
                ChoiceChip(
                  key: ValueKey('plan-${section.name}'),
                  label: Text(label),
                  avatar: Icon(icon, size: 17),
                  showCheckmark: false,
                  selected: _planSection == section,
                  onSelected: (selected) {
                    if (!selected || _planSection == section) return;
                    DeskHaptics.selection();
                    _openPlan(section);
                  },
                ),
            ],
          ),
        ),
      ),
      Expanded(
        child: ClipRect(
          child: DeskReveal(
            key: ValueKey(_planSection),
            child: _planSection == _PlanSection.timetable
                ? TimetablePage(
                    data: widget.data,
                    clock: _clock,
                    workspace: widget.workspace,
                    openFolder: _openFolder,
                    reminders: widget.reminders,
                  )
                : PlanPage(
                    data: widget.data,
                    clock: _clock,
                    workspace: widget.workspace,
                    openFolder: _openFolder,
                    openCoach: _openCoach,
                  ),
          ),
        ),
      ),
    ],
  );

  Widget _destination() => switch (_tab) {
    PersonalTab.home => HomePage(
      data: widget.data,
      clock: _clock,
      workspace: widget.workspace,
      openAssistant: _openAssistant,
      openTimetable: () => _openPlan(_PlanSection.timetable),
      openPlan: () => _openPlan(_PlanSection.checklist),
      openFinance: () => _openFolder('FN200'),
    ),
    PersonalTab.plan => _plan(),
    PersonalTab.materials => MaterialsPage(
      data: widget.data,
      clock: _clock,
      initialFolder: _folder,
      documents: widget.documents,
      openCoach: _openCoach,
    ),
    PersonalTab.settings => SettingsPage(
      data: widget.data,
      clock: _clock,
      workspace: widget.workspace,
      reminders: widget.reminders,
      welcomeVoice: widget.welcomeVoice,
      openAiSettings: _openAiSettings,
    ),
  };

  @override
  void dispose() {
    _timer?.cancel();
    unawaited(_reminderTaps?.cancel());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: _tab == PersonalTab.home,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _tab != PersonalTab.home)
        _selectDestination(PersonalTab.home);
    },
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: deskSystemBars,
      child: ListenableBuilder(
        listenable: widget.workspace,
        builder: (context, _) => AmbientSolarBackdrop(
          child: Scaffold(
            extendBody: true,
            backgroundColor: Colors.transparent,
            body: Column(
              children: [
                _DeskHeader(cohort: widget.data.cohort),
                Expanded(
                  child: SafeArea(
                    top: false,
                    bottom: false,
                    child: ClipRect(
                      child: DeskReveal(
                        key: ValueKey(_tab),
                        slideFraction: .025,
                        child: _destination(),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            bottomNavigationBar: MediaQuery.viewInsetsOf(context).bottom > 0
                ? null
                : PersonalGlassNavDock(
                    key: const Key('personal-dock'),
                    currentTab: _tab,
                    onTabSelected: _selectDestination,
                    onAiPressed: _openAssistant,
                    onAiSettings: _openAiSettings,
                  ),
          ),
        ),
      ),
    ),
  );
}

class _DeskHeader extends StatelessWidget {
  const _DeskHeader({required this.cohort});
  final String cohort;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: DeskColors.white,
      border: Border(bottom: BorderSide(color: DeskColors.line)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset(
                'assets/art/app-mark.png',
                width: 36,
                height: 36,
                excludeFromSemantics: true,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: 'StudyDesk',
                      style: deskType(
                        20,
                        weight: FontWeight.w800,
                        spacing: -.9,
                      ),
                      children: const [
                        TextSpan(
                          text: '.',
                          style: TextStyle(color: Color(0xffa46d09)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  const MetaLabel(
                    Icons.check_circle_outline,
                    'OFFLINE READY',
                    color: Color(0xff2f664b),
                    size: 8.5,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: Pill(
                  cohort.toUpperCase(),
                  background: gold.surface,
                  color: gold.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
