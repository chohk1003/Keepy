import 'dart:math' as math;
import 'dart:typed_data';

/// 픽셀 캐릭터 한 장: 정사각형 [size]×[size], 각 칸은 ARGB (0 = 투명).
class PixelSprite {
  const PixelSprite(this.size, this.pixels);

  final int size;
  final List<int> pixels;

  int at(int x, int y) => pixels[y * size + x];

  /// 실제로 보이는(투명 아닌) 칸이 차지하는 가로 범위 (v0.5).
  /// 캐릭터와 펫을 겹치지 않게 나란히 세울 때, 그림 여백이 아니라 눈에 보이는 폭으로 간격을 잰다.
  ({int min, int max}) get visibleColumns {
    var lo = size, hi = -1;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (pixels[y * size + x] == 0) continue;
        if (x < lo) lo = x;
        if (x > hi) hi = x;
      }
    }
    return hi < 0 ? (min: 0, max: size - 1) : (min: lo, max: hi);
  }

  /// [drawSize] 로 그렸을 때 보이는 폭, 그리고 보이는 부분의 가운데가 그림 가운데에서 얼마나 벗어나는지.
  ({double width, double offset}) visibleSpan(double drawSize) {
    final c = visibleColumns;
    final px = drawSize / size;
    return (width: (c.max - c.min + 1) * px, offset: ((c.min + c.max + 1) / 2 - size / 2) * px);
  }
}

/// 문자 지도 → 스프라이트. '.' 은 투명.
PixelSprite spriteFromMap(List<String> map, Map<String, int> palette) {
  final size = map.length;
  assert(map.every((r) => r.length == size), '정사각형이어야 합니다');
  return PixelSprite(size, <int>[
    for (final row in map)
      for (final ch in row.split('')) palette[ch] ?? 0,
  ]);
}

// v0.5: 더 둥글고 귀엽게 — 큰 머리, 눈 반짝임, 볼터치, 부드러운 남색 외곽선.

/// 남자 캐릭터 — 하늘색 둥근 모자, 큰 머리·볼터치의 둥글둥글한 비율 (v0.5).
PixelSprite boySprite() => spriteFromMap(const <String>[
      '................',
      '.....OOOOOO.....',
      '...OOBBBBBBOO...',
      '..OBBBBBBBBBBO..',
      '.OBBBLBBBBBBBBO.',
      '.OOOOOOOOOOOOOO.',
      '.OSSSSSSSSSSSSO.',
      '.OSSEESSSSEESSO.',
      '.OSSEWSSSSEWSSO.',
      '.OSPPSSMMSSPPSO.',
      '..OSSSSSSSSSSO..',
      '...OOSSSSSSOO...',
      '...OTTTTTTTTO...',
      '..OSTTTWWTTTSO..',
      '...OTTTTTTTTO...',
      '....ODDO.ODDO...',
    ], const <String, int>{'O': 0xFF2E3A55, 'B': 0xFF55B8FF, 'L': 0xFFBFE6FF, 'S': 0xFFFFE0CC, 'E': 0xFF2B2B3A, 'W': 0xFFFFFFFF, 'P': 0xFFFF9FB2, 'M': 0xFFE5607A, 'T': 0xFF7CC8FF, 'D': 0xFF5A6B8C});

/// 여자 캐릭터 — 갈색 단발 + 분홍 리본·원피스 (v0.5).
PixelSprite girlSprite() => spriteFromMap(const <String>[
      '..........ORRO..',
      '.....OOOOOORRO..',
      '...OOHHHHHHOO...',
      '..OHHHHHHHHHHO..',
      '.OHHHLHHHHHHHHO.',
      '.OHHSSHHHHSSHHO.',
      '.OHSSSSSSSSSSHO.',
      '.OHSEESSSSEESHO.',
      '.OHSEWSSSSEWSHO.',
      '.OHPPSSMMSSPPHO.',
      '.OHHSSSSSSSSHHO.',
      '.OHOOSSSSSSOOHO.',
      '..OOTTTTTTTTOO..',
      '..OSTTTTTTTTSO..',
      '.OTTTTTTTTTTTTO.',
      '...OODDOODDOO...',
    ], const <String, int>{'O': 0xFF2E3A55, 'H': 0xFF8A5A44, 'L': 0xFFB98468, 'R': 0xFFFF7FA8, 'S': 0xFFFFE0CC, 'E': 0xFF2B2B3A, 'W': 0xFFFFFFFF, 'P': 0xFFFF9FB2, 'M': 0xFFE5607A, 'T': 0xFFFFB3CF, 'D': 0xFF5A6B8C});

/// 예전 이름 호환.
PixelSprite defaultSprite() => boySprite();

