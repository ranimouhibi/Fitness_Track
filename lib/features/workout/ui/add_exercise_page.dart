import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../data/change_request_repository.dart';
import '../data/workout_repository.dart';

class AddExercisePage extends ConsumerStatefulWidget {
  /// Admin adds and edits apply right away. Others wait for approval.
  final bool isAdmin;

  /// Pre-selects the muscle group when opened from a body-part page.
  final String? initialGroup;

  /// When set, the form edits this exercise instead of adding one.
  final Exercise? existing;

  const AddExercisePage({
    super.key,
    this.isAdmin = false,
    this.initialGroup,
    this.existing,
  });

  @override
  ConsumerState<AddExercisePage> createState() => _AddExercisePageState();
}

class _AddExercisePageState extends ConsumerState<AddExercisePage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  final _instructions = TextEditingController();
  final _repo = WorkoutRepository();
  final _changes = ChangeRequestRepository();
  final _picker = ImagePicker();

  late String _group;
  final Set<String> _materials = {};
  String? _pickedPath;
  String? _currentMedia;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _group = e?.muscleGroup ?? widget.initialGroup ?? muscleGroups.first;
    if (e != null) {
      _name.text = e.name;
      _description.text = e.description ?? '';
      _instructions.text = e.steps.join('\n');
      _materials.addAll(
        (e.equipment ?? '').split(', ').where(materialOptions.contains),
      );
      _currentMedia = e.mediaPath;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _instructions.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file != null) setState(() => _pickedPath = file.path);
  }

  /// Copies the picked image into the app's own folder so it stays available.
  Future<String> _saveMedia(String source) async {
    final dir = await getApplicationDocumentsDirectory();
    final mediaDir = Directory(p.join(dir.path, 'exercise_media'));
    await mediaDir.create(recursive: true);
    final dest = p.join(
      mediaDir.path,
      '${DateTime.now().millisecondsSinceEpoch}${p.extension(source)}',
    );
    await File(source).copy(dest);
    return dest;
  }

  void _fail(String message) => setState(() => _error = message);

  Future<void> _submit() async {
    final nameError = Validators.requiredText(_name.text, 'the exercise name');
    if (nameError != null) {
      _fail(nameError);
      return;
    }
    if (_materials.isEmpty) {
      _fail('Choose at least one material.');
      return;
    }
    final instructionsError = Validators.minLength(
        _instructions.text, 'the instructions', 10);
    if (instructionsError != null) {
      _fail(instructionsError);
      return;
    }
    final user = ref.read(sessionProvider);
    if (user == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final media =
        _pickedPath != null ? await _saveMedia(_pickedPath!) : _currentMedia;
    final payload = exercisePayload(
      name: _name.text,
      muscleGroup: _group,
      equipment: materialOptions.where(_materials.contains).join(', '),
      description: _description.text,
      instructions: _instructions.text,
      mediaPath: media,
    );

    final existing = widget.existing;
    if (existing != null && widget.isAdmin) {
      await _repo.updateExercise(existing.id, payload);
    } else if (existing != null) {
      await _changes.submit(
        type: 'edit',
        table: 'exercises',
        targetId: existing.id,
        userId: user.id,
        payload: {...payload, 'target_name': existing.name},
      );
    } else {
      await _repo.addExercise(
        payload: payload,
        userId: user.id,
        isAdmin: widget.isAdmin,
      );
    }

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    final title = editing
        ? 'Edit exercise'
        : (widget.isAdmin ? 'Add exercise' : 'Add an exercise');
    final buttonLabel = widget.isAdmin
        ? 'Save'
        : (editing ? 'Send edit to admin' : 'Submit to admin');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!widget.isAdmin)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Reviewed by an admin before it appears in the app.',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          TextField(
            controller: _name,
            maxLength: 60,
            decoration: _decoration('Exercise name'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _group,
            decoration: _decoration('Muscle targeted'),
            items: [
              for (final g in muscleGroups)
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: (v) => setState(() => _group = v ?? _group),
          ),
          const SizedBox(height: 16),
          const Text('Materials needed',
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in materialOptions)
                FilterChip(
                  label: Text(m),
                  selected: _materials.contains(m),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _materials.add(m);
                    } else {
                      _materials.remove(m);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _description,
            maxLines: 3,
            maxLength: 300,
            decoration: _decoration('Description'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _instructions,
            maxLines: 6,
            maxLength: 1000,
            decoration: _decoration('Instructions (one step per line)'),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickMedia,
            icon: const Icon(Icons.upload_outlined),
            label: Text(_pickedPath == null && _currentMedia == null
                ? 'Add a photo or GIF (optional)'
                : 'Change photo or GIF'),
          ),
          if (_pickedPath != null || _currentMedia != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Image.file(
                  File(_pickedPath ?? _currentMedia!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.white),
                    )
                  : Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );
}