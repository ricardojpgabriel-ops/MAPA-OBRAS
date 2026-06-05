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

/// OCR on-device com o Google ML Kit + heurística de leitura do talão.
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> readText(String imagePath) async {
    final input = InputImage.fromFilePath(imagePath);
    final result = await _recognizer.processImage(input);
    return result.text;
  }

  void dispose() => _recognizer.close();

  /// Interpreta o texto OCR: jogo, data (canto sup. direito) e números.
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
    final dm = RegExp(r'(\d{2})[\/\-.](\d{2})[\/\-.](\d{4})').firstMatch(text);
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
