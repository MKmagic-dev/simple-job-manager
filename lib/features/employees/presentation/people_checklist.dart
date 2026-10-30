import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../profile/domain/profile_model.dart';
import 'employee_list_screen.dart' show MemberAvatar;

/// A multi-select of people shown as a grid of round photos/initials with the
/// name underneath — everyone visible at once, no inner scrolling (the page
/// around it scrolls), so even a hundred people read as a tidy block. Tap a
/// person to pick or unpick them. Above the grid: a search box (once the list
/// is long) and "select everyone shown".
class PeopleChecklist extends StatefulWidget {
  const PeopleChecklist({
    super.key,
    required this.people,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
  });

  final List<ProfileModel> people;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;

  @override
  State<PeopleChecklist> createState() => _PeopleChecklistState();
}

class _PeopleChecklistState extends State<PeopleChecklist> {
  static const _searchThreshold = 6;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = _query.trim().toLowerCase();
    final visible = [
      for (final person in widget.people)
        if (query.isEmpty || person.fullName.toLowerCase().contains(query))
          person,
    ];
    final allVisibleSelected =
        visible.isNotEmpty &&
        visible.every((person) => widget.selected.contains(person.id));

    void toggle(String id) {
      final next = {...widget.selected};
      next.contains(id) ? next.remove(id) : next.add(id);
      widget.onChanged(next);
    }

    void toggleAllVisible() {
      final next = {...widget.selected};
      for (final person in visible) {
        allVisibleSelected ? next.remove(person.id) : next.add(person.id);
      }
      widget.onChanged(next);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.people.length > _searchThreshold)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              enabled: widget.enabled,
              decoration: InputDecoration(
                hintText: l10n.searchPeopleHint,
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
        if (widget.people.length > 1)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.enabled && visible.isNotEmpty
                  ? toggleAllVisible
                  : null,
              icon: Icon(
                allVisibleSelected
                    ? Icons.check_box_outlined
                    : Icons.check_box_outline_blank,
                size: 20,
              ),
              label: Text(l10n.selectAllButton),
            ),
          ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(child: Text(l10n.noPeopleMatchSearch)),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 12,
              children: [
                for (final person in visible)
                  _PersonTile(
                    person: person,
                    selected: widget.selected.contains(person.id),
                    onTap: widget.enabled ? () => toggle(person.id) : null,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// One person: round photo (or initials), first line of the name, and a lime
/// ring + check badge when picked.
class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  final ProfileModel person;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: person.fullName,
      child: Tooltip(
        message: person.fullName,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(
            width: 84,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? theme.colorScheme.primary
                                : Colors.transparent,
                            width: 3,
                          ),
                        ),
                        child: Opacity(
                          opacity: selected || onTap == null ? 1 : 0.7,
                          child: MemberAvatar(member: person, radius: 28),
                        ),
                      ),
                      if (selected)
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Icon(
                            Icons.check_circle,
                            size: 24,
                            color: theme.colorScheme.primary,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    person.fullName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: selected ? FontWeight.bold : null,
                      color: selected ? theme.colorScheme.primary : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks which of [people] to pick, on its own full page (not a small pop-up):
/// all of them as icons, with search, "select everyone" and a confirm button
/// showing how many are chosen. Returns the chosen ids, or null if cancelled.
Future<Set<String>?> showPeoplePickerDialog(
  BuildContext context, {
  required String title,
  required List<ProfileModel> people,
}) {
  return Navigator.of(context).push<Set<String>>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (context) => _PeoplePickerPage(title: title, people: people),
    ),
  );
}

class _PeoplePickerPage extends StatefulWidget {
  const _PeoplePickerPage({required this.title, required this.people});

  final String title;
  final List<ProfileModel> people;

  @override
  State<_PeoplePickerPage> createState() => _PeoplePickerPageState();
}

class _PeoplePickerPageState extends State<_PeoplePickerPage> {
  Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: widget.people.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(32),
                            child: Center(
                              child: Text(l10n.noMoreEmployeesToAdd),
                            ),
                          )
                        : PeopleChecklist(
                            people: widget.people,
                            selected: _selected,
                            onChanged: (value) =>
                                setState(() => _selected = value),
                          ),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.cancelButton),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _selected.isEmpty
                        ? null
                        : () => Navigator.of(context).pop(_selected),
                    child: Text(l10n.addSelectedButton(_selected.length)),
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
