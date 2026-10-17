import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appName = 'JECKER ANDRE';
const developerName = 'JECKER ANDRE';
const supportEmail = 'support@jeckerandre.app';
const screenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = OperationsStore(screenshotMode: screenshotMode);
  await store.load();
  runApp(JeckerApp(store: store));
}

class JeckerApp extends StatelessWidget {
  const JeckerApp({super.key, required this.store});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF1565C0);
    const secondary = Color(0xFF8BC34A);
    const surface = Color(0xFFF6F8F7);

    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          secondary: secondary,
          surface: surface,
          onSurface: const Color(0xFF17212B),
        );

    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: surface,
        navigationBarTheme: const NavigationBarThemeData(
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          height: 72,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: surface,
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xFFE1E8EA)),
          ),
        ),
      ),
      home: HomeShell(store: store),
    );
  }
}

enum RecordType { shift, patient, task, container }

extension RecordTypeCopy on RecordType {
  String get label => switch (this) {
    RecordType.shift => 'Shifts',
    RecordType.patient => 'Patients',
    RecordType.task => 'Tasks',
    RecordType.container => 'Containers',
  };

  String get singular => switch (this) {
    RecordType.shift => 'Shift',
    RecordType.patient => 'Patient',
    RecordType.task => 'Task',
    RecordType.container => 'Container',
  };

  String get actionLabel => switch (this) {
    RecordType.shift => 'Add shift',
    RecordType.patient => 'Add patient',
    RecordType.task => 'Add task',
    RecordType.container => 'Add container',
  };

  IconData get icon => switch (this) {
    RecordType.shift => Icons.calendar_month_outlined,
    RecordType.patient => Icons.assignment_ind_outlined,
    RecordType.task => Icons.fact_check_outlined,
    RecordType.container => Icons.inventory_2_outlined,
  };

  List<String> get statuses => switch (this) {
    RecordType.shift => ['Scheduled', 'In progress', 'Covered', 'Needs cover'],
    RecordType.patient => ['Active', 'Review due', 'Ready', 'Archived'],
    RecordType.task => ['Open', 'In progress', 'Blocked', 'Completed'],
    RecordType.container => ['Inbound', 'On site', 'Needs action', 'Released'],
  };
}

class OpsRecord {
  const OpsRecord({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.owner,
    required this.due,
    required this.note,
    required this.priority,
  });

  final String id;
  final RecordType type;
  final String title;
  final String subtitle;
  final String status;
  final String owner;
  final String due;
  final String note;
  final int priority;

  OpsRecord copyWith({
    String? title,
    String? subtitle,
    String? status,
    String? owner,
    String? due,
    String? note,
    int? priority,
  }) {
    return OpsRecord(
      id: id,
      type: type,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      status: status ?? this.status,
      owner: owner ?? this.owner,
      due: due ?? this.due,
      note: note ?? this.note,
      priority: priority ?? this.priority,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'type': type.name,
      'title': title,
      'subtitle': subtitle,
      'status': status,
      'owner': owner,
      'due': due,
      'note': note,
      'priority': priority,
    };
  }

  factory OpsRecord.fromJson(Map<String, Object?> json) {
    final typeName = json['type'] as String? ?? RecordType.task.name;
    final type = RecordType.values.firstWhere(
      (value) => value.name == typeName,
      orElse: () => RecordType.task,
    );
    return OpsRecord(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      status: json['status'] as String? ?? type.statuses.first,
      owner: json['owner'] as String? ?? 'Duty lead',
      due: json['due'] as String? ?? 'Today',
      note: json['note'] as String? ?? '',
      priority: (json['priority'] as num?)?.toInt() ?? 2,
    );
  }
}

class OperationsStore extends ChangeNotifier {
  OperationsStore({required this.screenshotMode});

  static const _recordsKey = 'records';
  static const _showCompletedKey = 'showCompleted';
  static const _defaultOwnerKey = 'defaultOwner';

