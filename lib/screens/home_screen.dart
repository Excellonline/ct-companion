import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/note.dart';
import '../providers/notifications_provider.dart';
import '../providers/notes_provider.dart';
import '../services/quick_list_service.dart';
import '../services/reminder_service.dart';
import '../widgets/folder_filter_bar.dart';
import '../widgets/note_card.dart';
import '../widgets/pipeline_board.dart';
import 'activity_screen.dart';
import 'chat_screen.dart';
import 'decisions_screen.dart';
import 'editor_screen.dart';
import 'files_screen.dart';
import 'folders_screen.dart';
import 'global_search_screen.dart';
import 'inbox_screen.dart';
import 'live_share_screen.dart';
import 'notifications_screen.dart';
import 'quick_list_screen.dart';
import 'settings_screen.dart';

/// The Pipeline tab is a desktop-only workflow board. Phones get tabs without
/// it. The "add to pipeline" button on each note still works on phones —
/// promoted notes show up in the Pipeline tab on the desktop.
bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtl = TextEditingController();
  final _searchFocus = FocusNode();
  late final TabController _tabs;
  late final List<_TabSpec> _tabSpecs;

  @override
  void initState() {
    super.initState();
    _tabSpecs = _buildTabSpecs();
    _tabs = TabController(length: _tabSpecs.length, vsync: this);
    _tabs.addListener(() {
      if (mounted) setState(() {});
    });
  }

  /// Desktop: Pipeline | To-Do | Chat | Files | Notes (Pipeline default).
  /// Phone:   Notes | To-Do | Chat | Files (Notes default).
  List<_TabSpec> _buildTabSpecs() => _isDesktop
      ? const [
          _TabSpec.pipeline,
          _TabSpec.inbox,
          _TabSpec.todo,
          _TabSpec.chat,
          _TabSpec.liveShare,
          _TabSpec.files,
          _TabSpec.decisions,
          _TabSpec.activity,
          _TabSpec.notes,
        ]
      : const [
          _TabSpec.notes,
          _TabSpec.inbox,
          _TabSpec.todo,
          _TabSpec.chat,
          _TabSpec.liveShare,
          _TabSpec.files,
        ];

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _newNote(NoteType type) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EditorScreen(initialType: type)),
    );
  }

  void _newPipelineNote() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditorScreen(
          initialType: NoteType.note,
          initialInPipeline: true,
          initialPipelineStage: PipelineStage.ideas,
        ),
      ),
    );
  }

  void _newIdea() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const EditorScreen(
          initialType: NoteType.note,
          initialInInbox: true,
        ),
      ),
    );
  }

  void _newMeetingNote() {
    final now = DateTime.now();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          initialType: NoteType.note,
          initialTitle: 'Meeting notes - ${DateFormat.yMMMd().format(now)}',
          initialBody: '''
Attendees:

Agenda:
- 

Notes:

Decisions:
- 

Action items:
- 
''',
        ),
      ),
    );
  }

  Future<void> _togglePipeline(Note note) async {
    await ref
        .read(notesServiceProvider)
        .togglePipeline(note.id, add: !note.inPipeline);
  }

  void _openNote(BuildContext ctx, Note note) {
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => EditorScreen(note: note)),
    );
  }

  Future<void> _archiveNote(Note note) async {
    await ref.read(notesServiceProvider).archiveNote(note.id, archived: true);
  }

  void _selectTab(int index) {
    FocusManager.instance.primaryFocus?.unfocus();
    _tabs.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    // Re-schedule local reminders whenever the canonical notes list changes.
    ref.listen<AsyncValue<List<Note>>>(notesStreamProvider, (prev, next) {
      next.whenData((notes) => ReminderService.syncAll(notes));
    });

    final activeSpec = _tabSpecs[_tabs.index];

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
            const _NewNoteIntent(NoteType.note),
        const SingleActivator(LogicalKeyboardKey.keyL, control: true):
            const _NewNoteIntent(NoteType.checklist),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            const _FocusSearchIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewNoteIntent: CallbackAction<_NewNoteIntent>(
            onInvoke: (intent) {
              _newNote(intent.type);
              return null;
            },
          ),
          _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(
            onInvoke: (_) {
              _searchFocus.requestFocus();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            appBar: AppBar(
              title: _AppBarTitle(
                showNewNoteButton:
                    _isDesktop && activeSpec == _TabSpec.pipeline,
                onNewNote: _newPipelineNote,
              ),
              actions: [
                _isDesktop ? _appBarActions() : _mobileAppBarActions(),
              ],
            ),
            body: _isDesktop ? _desktopBody() : _tabBody(),
            bottomNavigationBar: _isDesktop
                ? null
                : BottomNavigationBar(
                    currentIndex: _tabs.index,
                    type: BottomNavigationBarType.fixed,
                    showUnselectedLabels: true,
                    onTap: _selectTab,
                    items: [
                      for (final s in _tabSpecs)
                        BottomNavigationBarItem(
                          icon: Icon(s.icon),
                          label: s.label,
                        ),
                    ],
                  ),
            floatingActionButton: activeSpec == _TabSpec.notes ? _fab() : null,
          ),
        ),
      ),
    );
  }

  Widget _tabBody() {
    return TabBarView(
      controller: _tabs,
      children: [
        for (final s in _tabSpecs) _buildBody(s),
      ],
    );
  }

  Widget _desktopBody() {
    return Row(
      children: [
        NavigationRail(
          extended: true,
          minExtendedWidth: 184,
          selectedIndex: _tabs.index,
          groupAlignment: -0.92,
          onDestinationSelected: _selectTab,
          destinations: [
            for (final s in _tabSpecs)
              NavigationRailDestination(
                icon: Icon(s.icon),
                label: Text(s.label),
              ),
          ],
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final s in _tabSpecs) _buildBody(s),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody(_TabSpec spec) {
    switch (spec) {
      case _TabSpec.pipeline:
        return PipelineBoard(
          onTogglePipeline: _togglePipeline,
          onOpen: _openNote,
        );
      case _TabSpec.inbox:
        return const InboxScreen(embedded: true);
      case _TabSpec.todo:
        return const QuickListScreen(kind: QuickListKind.todo);
      case _TabSpec.chat:
        return const ChatScreen();
      case _TabSpec.liveShare:
        return const LiveShareScreen();
      case _TabSpec.files:
        return const FilesScreen();
      case _TabSpec.decisions:
        return const DecisionsScreen(embedded: true);
      case _TabSpec.activity:
        return const ActivityScreen(embedded: true);
      case _TabSpec.notes:
        return _NotesTab(
          searchCtl: _searchCtl,
          searchFocus: _searchFocus,
          onTogglePipeline: _togglePipeline,
          onOpen: _openNote,
          onDelete: _archiveNote,
        );
    }
  }

  Widget _appBarActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
          ),
        ),
        const _NotificationsButton(),
        PopupMenuButton<_CreateAction>(
          icon: const Icon(Icons.add_circle_outline),
          tooltip: 'Create',
          onSelected: _handleCreateAction,
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _CreateAction.note,
              child: ListTile(
                leading: Icon(Icons.edit_note),
                title: Text('Note'),
              ),
            ),
            PopupMenuItem(
              value: _CreateAction.checklist,
              child: ListTile(
                leading: Icon(Icons.checklist),
                title: Text('Checklist'),
              ),
            ),
            PopupMenuItem(
              value: _CreateAction.idea,
              child: ListTile(
                leading: Icon(Icons.lightbulb_outline),
                title: Text('Idea'),
              ),
            ),
            PopupMenuItem(
              value: _CreateAction.meeting,
              child: ListTile(
                leading: Icon(Icons.groups_outlined),
                title: Text('Meeting note'),
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.folder_outlined),
          tooltip: 'Folders',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FoldersScreen()),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  Widget _mobileAppBarActions() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Search',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const GlobalSearchScreen()),
          ),
        ),
        PopupMenuButton<_MobileMoreAction>(
          icon: const Icon(Icons.more_vert),
          tooltip: 'More',
          onSelected: (action) {
            switch (action) {
              case _MobileMoreAction.note:
                _newNote(NoteType.note);
                break;
              case _MobileMoreAction.checklist:
                _newNote(NoteType.checklist);
                break;
              case _MobileMoreAction.idea:
                _newIdea();
                break;
              case _MobileMoreAction.meeting:
                _newMeetingNote();
                break;
              case _MobileMoreAction.notifications:
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                );
                break;
              case _MobileMoreAction.folders:
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FoldersScreen()),
                );
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _MobileMoreAction.note,
              child: ListTile(
                leading: Icon(Icons.edit_note),
                title: Text('Note'),
              ),
            ),
            PopupMenuItem(
              value: _MobileMoreAction.checklist,
              child: ListTile(
                leading: Icon(Icons.checklist),
                title: Text('Checklist'),
              ),
            ),
            PopupMenuItem(
              value: _MobileMoreAction.idea,
              child: ListTile(
                leading: Icon(Icons.lightbulb_outline),
                title: Text('Idea'),
              ),
            ),
            PopupMenuItem(
              value: _MobileMoreAction.meeting,
              child: ListTile(
                leading: Icon(Icons.groups_outlined),
                title: Text('Meeting note'),
              ),
            ),
            PopupMenuItem(
              value: _MobileMoreAction.notifications,
              child: ListTile(
                leading: Icon(Icons.notifications_none),
                title: Text('Notifications'),
              ),
            ),
            PopupMenuItem(
              value: _MobileMoreAction.folders,
              child: ListTile(
                leading: Icon(Icons.folder_outlined),
                title: Text('Folders'),
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          tooltip: 'Settings',
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
        ),
      ],
    );
  }

  void _handleCreateAction(_CreateAction action) {
    switch (action) {
      case _CreateAction.note:
        _newNote(NoteType.note);
        break;
      case _CreateAction.checklist:
        _newNote(NoteType.checklist);
        break;
      case _CreateAction.idea:
        _newIdea();
        break;
      case _CreateAction.meeting:
        _newMeetingNote();
        break;
    }
  }

  Widget _fab() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'fab-check',
          tooltip: 'New checklist (Ctrl+L)',
          onPressed: () => _newNote(NoteType.checklist),
          child: const Icon(Icons.checklist),
        ),
        const SizedBox(width: 12),
        FloatingActionButton(
          heroTag: 'fab-note',
          tooltip: 'New note (Ctrl+N)',
          onPressed: () => _newNote(NoteType.note),
          child: const Icon(Icons.edit_note),
        ),
      ],
    );
  }
}

