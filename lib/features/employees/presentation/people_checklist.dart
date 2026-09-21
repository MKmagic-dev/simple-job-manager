import 'package:flutter/material.dart';

import '../../../l10n/generated/app_localizations.dart';
import '../../profile/domain/profile_model.dart';
import 'employee_list_screen.dart' show MemberAvatar;

/// A searchable multi-select list of people — built so it stays usable with
/// a hundred names: a search box (once the list is long), "select everyone
/// shown", and a scroll area of bounded height instead of a page-long column.
class PeopleChecklist extends StatefulWidget {
  const PeopleChecklist({
    super.key,
    required this.people,
    required this.selected,
    required this.onChanged,
    this.enabled = true,
    this.maxHeight = 320,
  });

  final List<ProfileModel> people;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;
  final double maxHeight;

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

    void toggle(String id, bool checked) {
      final next = {...widget.selected};
      checked ? next.add(id) : next.remove(id);
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
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: widget.maxHeight),
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(child: Text(l10n.noPeopleMatchSearch)),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final person in visible)
                      CheckboxListTile(
                        value: widget.selected.contains(person.id),
                        onChanged: widget.enabled
                            ? (checked) => toggle(person.id, checked ?? false)
                            : null,
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        secondary: MemberAvatar(member: person, radius: 16),
                        title: Text(person.fullName),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Asks which of [people] to pick. Returns the chosen ids, or null when
/// cancelled.
Future<Set<String>?> showPeoplePickerDialog(
  BuildContext context, {
  required String title,
  required List<ProfileModel> people,
}) {
  return showDialog<Set<String>>(
    context: context,
    builder: (context) {
      final l10n = AppLocalizations.of(context)!;
      var selected = <String>{};
      return StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: people.isEmpty
                ? Text(l10n.noMoreEmployeesToAdd)
                : PeopleChecklist(
                    people: people,
                    selected: selected,
                    onChanged: (value) => setState(() => selected = value),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.cancelButton),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(selected),
              child: Text(l10n.addSelectedButton(selected.length)),
            ),
          ],
        ),
      );
    },
  );
}
