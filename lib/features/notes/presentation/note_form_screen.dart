import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/friendly_error.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../employees/data/employee_repository.dart';
import '../../employees/presentation/people_checklist.dart';
import '../../profile/domain/profile_model.dart';
import '../data/note_repository.dart';
import '../domain/note_model.dart';

/// Adds a note, or edits [existing]: a title, the text, and — optionally —
/// the employees who can read it. With nobody ticked the note is only the
/// boss's own.
class NoteFormScreen extends ConsumerStatefulWidget {
  const NoteFormScreen({super.key, required this.companyId, this.existing});

  final String companyId;
  final NoteModel? existing;

  @override
  ConsumerState<NoteFormScreen> createState() => _NoteFormScreenState();
}

class _NoteFormScreenState extends ConsumerState<NoteFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(
    text: widget.existing?.title ?? '',
  );
  late final _contentController = TextEditingController(
    text: widget.existing?.content ?? '',
  );
  bool _saving = false;

  /// The employees this note is shared with (starts from its current ones).
  late final Set<String> _recipientIds = {
    if (widget.existing != null)
      for (final recipient
          in ref.read(noteRecipientsProvider).valueOrNull ?? const [])
        if (recipient.noteId == widget.existing!.id) recipient.employeeId,
  };

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      final repository = ref.read(noteRepositoryProvider);
      final title = _titleController.text.trim();
      final content = _contentController.text.trim();
      final String noteId;
      if (_isEditing) {
        noteId = widget.existing!.id;
        await repository.updateNote(
          noteId: noteId,
          title: title,
          content: content,
        );
      } else {
        noteId = await repository.createNote(
          companyId: widget.companyId,
          title: title,
          content: content,
        );
      }
      await repository.setRecipients(
        noteId: noteId,
        companyId: widget.companyId,
        employeeIds: _recipientIds,
      );
      ref.invalidate(noteListProvider);
      ref.invalidate(noteRecipientsProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.noteSavedSuccess)));
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(
          SnackBar(content: Text(friendlyErrorText(l10n, error))),
        );
      }
    }
  }

  Future<void> _delete() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteNoteTooltip),
        content: Text(l10n.deleteNoteConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancelButton),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(noteRepositoryProvider).deleteNote(widget.existing!.id);
      ref.invalidate(noteListProvider);
      ref.invalidate(noteRecipientsProvider);
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text(l10n.noteDeletedSuccess)));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(friendlyErrorText(l10n, error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final employees =
        ref.watch(employeeListProvider).valueOrNull ?? const <ProfileModel>[];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? l10n.editNoteTitle : l10n.addNoteTitle),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteNoteTooltip,
              onPressed: _saving ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      enabled: !_saving,
                      autofocus: !_isEditing,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: l10n.noteTitleLabel,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? l10n.noteTitleRequiredError
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contentController,
                      enabled: !_saving,
                      minLines: 5,
                      maxLines: 14,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: l10n.noteContentLabel,
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      l10n.noteShareSectionTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.noteShareHint,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (employees.isNotEmpty)
                      PeopleChecklist(
                        people: employees,
                        selected: _recipientIds,
                        enabled: !_saving,
                        onChanged: (value) => setState(() {
                          _recipientIds
                            ..clear()
                            ..addAll(value);
                        }),
                      ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.saveButton),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the note form to add a note or, with [existing], edit one.
void openNoteForm(
  BuildContext context, {
  required String companyId,
  NoteModel? existing,
}) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) =>
          NoteFormScreen(companyId: companyId, existing: existing),
    ),
  );
}