enum _TabSpec {
  pipeline(Icons.timeline, 'Pipeline'),
  inbox(Icons.inbox_outlined, 'Inbox'),
  todo(Icons.task_alt, 'To-Do'),
  chat(Icons.forum_outlined, 'Chat'),
  liveShare(Icons.co_present_outlined, 'Live Share'),
  files(Icons.folder_copy_outlined, 'Files'),
  decisions(Icons.fact_check_outlined, 'Decisions'),
  activity(Icons.auto_awesome_motion_outlined, 'Activity'),
  notes(Icons.notes, 'Notes');

  const _TabSpec(this.icon, this.label);
  final IconData icon;
  final String label;
}

enum _CreateAction { note, checklist, idea, meeting }

enum _MobileMoreAction {
  note,
  checklist,
  idea,
  meeting,
  notifications,
  folders,
}

class _NotificationsButton extends ConsumerWidget {
  const _NotificationsButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(unreadNotificationsCountProvider).valueOrNull ?? 0;
    return IconButton(
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text(count > 99 ? '99+' : '$count'),
        child: const Icon(Icons.notifications_none),
      ),
      tooltip: 'Notifications',
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
    );
  }
}

class _AppBarTitle extends StatelessWidget {
  final bool showNewNoteButton;
  final VoidCallback onNewNote;