/// 펫 (12×12).
/// 강아지 — 늘어진 귀, 혀 내밀기 (v0.5).
PixelSprite dogSprite() => spriteFromMap(const <String>[
      '............',
      '...OOOOOO...',
      '.OOTTTTTTOO.',
      'OEOTTTTTTOEO',
      'OEOTKTTKTOEO',
      'OEOTTNNTTOEO',
      '.OOPTTTTPOO.',
      '..OTTMMTTO..',
      '..OOTTTTOO..',
      '.OTTTTTTTTO.',
      '.OTTOTTOTTO.',
      '..OOO..OOO..',
    ], const <String, int>{'O': 0xFF2E3A55, 'T': 0xFFF2C38B, 'E': 0xFFB97A4A, 'K': 0xFF2B2B3A, 'N': 0xFF2B2B3A, 'P': 0xFFFFA3B5, 'M': 0xFFFF7F96});

/// 고양이 — 뾰족 귀, 치즈색 (v0.5).
PixelSprite catSprite() => spriteFromMap(const <String>[
      '.O........O.',
      '.OO......OO.',
      '.OGO....OGO.',
      '.OGGOOOOGGO.',
      'OGGGGGGGGGGO',
      'OGGKGGGGKGGO',
      'OGPGGNNGGPGO',
      '.OGGGMMGGGO.',
      '..OOGGGGOO..',
      '.OGGGGGGGGOO',
      '.OGGOGGOGGOG',
      '..OOO..OOO..',
    ], const <String, int>{'O': 0xFF2E3A55, 'G': 0xFFFFC27A, 'K': 0xFF2B2B3A, 'N': 0xFFFF8FA3, 'P': 0xFFFFB0A0, 'M': 0xFFE5607A});

/// 토끼 — 긴 귀, 분홍 코 (v0.5).
PixelSprite rabbitSprite() => spriteFromMap(const <String>[
      '..OO....OO..',
      '.OWPO..OPWO.',
      '.OWPO..OPWO.',
      '.OWWOOOOWWO.',
      'OWWWWWWWWWWO',
      'OWWKWWWWKWWO',
      'OWPWWNNWWPWO',
      '.OWWWMMWWWO.',
      '..OOWWWWOO..',
      '.OWWWWWWWWO.',
      '.OWWOWWOWWO.',
      '..OOO..OOO..',
    ], const <String, int>{'O': 0xFF2E3A55, 'W': 0xFFFFFFFF, 'P': 0xFFFFB3C6, 'K': 0xFF2B2B3A, 'N': 0xFFFF8FA3, 'M': 0xFFFFB3C6});

