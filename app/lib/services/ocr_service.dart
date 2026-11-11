import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../data/game_config.dart';
import '../engine/prize_engine.dart';

/// Resultado da leitura de um talão.
class TicketScan {
  String? game;
  String? date; // ISO yyyy-MM-dd
  Bet bet;
  TicketScan({this.game, this.date, Bet? bet}) : bet = bet ?? Bet();
}

final _dateRe = RegExp(r'(\d{2})[\/\-.](\d{2})[\/\-.](\d{4})');

/// OCR on-device com o Google ML Kit + heurística de leitura do talão.
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  void dispose() => _recognizer.close();

  /// Lê a imagem e devolve o talão interpretado.
  /// A DATA DO SORTEIO é procurada preferencialmente no CANTO SUPERIOR DIREITO,
  /// usando a posição de cada bloco de texto (o talão pode ter mais do que uma data).
  Future<TicketScan> scanImage(String imagePath, {String fallbackGame = 'euromilhoes'}) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);

    // parse base (jogo, números, código) a partir do texto completo
    final scan = parse(result.text, fallbackGame: fallbackGame);

    // escolher a data mais "canto superior direito"
    final dr = _topRightDate(result);
    if (dr != null) scan.date = dr;
    return scan;
  }

  /// Compatibilidade: devolve só o texto (usado em testes).
  Future<String> readText(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);
    return result.text;
  }

  /// Procura todas as datas e devolve a do bloco mais acima e à direita.
  String? _topRightDate(RecognizedText result) {
    // limites da área de texto (para normalizar posições)
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
      final xN = (r.center.dx - minX) / spanX; // 0 esquerda … 1 direita
      final yN = (r.center.dy - minY) / spanY; // 0 topo … 1 fundo
      final score = xN + (1 - yN);             // favorece direita + topo
      if (score > bestScore) {
        bestScore = score;
        best = '${m.group(3)}-${m.group(2)}-${m.group(1)}';
      }
    }
    return best;
  }

  /// Interpreta o texto OCR: jogo, data (fallback) e números.
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
      if (cm != null) scan.bet.code = '${cm.group(1)} ${cm.group(2)}';
      return scan;
    }

    // todos os números 1-2 dígitos pela ordem de leitura
    final pool = RegExp(r'\b\d{1,2}\b')
        .allMatches(text)
        .map((m) => int.parse(m.group(0)!))
        .where((n) => n >= 1 && n <= 50)
        .toList();

    final nums = <int>[];
    final extra = <int>[];
    int i = 0;
    while (nums.length < cfg.nums && i < pool.length) {
      if (pool[i] <= cfg.numMax) nums.add(pool[i]);
      i++;
    }
    while (extra.length < cfg.extraCount && i < pool.length) {
      if (pool[i] <= cfg.extraMax) extra.add(pool[i]);
      i++;
    }
    scan.bet.nums = nums;
    scan.bet.extra = extra;
    return scan;
  }
}
