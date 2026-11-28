import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/task_due_date_field.dart';
import '../../task/viewmodels/task_view_model.dart';
import '../services/android_ocr_service.dart';
import '../viewmodels/ocr_view_model.dart';

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});

  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  final _demoText = TextEditingController(text: OcrViewModel.sampleText);
  final _ocr = OcrViewModel();
  final _candidates = <_Candidate>[];
  bool _reading = false;
  bool _saving = false;
  bool _hasResult = false;
  String? _message;
  int? _elapsedMilliseconds;

  bool get _busy => _reading || _saving;

  @override
  void initState() {
    super.initState();
    if (AndroidOcrService.isSupported) _readPhoto();
  }

  @override
  void dispose() {
    _demoText.dispose();
    super.dispose();
  }

  void _showCandidates(String text, {int? elapsedMilliseconds}) {
    final titles = _ocr.extractTaskCandidates(text);
    setState(() {
      _elapsedMilliseconds = elapsedMilliseconds;
      _hasResult = true;
      _message = null;
      _candidates
        ..clear()
        ..addAll(titles.map(_Candidate.new));
    });
  }

  Future<void> _readPhoto([ImageSource? source]) async {
    if (_busy) return;
    setState(() {
      _reading = true;
      _message = null;
    });
    try {
      final result = await AndroidOcrService.instance.read(source: source);
      if (!mounted || result == null) return;
      _showCandidates(
        result.lines.join('\n'),
        elapsedMilliseconds: result.elapsedMilliseconds,
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'camera_access_denied' ||
        'camera_access_restricted' ||
        'camera_access_denied_without_prompt' =>
          '카메라 권한이 필요합니다. 기기 설정에서 Keepy에 카메라 권한을 허용하거나 사진을 선택해 주세요.',
        'no_available_camera' => '카메라를 열 수 없습니다. 기존 사진을 선택해 주세요.',
        'photo_access_denied' ||
        'photo_access_restricted' => '사진에 접근할 수 없습니다. 접근 가능한 다른 사진을 선택해 주세요.',
        _ => '사진을 처리하지 못했습니다. 기기에 저장된 다른 사진으로 다시 시도해 주세요.',
      };
      setState(() => _message = message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = '사진을 읽지 못했습니다. 다른 사진으로 다시 시도해 주세요.');
      }
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  void _discardReview() {
    setState(() {
      _candidates.clear();
      _hasResult = false;
      _elapsedMilliseconds = null;
      _message = null;
    });
  }

  Future<void> _saveSelected() async {
    if (_busy) return;
    final selected = _candidates.where((item) => item.selected).toList();
    if (selected.isEmpty || selected.any((item) => item.title.trim().isEmpty)) {
      return;
    }
    setState(() {
      _saving = true;
      _message = null;
    });
    final saved = <_Candidate>{};
    try {
      final tasks = ref.read(taskViewModelProvider);
      for (final item in selected) {
        if (!mounted) return;
        await tasks.add(title: item.title.trim(), dueAt: item.dueAt);
        saved.add(item);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = '일부 항목을 등록하지 못했습니다. 남은 항목을 다시 저장해 주세요.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _candidates.removeWhere(saved.contains);
          _saving = false;
          if (_candidates.isEmpty) _hasResult = false;
        });
        if (saved.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('태스크 ${saved.length}개를 추가했습니다.')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final nativeOcr = AndroidOcrService.isSupported;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final selected = _candidates.where((item) => item.selected).toList();
    final hasEmptySelection = selected.any((item) => item.title.trim().isEmpty);
    final elapsed = _elapsedMilliseconds;
    return Scaffold(
      appBar: AppBar(title: const Text('메모에서 태스크 추출')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.document_scanner_outlined,
                      size: 38,
                      color: scheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      nativeOcr ? '사진에서 할 일 가져오기' : 'OCR 텍스트 데모',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      nativeOcr
                          ? '기기에서 한글과 영문을 인식합니다. 저장할 항목을 확인하고 선택하세요.'
                          : '실제 사진 인식은 Android에서 사용할 수 있습니다. 여기서는 입력한 텍스트로 검토와 저장을 체험할 수 있습니다.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              if (nativeOcr)
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed:
                          _busy ? null : () => _readPhoto(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('카메라 촬영'),
                    ),
                    OutlinedButton.icon(
                      onPressed:
                          _busy ? null : () => _readPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('사진 선택'),
                    ),
                  ],
                )
              else ...[
                TextField(
                  controller: _demoText,
                  enabled: !_busy,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: '데모 텍스트 (한 줄에 태스크 하나)',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    onPressed:
                        _busy ? null : () => _showCandidates(_demoText.text),
                    icon: const Icon(Icons.list_alt),
                    label: const Text('후보 만들기'),
                  ),
                ),
              ],
              if (_reading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(semanticsLabel: '사진 처리 중'),
              ],
              if (elapsed != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    '인식 시간: $elapsed ms',
                    style: textTheme.labelLarge,
                  ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_message!, style: TextStyle(color: scheme.error)),
                ),
              const SizedBox(height: 24),
              if (_hasResult) ...[
                Text(
                  '태스크 후보 검토',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                if (_candidates.isEmpty)
                  const EmptyState(
                    message: '인식된 텍스트가 없습니다. 다른 사진이나 텍스트를 사용해 주세요.',
                    icon: Icons.fact_check_outlined,
                  ),
                for (final item in _candidates)
                  Card(
                    key: ObjectKey(item),
                    child: ListTile(
                      leading: Checkbox(
                        value: item.selected,
                        semanticLabel: '후보 선택',
                        onChanged:
                            _busy
                                ? null
                                : (value) {
                                  setState(
                                    () => item.selected = value ?? false,
                                  );
                                },
                      ),
                      title: TextFormField(
                        initialValue: item.title,
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: '후보 제목',
                          errorText:
                              item.selected && item.title.trim().isEmpty
                                  ? '제목을 입력해 주세요.'
                                  : null,
                        ),
                        onChanged:
                            (value) => setState(() => item.title = value),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TaskDueDateField(
                          dueAt: item.dueAt,
                          emptyLabel: '마감일 없음',
                          onChanged:
                              _busy
                                  ? null
                                  : (date) => setState(() => item.dueAt = date),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      onPressed:
                          _busy || selected.isEmpty || hasEmptySelection
                              ? null
                              : _saveSelected,
                      child: Text(
                        _saving ? '등록 중…' : '선택한 ${selected.length}개 저장',
                      ),
                    ),
                    TextButton(
                      onPressed: _busy ? null : _discardReview,
                      child: const Text('검토 취소'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Candidate {
  _Candidate(this.title);

  String title;
  DateTime? dueAt;
  bool selected = true;
}