  final bool screenshotMode;
  final List<OpsRecord> _records = [];
  bool _loaded = false;
  bool _showCompleted = true;
  String _defaultOwner = 'Duty lead';

  bool get loaded => _loaded;
  bool get showCompleted => _showCompleted;
  String get defaultOwner => _defaultOwner;

  Future<void> load() async {
    if (_loaded) {
      return;
    }

    if (screenshotMode) {
      _records
        ..clear()
        ..addAll(_sampleRecords);
      _defaultOwner = 'Andre operations';
      _loaded = true;
      notifyListeners();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    _showCompleted = prefs.getBool(_showCompletedKey) ?? true;
    _defaultOwner = prefs.getString(_defaultOwnerKey) ?? 'Duty lead';
    final encoded = prefs.getString(_recordsKey);
    if (encoded != null && encoded.isNotEmpty) {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      _records
        ..clear()
        ..addAll(
          decoded.whereType<Map<String, dynamic>>().map(
            (json) => OpsRecord.fromJson(json),
          ),
        );
    }
    _loaded = true;
    notifyListeners();
  }

  List<OpsRecord> recordsFor(RecordType type) {
    final items = _records.where((record) => record.type == type).toList()
      ..sort((a, b) {
        final priority = a.priority.compareTo(b.priority);
        return priority == 0 ? a.title.compareTo(b.title) : priority;
      });

    if (_showCompleted) {
      return items;
    }

    return items
        .where(
          (record) =>
              record.status != 'Completed' &&
              record.status != 'Covered' &&
              record.status != 'Released' &&
              record.status != 'Archived',
        )
        .toList();
  }

  OpsRecord? recordById(String id) {
    for (final record in _records) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  int countFor(RecordType type) => recordsFor(type).length;

  int urgentCount() {
    return _records
        .where(
          (record) =>
              record.priority == 1 &&
              record.status != 'Completed' &&
              record.status != 'Released' &&
              record.status != 'Archived',
        )
        .length;
  }

  List<OpsRecord> priorityRecords() {
    final items =
        _records
            .where(
              (record) =>
                  record.status != 'Completed' &&
                  record.status != 'Released' &&
                  record.status != 'Archived',
            )
            .toList()
          ..sort((a, b) {
            final priority = a.priority.compareTo(b.priority);
            return priority == 0 ? a.due.compareTo(b.due) : priority;
          });
    return items.take(4).toList();
  }

  Future<void> addRecord(OpsRecord record) async {
    _records.add(record);
    notifyListeners();
    await _saveRecords();
  }

  Future<void> updateStatus(String id, String status) async {
    final index = _records.indexWhere((record) => record.id == id);
    if (index == -1) {
      return;
    }
    _records[index] = _records[index].copyWith(status: status);
    notifyListeners();
    await _saveRecords();
  }

  Future<void> removeRecord(String id) async {
    _records.removeWhere((record) => record.id == id);
    notifyListeners();
    await _saveRecords();
  }

  Future<void> setShowCompleted(bool value) async {
    _showCompleted = value;
    notifyListeners();
    if (screenshotMode) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showCompletedKey, value);
  }

  Future<void> setDefaultOwner(String value) async {
    _defaultOwner = value.trim().isEmpty ? 'Duty lead' : value.trim();
    notifyListeners();
    if (screenshotMode) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultOwnerKey, _defaultOwner);
  }

  Future<void> _saveRecords() async {
    if (screenshotMode) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _recordsKey,
      jsonEncode(_records.map((record) => record.toJson()).toList()),
    );
  }
}

