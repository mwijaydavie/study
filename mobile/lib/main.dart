import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'campus/campus_calendar.dart';
import 'campus/campus_events.dart';
import 'design.dart';
import 'documents/personal_documents.dart';
import 'pages/campus_events_page.dart';
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

class _DeskHomeState extends State<DeskHome> with WidgetsBindingObserver {
  var _tab = 0;
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
    setState(() => _tab = opened.event == null ? 0 : 3);
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

  void _openFolder(String code) => setState(() {
    _folder = code;
    _tab = 2;
  });

  void _selectDestination(int index) {
    if (index != _tab) {
      DeskHaptics.selection();
    } else if (index != 2 || _folder.isEmpty) {
      return;
    }
    setState(() {
      _tab = index;
      if (index == 2) _folder = '';
    });
  }

  void _openCoach() => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => StudyCoachPage(
        data: widget.data,
        journal: widget.workspace.studyJournal,
        now: widget.now,
      ),
    ),
  );

  Widget _destination() => switch (_tab) {
    0 => TimetablePage(
      data: widget.data,
      clock: _clock,
      workspace: widget.workspace,
      openFolder: _openFolder,
      reminders: widget.reminders,
    ),
    1 => PlanPage(
      data: widget.data,
      clock: _clock,
      workspace: widget.workspace,
      openFolder: _openFolder,
      openCoach: _openCoach,
    ),
    2 => MaterialsPage(
      data: widget.data,
      clock: _clock,
      initialFolder: _folder,
      documents: widget.documents,
      openCoach: _openCoach,
    ),
    _ => SettingsPage(
      data: widget.data,
      clock: _clock,
      workspace: widget.workspace,
      reminders: widget.reminders,
      welcomeVoice: widget.welcomeVoice,
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
    canPop: _tab == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _tab != 0) setState(() => _tab = 0);
    },
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: deskSystemBars,
      child: ListenableBuilder(
        listenable: widget.workspace,
        builder: (context, _) => Scaffold(
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
                      child: _destination(),
                    ),
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: DeskColors.line)),
            ),
            child: NavigationBar(
              height: 65,
              animationDuration: DeskMotion.durationOf(
                context,
                DeskMotion.section,
              ),
              selectedIndex: _tab,
              onDestinationSelected: _selectDestination,
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  selectedIcon: Icon(Icons.calendar_month),
                  label: 'Timetable',
                ),
                NavigationDestination(
                  icon: Icon(Icons.checklist_rounded),
                  label: 'Study plan',
                ),
                NavigationDestination(
                  icon: Icon(Icons.folder_outlined),
                  selectedIcon: Icon(Icons.folder_open_rounded),
                  label: 'Materials',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
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
