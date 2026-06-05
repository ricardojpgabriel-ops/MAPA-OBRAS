/// Motor de comparação — portado e validado a partir do protótipo web.
/// Recebe o sorteio (Map vindo do resultados.json) e a aposta do utilizador,
/// e devolve a categoria de prémio, o valor e os acertos para destacar.

class Bet {
  List<int> nums;
  List<int> extra; // estrelas / nº da sorte / nº de sonho
  String? code; // M1lhão
  Bet({List<int>? nums, List<int>? extra, this.code})
      : nums = nums ?? [],
        extra = extra ?? [];
}

class BetResult {
  final String? tierKey; // null = sem prémio
  final String label;
  final String? prize; // texto a mostrar (ex: "€ 96,83")
  final double? prizeValue; // valor numérico, quando aplicável
  final Set<int> hitNums;
  final Set<int> hitExtra;
  const BetResult({
    this.tierKey,
    required this.label,
    this.prize,
    this.prizeValue,
    this.hitNums = const {},
    this.hitExtra = const {},
  });
  bool get isWinner => prize != null;
}

class PrizeEngine {
  static double? prizeToNumber(String s) {
    final m = RegExp(r'([\d.]+),(\d{2})').firstMatch(s);
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll('.', '') + '.' + m.group(2)!);
  }

  static String _norm(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  static BetResult eval(String game, Map<String, dynamic> draw, Bet bet) {
    if (game == 'm1lhao') {
      final codes = (draw['codes'] as List?)?.cast<String>() ?? const [];
      final hit = bet.code != null &&
          codes.any((c) => _norm(c) == _norm(bet.code!));
      return BetResult(
        tierKey: hit ? 'WIN' : null,
        label: hit ? 'Código premiado' : 'Sem prémio',
        prize: hit ? draw['prize'] as String? : null,
        prizeValue: hit ? prizeToNumber(draw['prize']?.toString() ?? '') : null,
      );
    }

    final drawn = (draw['numbers'] as List).cast<num>().map((e) => e.toInt()).toList();
    final hitNums = bet.nums.where(drawn.contains).toSet();
    final nM = hitNums.length;
    String? key;
    Set<int> hitExtra = {};

    if (game == 'euromilhoes') {
      final stars = (draw['stars'] as List).cast<num>().map((e) => e.toInt()).toList();
      hitExtra = bet.extra.where(stars.contains).toSet();
      key = '$nM+${hitExtra.length}';
    } else if (game == 'totoloto') {
      final sorte = (draw['sorte'] as num?)?.toInt();
      final sorteHit = sorte != null && bet.extra.contains(sorte);
      if (sorteHit) hitExtra = {sorte};
      if (nM == 5 && sorteHit) {
        key = '5+S';
      } else if (nM >= 2) {
        key = '$nM';
      } else if (sorteHit) {
        key = 'S';
      }
    } else if (game == 'eurodreams') {
      final sonho = (draw['sonho'] as num?)?.toInt();
      final sonhoHit = sonho != null && bet.extra.contains(sonho);
      if (sonhoHit) hitExtra = {sonho};
      if (nM == 6 && sonhoHit) {
        key = '6+D';
      } else if (nM >= 2) {
        key = '$nM';
      }
    }

    final tiers = (draw['tiers'] as Map?)?.cast<String, dynamic>() ?? {};
    final prize = (key != null && tiers[key] != null) ? tiers[key].toString() : null;
    return BetResult(
      tierKey: prize != null ? key : null,
      label: prize != null ? 'Categoria $key' : 'Sem prémio',
      prize: prize,
      prizeValue: prize != null ? prizeToNumber(prize) : null,
      hitNums: hitNums,
      hitExtra: hitExtra,
    );
  }
}