final _sampleRecords = <OpsRecord>[
  const OpsRecord(
    id: 'shift-1',
    type: RecordType.shift,
    title: 'JECKER ANDRE',
    subtitle: 'Front desk and care routing',
    status: 'In progress',
    owner: 'Nadia',
    due: 'Today 07:00-15:00',
    note: 'Confirm handoff notes before the afternoon roster starts.',
    priority: 1,
  ),
  const OpsRecord(
    id: 'shift-2',
    type: RecordType.shift,
    title: 'Evening coverage',
    subtitle: 'Two operators required',
    status: 'Needs cover',
    owner: 'Andre operations',
    due: 'Today 15:00-23:00',
    note: 'One seat is open after a late absence.',
    priority: 1,
  ),
  const OpsRecord(
    id: 'patient-1',
    type: RecordType.patient,
    title: 'Patient file JA-204',
    subtitle: 'Discharge checklist',
    status: 'Review due',
    owner: 'Samir',
    due: 'Today 13:30',
    note: 'Prepare transport note and verify signed summary.',
    priority: 1,
  ),
  const OpsRecord(
    id: 'patient-2',
    type: RecordType.patient,
    title: 'Patient file JA-188',
    subtitle: 'Follow-up call',
    status: 'Active',
    owner: 'Lina',
    due: 'May 13',
    note: 'Keep the local notes updated after the call.',
    priority: 2,
  ),
  const OpsRecord(
    id: 'task-1',
    type: RecordType.task,
    title: 'Reconcile supply requests',
    subtitle: 'Operations board',
    status: 'Open',
    owner: 'Andre operations',
    due: 'Today 16:00',
    note: 'Match urgent requests against available stock.',
    priority: 1,
  ),
  const OpsRecord(
    id: 'task-2',
    type: RecordType.task,
    title: 'Close weekly incident review',
    subtitle: 'Quality follow-up',
    status: 'In progress',
    owner: 'Mina',
    due: 'May 14',
    note: 'Attach final outcomes to the local handover.',
    priority: 2,
  ),
  const OpsRecord(
    id: 'container-1',
    type: RecordType.container,
    title: 'Container C-1182',
    subtitle: 'Sterile supply return',
    status: 'Needs action',
    owner: 'Youssef',
    due: 'Dock B, today',
    note: 'Seal check pending before release.',
    priority: 1,
  ),
  const OpsRecord(
    id: 'container-2',
    type: RecordType.container,
    title: 'Container C-1190',
    subtitle: 'Inbound consumables',
    status: 'On site',
    owner: 'Andre operations',
    due: 'Bay 3',
    note: 'Count received packs before storage.',
    priority: 2,
  ),
];

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});

  final OperationsStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _types = <RecordType>[
    RecordType.shift,
    RecordType.patient,
    RecordType.task,
    RecordType.container,
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final selectedType = _index == 0 ? null : _types[_index - 1];
        return Scaffold(
          appBar: AppBar(
            title: Text(_index == 0 ? appName : selectedType!.label),
            actions: [
              IconButton(
                key: const ValueKey('settings-action'),
                tooltip: 'Settings',
                icon: const Icon(Icons.tune_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SettingsScreen(store: widget.store),
                    ),
                  );
                },
              ),
            ],
          ),
          body: IndexedStack(
            index: _index,
            children: [
              DashboardScreen(
                store: widget.store,
                onReviewTasks: () => setState(() => _index = 3),
              ),
              for (final type in _types)
                RecordsScreen(store: widget.store, type: type),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: ValueKey(
              selectedType == null
                  ? 'add-dashboard-task'
                  : 'add-${selectedType.name}',
            ),
            onPressed: () =>
                _openForm(context, selectedType ?? RecordType.task),
            icon: const Icon(Icons.add),
            label: Text(selectedType?.actionLabel ?? 'Add task'),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (index) => setState(() => _index = index),
            destinations: const [
              NavigationDestination(
                key: ValueKey('nav-today'),
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Today',
              ),
              NavigationDestination(
                key: ValueKey('nav-shifts'),
                icon: Icon(Icons.calendar_month_outlined),
                selectedIcon: Icon(Icons.calendar_month),
                label: 'Shifts',
              ),
              NavigationDestination(
                key: ValueKey('nav-patients'),
                icon: Icon(Icons.assignment_ind_outlined),
                selectedIcon: Icon(Icons.assignment_ind),
                label: 'Patients',
              ),
              NavigationDestination(
                key: ValueKey('nav-tasks'),
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check),
                label: 'Tasks',
              ),
              NavigationDestination(
                key: ValueKey('nav-containers'),
                icon: Icon(Icons.inventory_2_outlined),
                selectedIcon: Icon(Icons.inventory_2),
                label: 'Containers',
              ),
            ],
          ),
        );
      },
    );
  }

  void _openForm(BuildContext context, RecordType type) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordFormScreen(store: widget.store, type: type),
      ),
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.store,
    required this.onReviewTasks,
  });

  final OperationsStore store;
  final VoidCallback onReviewTasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final urgent = store.urgentCount();
    final priorities = store.priorityRecords();

    return ListView(
      key: const ValueKey('dashboard-screen'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Text(
          'Daily operations',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Coordinate shifts, patient files, work queues, and container movement from local app storage.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth > 560;
            return GridView.count(
              crossAxisCount: wide ? 4 : 2,
              childAspectRatio: wide ? 1.55 : 1.05,
              shrinkWrap: true,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                MetricTile(
                  icon: Icons.priority_high,
                  label: 'Urgent',
                  value: urgent.toString(),
                  color: const Color(0xFFB54227),
                ),
                MetricTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Shifts',
                  value: store.countFor(RecordType.shift).toString(),
                  color: const Color(0xFF1A547E),
                ),
                MetricTile(
                  icon: Icons.assignment_ind_outlined,
                  label: 'Patients',
                  value: store.countFor(RecordType.patient).toString(),
                  color: const Color(0xFF29708C),
                ),
                MetricTile(
                  icon: Icons.inventory_2_outlined,
                  label: 'Containers',
                  value: store.countFor(RecordType.container).toString(),
                  color: const Color(0xFF64512A),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        SectionHeader(
          title: 'Priority work',
          actionLabel: 'Review tasks',
          onAction: onReviewTasks,
        ),
        const SizedBox(height: 10),
        for (final record in priorities)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RecordCard(store: store, record: record),
          ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(
                      'Local workspace',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Records stay on this device. There is no account, cloud sync, analytics, advertising, or external service connection.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key, required this.store, required this.type});

  final OperationsStore store;
  final RecordType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final records = store.recordsFor(type);
    final emptyCopy = switch (type) {
      RecordType.shift => 'Plan coverage for the next desk or floor shift.',
      RecordType.patient => 'Create a local patient work file for follow-up.',
      RecordType.task => 'Add operational work that needs a clear owner.',
      RecordType.container =>
        'Track a container that is inbound, on site, or ready for release.',
    };

    return ListView(
      key: ValueKey('${type.name}-screen'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        Text(
          type.label,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          emptyCopy,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        if (records.isEmpty)
          EmptyState(type: type)
        else
          for (final record in records)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: RecordCard(store: store, record: record),
            ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.type});

  final RecordType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(type.icon, size: 42, color: theme.colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              'No ${type.label.toLowerCase()} yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Use the add button to save the first local ${type.singular.toLowerCase()} record.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class RecordCard extends StatelessWidget {
  const RecordCard({super.key, required this.store, required this.record});

  final OperationsStore store;
  final OpsRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => DetailScreen(store: store, recordId: record.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      record.type.icon,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          record.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          record.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(label: record.status),
                  InfoPill(icon: Icons.person_outline, label: record.owner),
                  InfoPill(icon: Icons.schedule, label: record.due),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class InfoPill extends StatelessWidget {
  const InfoPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.store, required this.recordId});

  final OperationsStore store;
  final String recordId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final record = store.recordById(recordId);
        if (record == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Record')),
            body: const Center(child: Text('This local record was removed.')),
          );
        }
        final theme = Theme.of(context);
        return Scaffold(
          appBar: AppBar(title: Text(record.type.singular)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text(
                record.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                record.subtitle,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  StatusPill(label: record.status),
                  InfoPill(icon: Icons.person_outline, label: record.owner),
                  InfoPill(icon: Icons.schedule, label: record.due),
                ],
              ),
              const SizedBox(height: 22),
              SectionHeader(title: 'Notes'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(record.note),
                ),
              ),
              const SizedBox(height: 22),
              SectionHeader(title: 'Update status'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in record.type.statuses)
                    ChoiceChip(
                      label: Text(status),
                      selected: status == record.status,
                      onSelected: (_) => store.updateStatus(record.id, status),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  await store.removeRecord(record.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove local record'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class RecordFormScreen extends StatefulWidget {
  const RecordFormScreen({super.key, required this.store, required this.type});

  final OperationsStore store;
  final RecordType type;

  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _subtitle;
  late final TextEditingController _owner;
  late final TextEditingController _due;
  late final TextEditingController _note;
  late String _status;
  int _priority = 2;
  String? _titleError;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _subtitle = TextEditingController();
    _owner = TextEditingController(text: widget.store.defaultOwner);
    _due = TextEditingController(text: 'Today');
    _note = TextEditingController();
    _status = widget.type.statuses.first;
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _owner.dispose();
    _due.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.type.actionLabel)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
        children: [
          Text(
            'Create ${widget.type.singular.toLowerCase()} record',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'The record is saved only in local app storage on this device.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          TextField(
            key: const ValueKey('record-title-field'),
            controller: _title,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: '${widget.type.singular} name',
              errorText: _titleError,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subtitle,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Summary',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _owner,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Owner',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _due,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Due or location',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final status in widget.type.statuses)
                DropdownMenuItem(value: status, child: Text(status)),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => _status = value);
              }
            },
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 1, label: Text('Urgent')),
              ButtonSegment(value: 2, label: Text('Normal')),
              ButtonSegment(value: 3, label: Text('Low')),
            ],
            selected: {_priority},
            onSelectionChanged: (values) {
              setState(() => _priority = values.first);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Notes',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: FilledButton.icon(
            key: const ValueKey('save-record-button'),
            onPressed: _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Save local record'),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Enter a name');
      return;
    }
    setState(() => _titleError = null);
    await widget.store.addRecord(
      OpsRecord(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: widget.type,
        title: title,
        subtitle: _subtitle.text.trim().isEmpty
            ? '${widget.type.singular} follow-up'
            : _subtitle.text.trim(),
        status: _status,
        owner: _owner.text.trim().isEmpty
            ? widget.store.defaultOwner
            : _owner.text.trim(),
        due: _due.text.trim().isEmpty ? 'Today' : _due.text.trim(),
        note: _note.text.trim().isEmpty
            ? 'No extra notes have been saved for this record.'
            : _note.text.trim(),
        priority: _priority,
      ),
    );
    if (mounted) {
      Navigator.of(context).pop();
    }
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.store});

  final OperationsStore store;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _owner;

  @override
  void initState() {
    super.initState();
    _owner = TextEditingController(text: widget.store.defaultOwner);
  }

  @override
  void dispose() {
    _owner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            key: const ValueKey('settings-screen'),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              Text(
                'Workspace settings',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Show completed records'),
                      subtitle: const Text(
                        'Keep resolved work visible in lists.',
                      ),
                      value: widget.store.showCompleted,
                      onChanged: widget.store.setShowCompleted,
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _owner,
                              decoration: const InputDecoration(
                                labelText: 'Default owner',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          IconButton.filled(
                            tooltip: 'Save owner',
                            onPressed: () =>
                                widget.store.setDefaultOwner(_owner.text),
                            icon: const Icon(Icons.check),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SectionHeader(title: 'Privacy'),
              const SizedBox(height: 10),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Local data only',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'JECKER ANDRE does not require sign-in, cloud sync, analytics, advertising identifiers, location, contacts, camera, microphone, files, or other Android permissions.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Support',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(supportEmail),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
