import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/dates.dart';
import '../../core/theme.dart';
import '../../game/pixel_art.dart';
import '../../models/app_settings.dart';
import '../../services/character_maker.dart';
import '../../state/keepy_scope.dart';
import '../../state/task_store.dart';
import '../widgets/basics.dart';

/// 설정에 맞는 캐릭터 그림 (남자 / 여자 / 내 사진).
PixelSprite characterSpriteOf(AppSettings s) => switch (s.effectiveCharacterStyle) {
      CharacterStyle.boy => boySprite(),
      CharacterStyle.girl => girlSprite(),
      CharacterStyle.photo => PixelSprite(AppSettings.characterSize, s.characterPixels!),
    };

/// 설정에 맞는 펫 그림 (없으면 null).
PixelSprite? petSpriteOf(PetKind pet) => switch (pet) {
      PetKind.none => null,
      PetKind.dog => dogSprite(),
      PetKind.cat => catSprite(),
      PetKind.rabbit => rabbitSprite(),
    };

/// 미니게임: 계단 오르기 (v0.3 요청 #6~8, v0.4 다듬기).
///
/// - 설정/메인/날짜와 상관없는 별도 영역 (카메라 화면처럼 전체 화면). X 로 언제든 나간다.
/// - 계단 수 = 이번 달 할 일 수 (미완료·지연 포함), 오른 칸 = 완료 수.
/// - 이번 달 완료율 100% → 정상 도착 + 만세 모션과 폭죽, 펫도 함께 뛴다.
///   100% 가 아니면 → 격려 문구와 응원 모션.
/// - v0.4: 캐릭터 남자/여자/내 사진 고르기, 펫(강아지·고양이·토끼) 데리고 가기,
///   진행 막대·오늘 오른 칸, 다크 모드에서는 밤하늘.
/// - v0.5: 펫은 캐릭터와 같은 칸에 나란히 서서 함께 오른다. 캐릭터·펫을 더 둥글게.
class StairGamePage extends StatefulWidget {
  const StairGamePage({super.key, this.picker});

  final ImagePicker? picker;

  static Future<void> open(BuildContext context) {
    HapticFeedback.selectionClick();
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, _, _) => const StairGamePage(),
        transitionsBuilder: (_, anim, _, child) => FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.96, end: 1).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  State<StairGamePage> createState() => _StairGamePageState();
}

class _StairGamePageState extends State<StairGamePage> with TickerProviderStateMixin {
  late final AnimationController _climb = AnimationController(vsync: this);
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
  late final ImagePicker _picker = widget.picker ?? ImagePicker();
  bool _arrived = false; // 오르기 애니메이션이 끝났는지
  bool _making = false;
  int _lastStep = 0;