/// 사진 → 픽셀 캐릭터.
///
/// [rgba]: 가로 [width] × 세로 [height] 의 RGBA 바이트.
/// [mask]: 같은 크기의 '사람일 확률' (0~1). 온디바이스 AI(ML Kit Selfie Segmentation)가
///   만든 값이며, 없으면 사진 테두리 색을 배경으로 보고 비슷한 색을 지운다.
///
/// 순서: 사람 영역 정사각형으로 자르기 → [size]×[size] 로 평균 축소 →
/// 색을 [colors]개로 줄이기(k-평균) → 채도·대비 살짝 올리기 → 1칸 외곽선.
List<int> pixelate({
  required int width,
  required int height,
  required Uint8List rgba,
  List<double>? mask,
  int size = 24,
  int colors = 10,
}) {
  assert(rgba.length >= width * height * 4);

  double alphaAt(int x, int y) => mask == null ? 1 : mask[y * width + x];

  // 1) 자를 영역: 마스크가 있으면 사람이 있는 상자, 없으면 가운데 정사각형
  var minX = 0, minY = 0, maxX = width - 1, maxY = height - 1;
  if (mask != null) {
    var found = false;
    var bx0 = width, by0 = height, bx1 = 0, by1 = 0;
    for (var y = 0; y < height; y += 2) {
      for (var x = 0; x < width; x += 2) {
        if (alphaAt(x, y) > 0.5) {
          found = true;
          bx0 = math.min(bx0, x);
          by0 = math.min(by0, y);
          bx1 = math.max(bx1, x);
          by1 = math.max(by1, y);
        }
      }
    }
    if (found) {
      minX = bx0;
      minY = by0;
      maxX = bx1;
      maxY = by1;
    }
  }
  final boxW = maxX - minX + 1, boxH = maxY - minY + 1;
  final side = math.min(math.max(boxW, boxH) * (mask == null ? 1.0 : 1.08), math.min(width, height).toDouble());
  final cx = minX + boxW / 2, cy = minY + boxH / 2;
  final left = (cx - side / 2).clamp(0.0, width - side);
  final top = (cy - side / 2).clamp(0.0, height - side);

  // 마스크가 없을 때: 자른 영역 테두리 평균색 = 배경
  List<int>? bg;
  if (mask == null) {
    var r = 0, g = 0, b = 0, n = 0;
    final step = math.max(1, side ~/ 40);
    for (var i = 0; i < side; i += step) {
      for (final (x, y) in <(int, int)>[
        ((left + i).toInt(), top.toInt()),
        ((left + i).toInt(), (top + side - 1).toInt()),
        (left.toInt(), (top + i).toInt()),
        ((left + side - 1).toInt(), (top + i).toInt()),
      ]) {
        final o = (y.clamp(0, height - 1) * width + x.clamp(0, width - 1)) * 4;
        r += rgba[o];
        g += rgba[o + 1];
        b += rgba[o + 2];
        n++;
      }
    }
    bg = <int>[r ~/ n, g ~/ n, b ~/ n];
  }

  // 2) 칸마다 평균 (블록 안을 듬성듬성 표본 추출)
  final cell = side / size;
  final sampleStep = math.max(1, (cell / 5).floor());
  final cr = List<double>.filled(size * size, 0);
  final cg = List<double>.filled(size * size, 0);
  final cb = List<double>.filled(size * size, 0);
  final opaque = List<bool>.filled(size * size, false);
  for (var j = 0; j < size; j++) {
    for (var i = 0; i < size; i++) {
      var r = 0.0, g = 0.0, b = 0.0, a = 0.0, n = 0;
      final x0 = (left + i * cell).floor(), y0 = (top + j * cell).floor();
      final x1 = math.min(width, (left + (i + 1) * cell).ceil());
      final y1 = math.min(height, (top + (j + 1) * cell).ceil());
      for (var y = y0; y < y1; y += sampleStep) {
        for (var x = x0; x < x1; x += sampleStep) {
          final o = (y * width + x) * 4;
          r += rgba[o];
          g += rgba[o + 1];
          b += rgba[o + 2];
          a += alphaAt(x, y);
          n++;
        }
      }
      if (n == 0) continue;
      final k = j * size + i;
      cr[k] = r / n;
      cg[k] = g / n;
      cb[k] = b / n;
      var isPerson = a / n > 0.45;
      if (bg != null) {
        final d = math.sqrt(math.pow(cr[k] - bg[0], 2) + math.pow(cg[k] - bg[1], 2) + math.pow(cb[k] - bg[2], 2));
        isPerson = d > 42;
      }
      opaque[k] = isPerson;
    }
  }

  // 3) 색 줄이기 (k-평균)
  final points = <int>[for (var k = 0; k < size * size; k++) if (opaque[k]) k];
  final out = List<int>.filled(size * size, 0);
  if (points.isEmpty) return out;
  final kCount = math.min(colors, points.length);
  final sortedByLuma = List<int>.of(points)
    ..sort((a, b) => (cr[a] * 0.3 + cg[a] * 0.59 + cb[a] * 0.11).compareTo(cr[b] * 0.3 + cg[b] * 0.59 + cb[b] * 0.11));
  final centers = <List<double>>[
    for (var c = 0; c < kCount; c++)
      (() {
        final p = sortedByLuma[((c + 0.5) * sortedByLuma.length / kCount).floor().clamp(0, sortedByLuma.length - 1)];
        return <double>[cr[p], cg[p], cb[p]];
      })(),
  ];
  final assign = <int, int>{};
  for (var iter = 0; iter < 8; iter++) {
    for (final p in points) {
      var best = 0;
      var bestD = double.infinity;
      for (var c = 0; c < centers.length; c++) {
        final d = math.pow(cr[p] - centers[c][0], 2) + math.pow(cg[p] - centers[c][1], 2) + math.pow(cb[p] - centers[c][2], 2);
        if (d < bestD) {
          bestD = d.toDouble();
          best = c;
        }
      }
      assign[p] = best;
    }
    for (var c = 0; c < centers.length; c++) {
      var r = 0.0, g = 0.0, b = 0.0, n = 0;
      for (final p in points) {
        if (assign[p] != c) continue;
        r += cr[p];
        g += cg[p];
        b += cb[p];
        n++;
      }
      if (n > 0) centers[c] = <double>[r / n, g / n, b / n];
    }
  }

  // 4) 픽셀아트 느낌: 채도·대비 살짝
  int vivid(List<double> c) {
    final l = (c[0] + c[1] + c[2]) / 3;
    int ch(double v) => ((l + (v - l) * 1.25 - 128) * 1.08 + 128).round().clamp(0, 255);
    return 0xFF000000 | (ch(c[0]) << 16) | (ch(c[1]) << 8) | ch(c[2]);
  }

  for (final p in points) {
    out[p] = vivid(centers[assign[p]!]);
  }

  // 5) 외곽선: 투명 칸 중 사람 칸과 맞닿은 곳
  const outline = 0xFF1A2433;
  final withOutline = List<int>.of(out);
  for (var j = 0; j < size; j++) {
    for (var i = 0; i < size; i++) {
      final k = j * size + i;
      if (out[k] != 0) continue;
      final touches = (i > 0 && out[k - 1] != 0) ||
          (i < size - 1 && out[k + 1] != 0) ||
          (j > 0 && out[k - size] != 0) ||
          (j < size - 1 && out[k + size] != 0);
      if (touches) withOutline[k] = outline;
    }
  }
  return withOutline;
}
