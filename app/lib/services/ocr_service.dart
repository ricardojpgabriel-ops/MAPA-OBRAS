import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../data/game_config.dart';
import '../engine/prize_engine.dart';

/// Resultado da leitura de um talão (pode ter várias apostas).
class TicketScan {
  String? game;
  String? date; // ISO yyyy-MM-dd
  List<Bet> bets;
  TicketScan({this.game, this.date, List<Bet>? bets}) : bets = bets ?? [];
}

final _dateRe = RegExp(r'(\d{2})[\/\-.](\d{2})[\/\-.](\d{4})');

/// OCR on-device com o Google ML Kit + heurística de leitura do talão.
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  void dispose() => _recognizer.close();

  /// Lê a imagem e devolve o talão interpretado (jogo, data e TODAS as apostas).
  Future<TicketScan> scanImage(String imagePath, {String fallbackGame = 'euromilhoes'}) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);
    final scan = parse(result.text, fallbackGame: fallbackGame);
    final dr = _topRightDate(result);
    if (dr != null) scan.date = dr;
    return scan;
  }

  Future<String> readText(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);
    return result.text;
  }

  /// Data mais "canto superior direito" (usa a posição de cada bloco).
  String? _topRightDate(RecognizedText result) {
    double minX = double.infinity, minY = double.infinity, maxX = 0, maxY = 0;
    for (final b in result.blocks) {
      final r = b.boundingBox;
      minX = min(minX, r.left); minY = min(minY, r.top);
      maxX = max(maxX, r.right); maxY = max(maxY, r.bottom);
    }
    final spanX = (maxX - minX).abs() < 1 ? 1 : (maxX - minX);
    final spanY = (maxY - minY).abs() < 1 ? 1 : (maxY - minY);
    String? best;
    double bestScore = -1;
    for (final b in result.blocks) {
      final m = _dateRe.firstMatch(b.text);
      if (m == null) continue;
      final r = b.boundingBox;
      final xN = (r.center.dx - minX) / spanX;
      final yN = (r.center.dy - minY) / spanY;
      final score = xN + (1 - yN);
      if (score > bestScore) { bestScore = score; best = '${m.group(3)}-${m.group(2)}-${m.group(1)}'; }
    }
    return best;
  }

  /// Interpreta o texto OCR: jogo, data (fallback) e TODAS as apostas.
  static TicketScan parse(String text, {String fallbackGame = 'euromilhoes'}) {
    final t = text.toUpperCase();
    String? game;
    if (RegExp(r'EUROMILH|EUROMILLION').hasMatch(t)) {
      game = 'euromilhoes';
    } else if (RegExp(r'EURODREAM').hasMatch(t)) {
      game = 'eurodreams';
    } else if (RegExp(r'TOTOLOTO').hasMatch(t)) {
      game = 'totoloto';
    } else if (RegExp(r'M1LH|MILHAO|MILHÃO').hasMatch(t)) {
      game = 'm1lhao';
    }
    game ??= fallbackGame;

    String? date;
    final dm = _dateRe.firstMatch(text);
    if (dm != null) date = '${dm.group(3)}-${dm.group(2)}-${dm.group(1)}';

    final scan = TicketScan(game: game, date: date);
    final cfg = kGames[game]!;

    if (cfg.isCode) {
      final cm = RegExp(r'\b([A-Z]{3})\s?(\d{5})\b').firstMatch(t);
      scan.bets.add(Bet(code: cm != null ? '${cm.group(1)} ${cm.group(2)}' : ''));
      return scan;
    }

    scan.bets.addAll(_parseBets(text, cfg));
    if (scan.bets.isEmpty) scan.bets.add(Bet());
    return scan;
  }

  /// Extrai várias apostas. Robusto a: marcadores N/E, linhas sem marcadores,
  /// e números+estrelas na mesma linha (com ou sem índice "1." à frente).
  static List<Bet> _parseBets(String text, GameConfig cfg) {
    final lines = text.split(RegExp(r'[\r\n]+'));
    final bets = <Bet>[];
    List<int>? mains;

    List<int> numsIn(String s) => RegExp(r'\d{1,2}')
        .allMatches(s).map((m) => int.parse(m.group(0)!)).toList();

    String? afterMarker(String s, String mk) {
      final r = RegExp('(^|[^A-Z])$mk([^A-Z]|\$)').firstMatch(s);
      return r == null ? null : s.substring(r.end - 1);
    }

    void flush() { if (mains != null) { bets.add(Bet(nums: mains!, extra: [])); mains = null; } }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final up = line.toUpperCase();
      if (_dateRe.hasMatch(line) || RegExp(r'\b\d{4}\b').hasMatch(line)) continue;
      if (RegExp(r'AP\b|SIMPLES|SORT|AUT|TOTAL|M1L|VIRN|PAGAR|EURO|PAIS|CAUSAS').hasMatch(up)) continue;

      final hasE = RegExp(r'(^|[^A-Z])E([^A-Z]|$)').hasMatch(up);
      final hasN = RegExp(r'(^|[^A-Z])N([^A-Z]|$)').hasMatch(up);

      if (hasN) {
        final mn = numsIn(afterMarker(up, 'N') ?? '').where((n) => n >= 1 && n <= cfg.numMax).toList();
        var extra = <int>[];
        if (hasE) {
          final ea = afterMarker(up, 'E');
          if (ea != null) extra = numsIn(ea).where((n) => n >= 1 && n <= cfg.extraMax).take(cfg.extraCount).toList();
        }
        if (mn.length >= cfg.nums) {
          flush();
          mains = mn.take(cfg.nums).toList();
          if (extra.isNotEmpty) { bets.add(Bet(nums: mains!, extra: extra)); mains = null; }
        }
        continue;
      }
      if (hasE && mains != null) {
        final extra = numsIn(afterMarker(up, 'E') ?? up).where((n) => n >= 1 && n <= cfg.extraMax).take(cfg.extraCount).toList();
        bets.add(Bet(nums: mains!, extra: extra));
        mains = null;
        continue;
      }

      // sem marcadores
      var ns = numsIn(up);
      if (ns.length == cfg.nums + 1 || ns.length == cfg.nums + cfg.extraCount + 1) {
        if (ns[0] <= bets.length + 1 || ns[0] <= 9) ns = ns.sublist(1);
      }
      final mainPart = ns.take(cfg.nums).where((n) => n >= 1 && n <= cfg.numMax).toList();
      if (mainPart.length >= cfg.nums) {
        flush();
        mains = mainPart;
        final rest = ns.skip(cfg.nums).where((n) => n >= 1 && n <= cfg.extraMax).take(cfg.extraCount).toList();
        if (rest.length >= cfg.extraCount) { bets.add(Bet(nums: mains!, extra: rest)); mains = null; }
      } else if (mains != null && ns.length <= cfg.extraCount && ns.every((n) => n <= cfg.extraMax)) {
        bets.add(Bet(nums: mains!, extra: ns.take(cfg.extraCount).toList()));
        mains = null;
      }
    }
    flush();

    if (bets.isEmpty) {
      final pool = numsIn(text).where((n) => n >= 1 && n <= 50).toList();
      final nums = <int>[], extra = <int>[];
      int i = 0;
      while (nums.length < cfg.nums && i < pool.length) { if (pool[i] <= cfg.numMax) nums.add(pool[i]); i++; }
      while (extra.length < cfg.extraCount && i < pool.length) { if (pool[i] <= cfg.extraMax) extra.add(pool[i]); i++; }
      if (nums.isNotEmpty) bets.add(Bet(nums: nums, extra: extra));
    }
    return bets;
  }
}
