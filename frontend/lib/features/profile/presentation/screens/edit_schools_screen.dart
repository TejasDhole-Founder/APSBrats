import 'package:apsbrat_frontend/core/theme/app_theme.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:apsbrat_frontend/features/auth/data/auth_repository.dart';
import 'package:apsbrat_frontend/features/feed/presentation/widgets/feed_shared.dart';
import 'package:apsbrat_frontend/features/onboarding/data/models/school_history_registration_model.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/providers/onboarding_flow_provider.dart';
import 'package:apsbrat_frontend/features/onboarding/presentation/widgets/school_history_editor.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_models.dart';
import 'package:apsbrat_frontend/features/profile/data/profile_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Edits the logged-in user's school list with the same cards as onboarding,
/// then saves the whole list in one call (the backend replaces it).
class EditSchoolsScreen extends ConsumerStatefulWidget {
  const EditSchoolsScreen({super.key});

  @override
  ConsumerState<EditSchoolsScreen> createState() => _EditSchoolsScreenState();
}

class _EditSchoolsScreenState extends ConsumerState<EditSchoolsScreen> {
  List<SchoolHistoryDraft>? _drafts;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await ref.read(mySchoolHistoryProvider.future);
    if (!mounted) return;
    final drafts = saved.map(_draftFrom).toList();
    setState(() {
      _drafts = drafts.isEmpty ? [const SchoolHistoryDraft()] : drafts;
    });
  }

  /// Saved row → editable card. Class numbers become the dropdown labels
  /// ("10" → "10th") so the card shows the current values.
  SchoolHistoryDraft _draftFrom(SchoolHistory h) {
    return SchoolHistoryDraft(
      schoolId: h.schoolId ?? '',
      schoolName: h.schoolName ?? '',
      classFrom: _classLabel(h.classFrom),
      classTo: _classLabel(h.classTo),
      section: h.section,
      stream: h.stream ?? '',
      yearJoined: '${h.batchStart}',
      yearLeft: '${h.batchEnd}',
      isMostMissed: h.isPrimary,
    );
  }

  String _classLabel(int classNumber) {
    final index = classNumber - 1;
    return index >= 0 && index < kClassOptions.length
        ? kClassOptions[index]
        : '';
  }

  void _add() =>
      setState(() => _drafts = [..._drafts!, const SchoolHistoryDraft()]);

  void _remove(int index) {
    if (_drafts!.length <= 1) return;
    setState(() => _drafts = [..._drafts!]..removeAt(index));
  }

  void _update(int index, SchoolHistoryDraft draft) {
    setState(() => _drafts = [..._drafts!]..[index] = draft);
  }

  Future<void> _save() async {
    final drafts = _drafts!;
    final problem = schoolDraftsProblem(drafts);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final userId = await ref.read(authRepositoryProvider).currentUserId();
      if (userId == null || userId.isEmpty) {
        throw StateError('Not logged in');
      }
      final items = drafts
          .map(SchoolHistoryRegistrationModel.fromDraft)
          .map((m) => m.toJson())
          .toList();
      await ref
          .read(profileRepositoryProvider)
          .replaceSchoolHistory(userId, items);

      ref.invalidate(mySchoolHistoryProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Schools updated')));
      context.pop();
    } on DioException catch (e) {
      final payload = e.response?.data;
      var message = 'Could not save. Please try again.';
      if (payload is Map<String, dynamic> && payload['error'] is String) {
        message = payload['error'] as String;
      }
      if (mounted) setState(() => _error = message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final drafts = _drafts;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Column(
          children: [
            CrimsonHeader(
              waveColor: Colors.white,
              child: Row(
                children: [
                  FeedIconBtn(
                    icon: HugeIcons.strokeRoundedArrowLeft01,
                    onTap: () => context.pop(),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Edit schools',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (drafts == null)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.crimson),
                ),
              )
            else ...[
              Expanded(
                child: SingleChildScrollView(
                  child: SchoolHistoryEditor(
                    drafts: drafts,
                    onAdd: _add,
                    onRemove: _remove,
                    onUpdate: _update,
                  ),
                ),
              ),
              _SaveBar(saving: _saving, error: _error, onSave: _save),
            ],
          ],
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.saving,
    required this.error,
    required this.onSave,
  });

  final bool saving;
  final String? error;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Column(
        children: [
          if (error != null) ...[
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
          ],
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.crimson,
              minimumSize: const Size(double.infinity, 48),
              shape: const StadiumBorder(),
            ),
            onPressed: saving ? null : onSave,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Save changes',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }
}
