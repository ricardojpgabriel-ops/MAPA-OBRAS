import 'dart:io';
import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import '../data/game_config.dart';
import '../engine/prize_engine.dart';

/// Resultado da leitura de um talão (pode ter várias apostas).
class TicketScan {
  String? game;
  String? date; // ISO yyyy-MM-dd
  List<Bet> bets;
  String rawText; // texto bruto do OCR (debug)
  TicketScan({this.game, this.date, List<Bet>? bets, this.rawText = ''}) : bets = bets ?? [];
}

final _dateRe = RegExp(r'(\d{2})[\/\-.](\d{2})[\/\-.](\d{4})');
final _junkRe = RegExp(r'AP\b|SIMPLES|SORT|AUT|TOTAL|IOTAL|M1L|VIRN|PAGAR|EURO|PA[IF]S|CAUSAS|BOAS|DATA');

/// Corrige confusões típicas do OCR em talões térmicos (0↔O, 1↔I/l).
String _norm(String s) => s.replaceAll(RegExp(r'[Oo]'), '0').replaceAll(RegExp(r'[Il|]'), '1');
List<int> _numsIn(String s) =>
    RegExp(r'\d{1,2}').allMatches(_norm(s)).map((m) => int.parse(m.group(0)!)).toList();

/// OCR on-device com o Google ML Kit + heurística de leitura do talão.
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  void dispose() => _recognizer.close();

  /// Lê a imagem (com pré-processamento) e devolve o talão interpretado.
  Future<TicketScan> scanImage(String imagePath, {String fallbackGame = 'euromilhoes'}) async {
    final pp = _preprocess(imagePath);
    final usePath = pp ?? imagePath;
    final input = InputImage.fromFilePath(usePath);
    final result = await _recognizer.processImage(input);
    final scan = parse(result.text, fallbackGame: fallbackGame);
    final dr = _topRightDate(result);
    if (dr != null) scan.date = dr;
    return scan;
  }

  /// Cinzento + contraste + ampliação: ajuda muito com papel térmico.
  String? _preprocess(String path) {
    try {
      final bytes = File(path).readAsBytesSync();
      var im = img.decodeImage(bytes);
      if (im == null) return null;
      if (im.width < 1600) im = img.copyResize(im, width: 1600);
      im = img.grayscale(im);
      im = img.adjustColor(im, contrast: 1.35);
      final out = '${Directory.systemTemp.path}/euroscan_${DateTime.now().millisecondsSinceEpoch}.jpg';
      File(out).writeAsBytesSync(img.encodeJpg(im, quality: 92));
      return out;
    } catch (_) {
      return null;
    }
  }

  Future<String> readText(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);
    return result.text;
  }

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

  /// Interpreta o texto OCR: jogo, data, nº de apostas e as apostas.
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

    final scan = TicketScan(game: game, date: date, rawText: text);
    final cfg = kGames[game]!;

    if (cfg.isCode) {
      final cm = RegExp(r'\b([A-Z]{3})\s?(\d{5})\b').firstMatch(t);
      scan.bets.add(Bet(code: cm != null ? '${cm.group(1)} ${cm.group(2)}' : ''));
      return scan;
    }

    // nº de apostas declarado no talão ("5 AP SIMPLES")
    final dc = RegExp(r'(\d+)\s*AP\b').firstMatch(t);
    final declared = dc != null ? int.parse(dc.group(1)!) : 0;

    final marker = _parseMarker(text, cfg);
    final loose = _parseLoose(text, cfg);
    List<Bet> chosen;
    if (declared > 0 && marker.length >= declared) {
      chosen = marker;
    } else if (marker.length >= 2 && marker.any((b) => b.extra.isNotEmpty)) {
      chosen = marker;
    } else {
      chosen = loose.length > marker.length ? loose : marker;
    }
    if (declared > 0 && chosen.length > declared + 1) chosen = chosen.sublist(0, declared);
    while (declared > chosen.length && declared <= 20) chosen.add(Bet());

    if (chosen.isEmpty) chosen.add(Bet());
    scan.bets.addAll(chosen);
    return scan;
  }

  /// Leitura precisa quando os marcadores N/E são legíveis.
  static List<Bet> _parseMarker(String text, GameConfig cfg) {
    final lines = text.split(RegExp(r'[\r\n]+'));
    final bets = <Bet>[];
    List<int>? mains;
    String? after(String s, String mk) {
      final r = RegExp('(^|[^A-Z])$mk([^A-Z]|\$)').firstMatch(s);
      return r == null ? null : s.substring(r.end - 1);
    }
    void flush() { if (mains != null) { bets.add(Bet(nums: mains!, extra: [])); mains = null; } }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final up = line.toUpperCase();
      if (_dateRe.hasMatch(line) || RegExp(r'\b(19|20)\d{2}\b').hasMatch(line)) continue;
      if (_junkRe.hasMatch(up)) continue;
      final hasE = RegExp(r'(^|[^A-Z])E([^A-Z]|$)').hasMatch(up);
      final hasN = RegExp(r'(^|[^A-Z])N([^A-Z]|$)').hasMatch(up);
      if (hasN) {
        final mn = _numsIn(after(up, 'N') ?? '').where((n) => n >= 1 && n <= cfg.numMax).toList();
        var extra = <int>[];
        if (hasE) {
          final ea = after(up, 'E');
          if (ea != null) extra = _numsIn(ea).where((n) => n >= 1 && n <= cfg.extraMax).take(cfg.extraCount).toList();
        }
        if (mn.length >= cfg.nums) {
          flush();
          mains = mn.take(cfg.nums).toList();
          if (extra.isNotEmpty) { bets.add(Bet(nums: mains!, extra: extra)); mains = null; }
        }
        continue;
      }
      if (hasE && mains != null) {
        final extra = _numsIn(after(up, 'E') ?? up).where((n) => n >= 1 && n <= cfg.extraMax).take(cfg.extraCount).toList();
        bets.add(Bet(nums: mains!, extra: extra));
        mains = null;
      }
    }
    flush();
    return bets;
  }

  /// Leitura tolerante: cada linha com >=3 números vira uma aposta (completa-se à mão).
  static List<Bet> _parseLoose(String text, GameConfig cfg) {
    final bets = <Bet>[];
    for (final raw in text.split(RegExp(r'[\r\n]+'))) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final up = line.toUpperCase();
      if (_dateRe.hasMatch(line) || RegExp(r'\b(19|20)\d{2}\b').hasMatch(line)) continue;
      if (_junkRe.hasMatch(up)) continue;
      if (RegExp(r'[-:/]').hasMatch(line)) continue; // códigos, horas
      final ns = _numsIn(up).where((n) => n >= 1 && n <= cfg.numMax).toList();
      if (ns.length >= 3) {
        bets.add(Bet(
          nums: ns.take(cfg.nums).toList(),
          extra: ns.skip(cfg.nums).where((n) => n <= cfg.extraMax).take(cfg.extraCount).toList(),
        ));
      }
    }
    return bets;
  }
}