  const _AppBarTitle({
    required this.showNewNoteButton,
    required this.onNewNote,
  });

  @override
  Widget build(BuildContext context) {
    final wordmark = Theme.of(context).brightness == Brightness.dark
        ? 'assets/brand/logo-wordmark-dark.png'
        : 'assets/brand/logo-wordmark-light.png';
    return Row(
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Image.asset(
            wordmark,
            height: 28,
            fit: BoxFit.contain,
            alignment: Alignment.centerLeft,
            errorBuilder: (_, __, ___) => const Text(
              'CardTrove Companion',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (showNewNoteButton)
          Expanded(
            child: Center(
              child: SizedBox(
                height: 40,
                child: FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('New note'),
                  onPressed: onNewNote,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _NotesTab extends ConsumerStatefulWidget {
  final TextEditingController searchCtl;
  final FocusNode searchFocus;
  final void Function(Note) onTogglePipeline;
  final void Function(BuildContext, Note) onOpen;
  final Future<void> Function(Note) onDelete;

  const _NotesTab({
    required this.searchCtl,
    required this.searchFocus,
    required this.onTogglePipeline,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  ConsumerState<_NotesTab> createState() => _NotesTabState();
}

class _NotesTabState extends ConsumerState<_NotesTab> {
  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesStreamProvider);
    final notes = ref.watch(filteredNotesProvider);
    final hasSearch = widget.searchCtl.text.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: widget.searchCtl,
            focusNode: widget.searchFocus,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search notes',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              isDense: true,
              suffixIcon: hasSearch
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        widget.searchCtl.clear();
                        ref.read(searchQueryProvider.notifier).state = '';
                        setState(() {});
                      },
                    )
                  : null,
            ),
            onChanged: (v) {
              ref.read(searchQueryProvider.notifier).state = v;
              setState(() {});
            },
          ),
        ),
        const FolderFilterBar(),
        Expanded(
          child: notesAsync.when(
            data: (_) => notes.isEmpty
                ? _NotesEmpty(searching: hasSearch)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    itemCount: notes.length,
                    itemBuilder: (ctx, i) {
                      final note = notes[i];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Dismissible(
                          key: ValueKey(note.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.archive_outlined,
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (dctx) => AlertDialog(
                                title: Text(
                                  'Archive "${note.title.isEmpty ? "this note" : note.title}"?',
                                ),
                                content: const Text(
                                  'Archived notes leave active views and can be restored from Settings.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(dctx, true),
                                    child: const Text('Archive'),
                                  ),
                                ],
                              ),
                            );
                            return ok ?? false;
                          },
                          onDismissed: (_) => widget.onDelete(note),
                          child: NoteCard(
                            note: note,
                            onTap: () => widget.onOpen(ctx, note),
                            onTogglePipeline: () =>
                                widget.onTogglePipeline(note),
                          ),
                        ),
                      );
                    },
                  ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Failed to load notes:\n$e',
                    textAlign: TextAlign.center),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NewNoteIntent extends Intent {
  final NoteType type;
  const _NewNoteIntent(this.type);
}

class _FocusSearchIntent extends Intent {
  const _FocusSearchIntent();
}

class _NotesEmpty extends StatelessWidget {
  final bool searching;
  const _NotesEmpty({required this.searching});

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            searching ? Icons.search_off : Icons.note_outlined,
            size: 64,
            color: hint,
          ),
          const SizedBox(height: 16),
          Text(searching ? 'No matches' : 'No notes yet'),
          const SizedBox(height: 4),
          Text(
            searching ? 'Try a different search' : 'Tap + to create one',
            style: TextStyle(color: hint),
          ),
        ],
      ),
    );
  }
}