  @override
  void initState() {
    super.initState();
    _climb.addListener(_onClimbTick);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startClimb());
  }

  @override
  void dispose() {
    _climb.dispose();
    _loop.dispose();
    super.dispose();
  }

  TaskStore get _store => KeepyScope.of(context).tasks;
  DayStat _stat() => _store.monthStat(_store.today);

  /// 이번 달 할 일 중 오늘 끝낸 것 (오늘 오른 칸).
  int _doneToday() {
    final store = _store;
    final today = store.today;
    bool inMonth(DateTime d) => d.year == today.year && d.month == today.month;
    return store.tasks
        .where((t) =>
            t.done &&
            t.completedAt != null &&
            isSameDay(t.completedAt!, today) &&
            (t.due != null ? inMonth(t.due!) : inMonth(t.createdAt)))
        .length;
  }

  /// 0칸에서 완료한 칸까지 한 칸씩 올라간다.
  void _startClimb() {
    if (!mounted) return;
    final done = _stat().done;
    setState(() => _arrived = false);
    _lastStep = 0;
    _loop.stop();
    if (done == 0) {
      _climb.value = 0;
      _finish();
      return;
    }
    final ms = (done * 320).clamp(600, 4200);
    _climb
      ..duration = Duration(milliseconds: ms)
      ..value = 0
      ..animateTo(1, curve: Curves.linear).whenComplete(_finish);
  }

  void _onClimbTick() {
    final done = _stat().done;
    final step = (_climb.value * done).floor();
    if (step != _lastStep) {
      _lastStep = step;
      HapticFeedback.selectionClick();
    }
  }

  void _finish() {
    if (!mounted) return;
    final s = _stat();
    setState(() => _arrived = true);
    if (s.total > 0 && s.done == s.total) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    _loop.repeat();
  }

  Future<void> _makeCharacter(ImageSource source) async {
    if (_making) return;
    final settings = KeepyScope.of(context).settings;
    setState(() => _making = true);
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1200, imageQuality: 90);
      if (file == null) return;
      final pixels = await const CharacterMaker().fromPicked(file);
      if (!mounted) return;
      if (pixels == null || pixels.every((p) => p == 0)) {
        _alert('사람을 찾지 못했어요', '얼굴이나 상반신이 잘 보이는 사진으로 다시 해 주세요.');
        return;
      }
      settings.update((s) => s.copyWith(characterPixels: pixels, characterStyle: CharacterStyle.photo));
      _startClimb();
    } on PlatformException catch (e) {
      if (mounted) _alert('사진을 열지 못했어요', e.message ?? e.code);
    } catch (e) {
      if (mounted) _alert('캐릭터를 만들지 못했어요', '$e');
    } finally {
      if (mounted) setState(() => _making = false);
    }
  }

  void _alert(String title, String message) {
    showCupertinoDialog<void>(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))],
      ),
    );
  }

  /// 사진 고르기 (찍기 / 앨범).
  void _photoMenu() {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('내 사진으로 캐릭터 만들기'),
        message: const Text('사진 속 사람만 기기 안에서 오려 내 픽셀 캐릭터로 바꿔요.\n사진은 저장되지 않아요.'),
        actions: <Widget>[
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _makeCharacter(ImageSource.camera);
            },
            child: const Text('사진 찍기'),
          ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.pop(ctx);
              _makeCharacter(ImageSource.gallery);
            },
            child: const Text('앨범에서 고르기'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
      ),
    );
  }

  /// 꾸미기: 캐릭터(남자/여자/내 사진) + 펫(없음/강아지/고양이/토끼).
  void _customize() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: const Color(0x52000000),
      // 기본 시트는 화면 높이의 9/16 까지만 커져서 '완료' 버튼이 잘렸다 (BOTTOM OVERFLOWED).
      // 내용만큼 커지게 하고, 화면이 낮으면 시트 안에서 스크롤한다.
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CustomizeSheet(
        onPhoto: () {
          Navigator.pop(context);
          _photoMenu();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = KeepyScope.of(context);
    final dark = KeepyPalette.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: KeepyColors.background,
        body: ListenableBuilder(
          listenable: Listenable.merge(<Listenable>[scope.tasks, scope.settings]),
          builder: (context, _) {
            final store = scope.tasks;
            final settings = scope.settings.settings;
            final stat = store.monthStat(store.today);
            final sprite = characterSpriteOf(settings);
            final pet = petSpriteOf(settings.pet);
            final complete = stat.total > 0 && stat.done == stat.total;
            final rate = stat.total == 0 ? 0.0 : stat.done / stat.total;
            final percent = (rate * 100).round();
            final month = store.today.month;
            final today = _doneToday();

            return Container(
              decoration: BoxDecoration(gradient: KeepyGradients.sky),
              child: SafeArea(
                child: Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text('미니게임', style: KeepyText.footnote),
                                const SizedBox(height: 2),
                                Text('$month월 계단 오르기', style: KeepyText.title),
                                const SizedBox(height: 6),
                                Row(
                                  children: <Widget>[
                                    Text(
                                      '${stat.done} / ${stat.total}칸 · $percent%',
                                      style: KeepyText.caption.copyWith(color: KeepyColors.blue, fontWeight: FontWeight.w800),
                                    ),
                                    if (today > 0) ...<Widget>[
                                      const SizedBox(width: 8),
                                      Pill('오늘 +$today칸', background: KeepyColors.skyTint),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),
                                // 진행 막대
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: SizedBox(
                                    height: 6,
                                    child: Stack(
                                      children: <Widget>[
                                        Container(color: KeepyColors.card.withValues(alpha: dark ? 0.25 : 0.7)),
                                        FractionallySizedBox(
                                          widthFactor: rate.clamp(0.0, 1.0),
                                          child: Container(
                                            decoration: const BoxDecoration(gradient: KeepyGradients.primary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            key: const Key('game-close'),
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(CupertinoIcons.xmark, color: KeepyColors.label, size: 24),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                        child: AnimatedBuilder(
                          animation: Listenable.merge(<Listenable>[_climb, _loop]),
                          builder: (context, _) => CustomPaint(
                            size: Size.infinite,
                            painter: StairPainter(
                              total: stat.total,
                              position: _arrived ? stat.done.toDouble() : _climb.value * stat.done,
                              sprite: sprite,
                              pet: pet,
                              mood: !_arrived
                                  ? StairMood.climbing
                                  : complete
                                      ? StairMood.summit
                                      : StairMood.cheer,
                              loop: _loop.value,
                              night: dark,
                            ),
                          ),
                        ),
                      ),
                    ),
                    _MessageCard(stat: stat, arrived: _arrived, complete: complete, month: month, petName: settings.pet),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: GradientButton(
                              label: _making ? '캐릭터 만드는 중…' : '꾸미기 · 캐릭터와 펫',
                              onPressed: _making ? null : _customize,
                            ),
                          ),
                          const SizedBox(width: 10),
                          PressScale(
                            onTap: _startClimb,
                            child: Container(
                              key: const Key('game-replay'),
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: KeepyColors.card,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(CupertinoIcons.arrow_counterclockwise, color: KeepyColors.blue, size: 21),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 꾸미기 시트 (v0.4): 캐릭터와 펫을 미리 보며 고른다.
class _CustomizeSheet extends StatelessWidget {
  const _CustomizeSheet({required this.onPhoto});
  final VoidCallback onPhoto;

  @override
  Widget build(BuildContext context) {
    final store = KeepyScope.of(context).settings;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.settings;
        final style = s.effectiveCharacterStyle;
        final hasPhoto = s.characterPixels != null;
        return Container(
          decoration: BoxDecoration(
            color: KeepyColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(color: KeepyColors.tertiaryLabel, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('꾸미기', style: KeepyText.title),
                  const SizedBox(height: 14),
                  Text('캐릭터', style: KeepyText.caption),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      _Choice(
                        key: const Key('char-boy'),
                        label: '남자',
                        sprite: boySprite(),
                        selected: style == CharacterStyle.boy,
                        onTap: () => store.update((c) => c.copyWith(characterStyle: CharacterStyle.boy)),
                      ),
                      _Choice(
                        key: const Key('char-girl'),
                        label: '여자',
                        sprite: girlSprite(),
                        selected: style == CharacterStyle.girl,
                        onTap: () => store.update((c) => c.copyWith(characterStyle: CharacterStyle.girl)),
                      ),
                      _Choice(
                        key: const Key('char-photo'),
                        label: hasPhoto ? '내 사진' : '사진으로\n만들기',
                        sprite: hasPhoto ? PixelSprite(AppSettings.characterSize, s.characterPixels!) : null,
                        icon: CupertinoIcons.camera,
                        selected: style == CharacterStyle.photo,
                        onTap: hasPhoto
                            ? () => store.update((c) => c.copyWith(characterStyle: CharacterStyle.photo))
                            : onPhoto,
                      ),
                    ],
                  ),
                  if (hasPhoto)
                    Align(
                      alignment: Alignment.centerRight,
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        onPressed: onPhoto,
                        child: const Text('사진 다시 찍기', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  const SizedBox(height: 10),
                  Text('함께 오를 펫', style: KeepyText.caption),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      for (final p in PetKind.values)
                        _Choice(
                          key: Key('pet-${p.name}'),
                          label: p.label,
                          sprite: petSpriteOf(p),
                          icon: CupertinoIcons.nosign,
                          compact: true,
                          selected: s.pet == p,
                          onTap: () => store.update((c) => c.copyWith(pet: p)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  GradientButton(label: '완료', onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    super.key,
    required this.label,
    required this.sprite,
    required this.selected,
    required this.onTap,
    this.icon,
    this.compact = false,
  });

  final String label;
  final PixelSprite? sprite;
  final IconData? icon;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final box = compact ? 40.0 : 52.0;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: PressScale(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: KeepyMotion.fast,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? KeepyColors.skyTint : KeepyColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: selected ? KeepyColors.blue : KeepyColors.separator, width: selected ? 1.6 : 1),
            ),
            child: Column(
              children: <Widget>[
                SizedBox(
                  width: box,
                  height: box,
                  child: sprite == null
                      ? Icon(icon, color: KeepyColors.secondaryLabel, size: box * 0.5)
                      : SpriteView(sprite: sprite!),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                    color: selected ? KeepyColors.blue : KeepyColors.label,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 스프라이트를 그대로 그리는 작은 위젯 (꾸미기 미리보기).
class SpriteView extends StatelessWidget {
  const SpriteView({super.key, required this.sprite});
  final PixelSprite sprite;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _SpritePainter(sprite));
}

class _SpritePainter extends CustomPainter {
  _SpritePainter(this.sprite);
  final PixelSprite sprite;

  @override
  void paint(Canvas canvas, Size size) {
    final px = math.min(size.width, size.height) / sprite.size;
    final paint = Paint();
    for (var y = 0; y < sprite.size; y++) {
      for (var x = 0; x < sprite.size; x++) {
        final c = sprite.at(x, y);
        if (c == 0) continue;
        paint.color = Color(c);
        canvas.drawRect(Rect.fromLTWH(x * px, y * px, px + 0.4, px + 0.4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_SpritePainter old) => !identical(old.sprite.pixels, sprite.pixels);
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.stat,
    required this.arrived,
    required this.complete,
    required this.month,
    required this.petName,
  });
  final DayStat stat;
  final bool arrived;
  final bool complete;
  final int month;
  final PetKind petName;

  static String encouragement(DayStat s) {
    final left = s.total - s.done;
    final rate = s.total == 0 ? 0.0 : s.done / s.total;
    if (s.total == 0) return '이번 달 할 일을 추가하면 계단이 생겨요';
    if (s.done == 0) return '첫 계단이 기다리고 있어요. 가장 쉬운 일부터 시작해요!';
    if (rate >= 0.8) return '거의 다 왔어요! $left칸만 더 오르면 정상이에요';
    if (rate >= 0.5) return '절반 넘게 올라왔어요. 이 페이스 그대로 가 봐요!';
    return '한 칸씩 잘 오르고 있어요. 오늘 하나만 더 해 볼까요?';
  }

  @override
  Widget build(BuildContext context) {
    final String title;
    final String body;
    final withPet = petName == PetKind.none ? '' : ' ${petName.label}도 신났어요!';
    if (!arrived) {
      title = '올라가는 중…';
      body = '이번 달에 끝낸 할 일만큼 올라가요';
    } else if (complete) {
      title = '정상 도착! 🎉';
      body = '$month월 할 일 ${stat.total}개를 모두 끝냈어요. 정말 멋져요!$withPet';
    } else {
      title = stat.total == 0 ? '아직 계단이 없어요' : '${stat.total - stat.done}칸 남았어요';
      body = encouragement(stat);
    }
    return AnimatedSwitcher(
      duration: KeepyMotion.normal,
      child: Container(
        key: ValueKey<String>(title),
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        width: double.infinity,
        decoration: BoxDecoration(
          color: KeepyColors.card.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            complete && arrived
                ? GradientText(title, style: KeepyText.headline)
                : Text(title, style: KeepyText.headline),
            const SizedBox(height: 3),
            Text(body, style: KeepyText.caption.copyWith(height: 1.4)),
          ],
        ),
      ),
    );
  }
}

enum StairMood { climbing, summit, cheer }

/// 계단·캐릭터·펫·깃발·폭죽을 한 번에 그린다.
class StairPainter extends CustomPainter {
  StairPainter({
    required this.total,
    required this.position,
    required this.sprite,
    required this.mood,
    required this.loop,
    this.pet,
    this.night = false,
  });

  /// 계단 수 (= 이번 달 할 일 수).
  final int total;

  /// 캐릭터 위치 (0 = 땅, total = 정상). 소수는 오르는 중.
  final double position;
  final PixelSprite sprite;
  final PixelSprite? pet;
  final StairMood mood;
  final bool night;

  /// 0~1 반복 값 (모션용).
  final double loop;

  static const _stepDone = Color(0xFF2F7BFF);
  static const _stepDoneTop = Color(0xFF4CC3FF);
  static const _outline = Color(0xFF1A2433);

  Color get _ground => night ? const Color(0xFF1B2E4A) : const Color(0xFFCFE8FF);
  Color get _stepTodo => night ? const Color(0xFF223652) : const Color(0xFFFFFFFF);
  Color get _stepLine => night ? const Color(0xFF34507A) : const Color(0xFFBFD6EE);

  /// 칸 최소 폭 (v0.5). 할 일이 많아도 칸이 이보다 좁아지지 않고, 대신 화면이 캐릭터를 따라간다.
  static const minStepWithPet = 72.0;
  static const minStepAlone = 54.0;

  @override
  void paint(Canvas canvas, Size size) {
    final n = math.max(total, 1);
    final hasPet = pet != null;
    const marginX = 12.0;
    const flagRoom = 28.0; // 정상 깃발이 오른쪽으로 펄럭일 자리
    const topRoom = 92.0; // 정상 위 캐릭터·깃발 자리
    final groundY = size.height - 18;
    // 칸 폭: 화면에 다 들어가면 그대로, 좁아지면 최소 폭을 지키고 카메라로 따라간다.
    final stepW = math.max((size.width - marginX * 2 - flagRoom) / (n + 1), hasPet ? minStepWithPet : minStepAlone);
    final stepH = ((groundY - topRoom) / n).clamp(30.0, 46.0).toDouble();
    double xOf(int k) => marginX + k * stepW; // k번째 칸 왼쪽
    double topOf(int k) => groundY - k * stepH; // k번째 칸 윗면 (0 = 땅)
    double centerX(int k) => xOf(k) + stepW / 2;

    // 지금 서 있는 위치 (칸 사이를 깡충 이동 중이면 그 사이)
    final base = position.floor().clamp(0, n);
    final frac = (position - base).clamp(0.0, 1.0).toDouble();
    final next = math.min(base + 1, n);
    final stepX = centerX(base) + (centerX(next) - centerX(base)) * frac;
    final floorY = topOf(base) + (topOf(next) - topOf(base)) * frac;

    // 카메라: 계단 전체가 화면보다 크면 캐릭터를 화면 가운데쯤에 두고 따라간다.
    final worldW = marginX * 2 + flagRoom + (n + 1) * stepW;
    final camX = (stepX - size.width * 0.45).clamp(0.0, math.max(0.0, worldW - size.width)).toDouble();
    final camY = (size.height * 0.62 - floorY).clamp(0.0, math.max(0.0, topRoom - topOf(n))).toDouble();

    if (night) {
      // 밤하늘: 반짝이는 별
      final rnd = math.Random(3);
      for (var i = 0; i < 26; i++) {
        final x = rnd.nextDouble() * size.width;
        final y = rnd.nextDouble() * size.height * 0.45;
        final tw = 0.45 + 0.55 * (0.5 + 0.5 * math.sin((loop + i * 0.37) * math.pi * 2));
        canvas.drawCircle(Offset(x, y), 1.1 + rnd.nextDouble(), Paint()..color = Colors.white.withValues(alpha: tw * 0.8));
      }
      canvas.drawCircle(Offset(size.width * 0.82, 30), 13, Paint()..color = const Color(0xFFFFF1B8));
      canvas.drawCircle(Offset(size.width * 0.82 + 6, 26), 11, Paint()..color = const Color(0xFF0F2140));
    } else {
      // 구름 두 개
      final cloud = Paint()..color = Colors.white.withValues(alpha: 0.75);
      for (final (cx, cy, r) in <(double, double, double)>[(size.width * 0.18, 34, 16), (size.width * 0.72, 18, 12)]) {
        canvas.drawCircle(Offset(cx, cy), r, cloud);
        canvas.drawCircle(Offset(cx + r, cy + 4), r * 0.8, cloud);
        canvas.drawCircle(Offset(cx - r, cy + 5), r * 0.7, cloud);
      }
    }

    canvas.save();
    canvas.translate(-camX, camY);

    // 땅 (카메라가 움직여도 화면 폭 전체를 덮는다)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(camX - 20, groundY, size.width + 40, size.height + camY + 20), const Radius.circular(10)),
      Paint()..color = _ground,
    );

    // 계단 (k = 1..total). 오른 칸은 파랑, 남은 칸은 흰색(밤: 남색).
    if (total > 0) {
      for (var k = 1; k <= total; k++) {
        final rect = Rect.fromLTRB(xOf(k), topOf(k), xOf(k) + stepW + 0.5, groundY);
        if (rect.right < camX - 2 || rect.left > camX + size.width + 2) continue; // 화면 밖은 건너뜀
        final climbed = k <= position.floor();
        final paint = Paint();
        if (climbed) {
          paint.shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[_stepDoneTop, _stepDone],
          ).createShader(rect);
        } else {
          paint.color = _stepTodo;
        }
        canvas.drawRect(rect, paint);
        canvas.drawLine(
          Offset(rect.left, rect.top),
          Offset(rect.right, rect.top),
          Paint()
            ..color = climbed ? Colors.white.withValues(alpha: 0.7) : _stepLine
            ..strokeWidth = 2,
        );
      }
    }

    // ---- 캐릭터와 펫 크기: 둘이 한 칸 위에 겹치지 않고 들어가는 크기 (v0.5)
    final double cs = hasPet ? (stepW * 0.64).clamp(30.0, 50.0).toDouble() : (stepW * 0.88).clamp(32.0, 56.0).toDouble();
    final ps = cs * 0.72; // 펫 크기

    // 정상 깃발: 칸 오른쪽 끝, 바깥(오른쪽)으로 펄럭여 캐릭터 머리와 겹치지 않는다
    if (total > 0) {
      final fx = xOf(total) + stepW - 1;
      final fy = topOf(total);
      final poleH = cs + 18;
      canvas.drawLine(Offset(fx, fy), Offset(fx, fy - poleH), Paint()
        ..color = night ? Colors.white : _outline
        ..strokeWidth = 2);
      final wave = math.sin(loop * math.pi * 2) * 3;
      final flag = Path()
        ..moveTo(fx, fy - poleH)
        ..lineTo(fx + 22, fy - poleH + 6 + wave)
        ..lineTo(fx, fy - poleH + 13);
      canvas.drawPath(flag, Paint()..color = mood == StairMood.summit ? const Color(0xFFFF5D73) : const Color(0xFF4CC3FF));
    }

    // ---- 나란히 세우기: 보이는 폭 기준으로 [펫][간격][캐릭터] 를 칸 가운데에 (v0.5)
    final charSpan = sprite.visibleSpan(cs);
    final petSpan = hasPet ? pet!.visibleSpan(ps) : (width: 0.0, offset: 0.0);
    final gap = hasPet ? math.max(4.0, cs * 0.14) : 0.0; // 팔(만세)이 펫에 닿지 않을 만큼
    final pairW = petSpan.width + gap + charSpan.width;
    // 칸에 여유가 있으면 살짝 왼쪽으로 — 정상에서 만세 팔이 깃대에 닿지 않게
    final pairLeft = stepX - pairW / 2 - math.min(8.0, math.max(0.0, (stepW - pairW) / 2 - 2));
    final x = pairLeft + petSpan.width + gap + charSpan.width / 2 - charSpan.offset;
    final petX = pairLeft + petSpan.width / 2 - petSpan.offset;

    final hop = math.sin(frac * math.pi);
    var bottom = floorY - hop * cs * 0.35;
    var tilt = 0.0;
    var armsUp = false;
    var armWave = 0.0;
    var petLift = hop * ps * 0.45;
    var petTilt = 0.0;
    switch (mood) {
      case StairMood.climbing:
        break;
      case StairMood.summit:
        // 만세 점프 — 펫은 반 박자 엇갈려 함께 뛴다
        bottom -= (math.sin(loop * math.pi * 4)).abs() * cs * 0.45;
        armsUp = true;
        tilt = math.sin(loop * math.pi * 4) * 0.08;
        petLift += (math.sin((loop + 0.12) * math.pi * 4)).abs() * ps * 0.6;
      case StairMood.cheer:
        // 제자리 응원: 살짝 들썩 + 한 손 흔들기, 펫은 꼬리 흔들듯 들썩
        bottom -= (math.sin(loop * math.pi * 2)).abs() * cs * 0.12;
        armWave = math.sin(loop * math.pi * 4);
        petLift += (math.sin((loop + 0.5) * math.pi * 4)).abs() * ps * 0.15;
        petTilt = math.sin(loop * math.pi * 4) * 0.12;
    }
    final shadow = Paint()..color = const Color(0x221A2433);

    if (hasPet) {
      canvas.drawOval(Rect.fromCenter(center: Offset(petX + petSpan.offset, floorY + 2), width: petSpan.width * 0.8, height: 4), shadow);
      canvas.save();
      canvas.translate(petX, floorY - petLift);
      canvas.rotate(petTilt);
      _drawSprite(canvas, pet!, ps);
      canvas.restore();
    }

    canvas.drawOval(Rect.fromCenter(center: Offset(x + charSpan.offset, floorY + 2), width: charSpan.width * 0.8, height: 5), shadow);
    canvas.save();
    canvas.translate(x, bottom);
    canvas.rotate(tilt);
    _drawArms(canvas, cs, armsUp: armsUp, armWave: armWave);
    _drawSprite(canvas, sprite, cs);
    canvas.restore();

    canvas.restore(); // 카메라

    if (mood == StairMood.summit) _drawConfetti(canvas, size);
  }

  /// (0,0) = 발 아래 가운데.
  void _drawSprite(Canvas canvas, PixelSprite s, double size) {
    final px = size / s.size;
    final left = -size / 2;
    final top = -size;
    final paint = Paint();
    for (var y = 0; y < s.size; y++) {
      for (var xx = 0; xx < s.size; xx++) {
        final c = s.at(xx, y);
        if (c == 0) continue;
        paint.color = Color(c);
        // 0.5px 겹쳐 그려 칸 사이 틈을 없앤다
        canvas.drawRect(Rect.fromLTWH(left + xx * px, top + y * px, px + 0.5, px + 0.5), paint);
      }
    }
  }

  void _drawArms(Canvas canvas, double cs, {required bool armsUp, required double armWave}) {
    final px = cs / sprite.size;
    // 팔은 그림 여백이 아니라 몸이 보이는 가장자리에 붙인다 (v0.5)
    final cols = sprite.visibleColumns;
    final left = (cols.min - sprite.size / 2) * px;
    final right = (cols.max + 1 - sprite.size / 2) * px;
    final top = -cs;
    final arm = Paint()..color = night ? Colors.white : _outline;
    final armW = math.max(2.0, px * 1.6);
    if (armsUp) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(left - armW, top - cs * 0.15, armW, cs * 0.55), Radius.circular(armW)), arm);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(right, top - cs * 0.15, armW, cs * 0.55), Radius.circular(armW)), arm);
    } else if (armWave != 0) {
      canvas.save();
      canvas.translate(right + armW / 2, top + cs * 0.55);
      canvas.rotate(-0.9 + armWave * 0.5);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-armW / 2, -cs * 0.4, armW, cs * 0.4), Radius.circular(armW)), arm);
      canvas.restore();
    }
  }

  void _drawConfetti(Canvas canvas, Size size) {
    const colors = <Color>[Color(0xFF4CC3FF), Color(0xFF2F7BFF), Color(0xFFFFC94D), Color(0xFFFF6B8A), Color(0xFF3FD48C)];
    final rnd = math.Random(7);
    for (var i = 0; i < 42; i++) {
      final speed = 0.6 + rnd.nextDouble() * 0.8;
      final x = rnd.nextDouble() * size.width + math.sin((loop * speed + i) * math.pi * 2) * 10;
      final y = ((rnd.nextDouble() + loop * speed) % 1.0) * size.height * 0.85;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate((loop * 6 + i) % (math.pi * 2));
      canvas.drawRect(const Rect.fromLTWH(-3, -1.5, 6, 3), Paint()..color = colors[i % colors.length]);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(StairPainter old) =>
      old.total != total ||
      old.position != position ||
      old.mood != mood ||
      old.loop != loop ||
      old.night != night ||
      !identical(old.sprite.pixels, sprite.pixels) ||
      !identical(old.pet?.pixels, pet?.pixels);
}

/// 작은 계단 아이콘 (메인 화면 미니게임 바로가기, 설정).
class StairsIcon extends StatelessWidget {
  const StairsIcon({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _StairsIconPainter());
}

class _StairsIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;
    final paint = Paint()..shader = KeepyGradients.primary.createShader(rect);
    final path = Path()
      ..moveTo(0, s)
      ..lineTo(0, s * 0.72)
      ..lineTo(s * 0.33, s * 0.72)
      ..lineTo(s * 0.33, s * 0.46)
      ..lineTo(s * 0.66, s * 0.46)
      ..lineTo(s * 0.66, s * 0.2)
      ..lineTo(s, s * 0.2)
      ..lineTo(s, s)
      ..close();
    canvas.drawPath(path, paint);
    // 깃발
    final pole = Paint()
      ..color = KeepyColors.label
      ..strokeWidth = s * 0.07;
    canvas.drawLine(Offset(s * 0.86, s * 0.2), Offset(s * 0.86, 0), pole);
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.86, 0)
        ..lineTo(s * 0.62, s * 0.08)
        ..lineTo(s * 0.86, s * 0.15),
      Paint()..color = const Color(0xFFFF6B8A),
    );
  }

  @override
  bool shouldRepaint(_StairsIconPainter oldDelegate) => false;
}
