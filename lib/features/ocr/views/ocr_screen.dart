import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';
import '../../task/viewmodels/task_view_model.dart';
import '../viewmodels/ocr_view_model.dart';

class OcrScreen extends ConsumerStatefulWidget {
  const OcrScreen({super.key});
  @override
  ConsumerState<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends ConsumerState<OcrScreen> {
  final _controller = TextEditingController(text: OcrViewModel.sampleText);
  final _ocr = OcrViewModel();
  List<String> _candidates = const [];
  final Set<int> _registered = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _analyze() => setState(() {
    _candidates = _ocr.extractTaskCandidates(_controller.text);
    _registered.clear();
  });

  Future<void> _register(int index) async {
    try {
      await ref.read(taskViewModelProvider).add(title: _candidates[index]);
      if (!mounted) return;
      setState(() => _registered.add(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('태스크에 등록했습니다.')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('등록 실패: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('메모에서 태스크 추출')),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(padding: const EdgeInsets.all(18), children: [
          Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.document_scanner_outlined, size: 38, color: scheme.primary),
              const SizedBox(height: 8),
              Text('OCR → 태스크 등록', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              const Text('현재는 카메라/ML Kit 연결 전 단계입니다.\n인식된 텍스트라고 가정한 내용을 입력해 동작을 테스트합니다.'),
            ])),
          const SizedBox(height: 22),
          TextField(controller: _controller, minLines: 6, maxLines: 10,
            decoration: const InputDecoration(
              labelText: '인식된 메모 내용 (한 줄에 태스크 하나)',
              alignLabelWithHint: true, border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(onPressed: () {
              _controller.text = OcrViewModel.sampleText;
              _analyze();
            }, icon: const Icon(Icons.restart_alt), label: const Text('샘플')), 
            const SizedBox(width: 9),
            Expanded(child: FilledButton.icon(onPressed: _analyze,
              icon: const Icon(Icons.auto_awesome), label: const Text('텍스트 분석'))),
          ]),
          const SizedBox(height: 24),
          Text('추출한 태스크 후보', style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          if (_candidates.isEmpty)
            const EmptyState(message: '텍스트 분석을 누르면 태스크 후보가 표시됩니다.',
              icon: Icons.fact_check_outlined),
          for (var i = 0; i < _candidates.length; i++)
            Card(child: ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: Text(_candidates[i]),
              trailing: _registered.contains(i)
                ? const Icon(Icons.check_circle, color: Colors.green)
                : TextButton(onPressed: () => _register(i), child: const Text('등록')),
            )),
        ]),
      )),
    );
  }
}
