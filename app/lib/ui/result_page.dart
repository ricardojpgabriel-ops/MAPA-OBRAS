import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/game_config.dart';
import '../engine/prize_engine.dart';
import 'theme.dart';
import 'widgets.dart';

class ResultPage extends StatelessWidget {
  final String game;
  final Map<String, dynamic> draw;
  final List<Bet> bets;
  const ResultPage({super.key, required this.game, required this.draw, required this.bets});

  @override
  Widget build(BuildContext context) {
    final cfg = kGames[game]!;
    final results = bets.map((b) => PrizeEngine.eval(game, draw, b)).toList();
    final anyWin = results.any((r) => r.isWinner);
    double total = 0;
    bool special = false;
    for (final r in results) {
      if (r.isWinner) {
        if (r.prizeValue != null) {
          total += r.prizeValue!;
        } else {
          special = true;
        }
      }
    }
    final dt = DateTime.tryParse('${draw['date']}T12:00:00');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: santaGreen,
        foregroundColor: Colors.white,
        title: const Text('Resultado'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${cfg.name} · Sorteio ${draw['id']}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                if (dt != null)
                  Text(DateFormat('dd/MM/yyyy').format(dt),
                      style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
                const SizedBox(height: 12),
                const SectionTitle('Chave vencedora'),
                _winningKey(cfg),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < bets.length; i++) _betCard(cfg, i, bets[i], results[i]),
          const SizedBox(height: 8),
          _totalBanner(anyWin, total, special),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '⚠️ Resultado calculado pela app. Confirme sempre o prémio em jogossantacasa.pt antes de reclamar.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF7A5A00)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _winningKey(GameConfig cfg) {
    if (cfg.isCode) {
      final codes = (draw['codes'] as List?)?.cast<String>() ?? const [];
      return Text('Código(s): ${codes.join(', ')}',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15));
    }
    final nums = (draw['numbers'] as List).cast<num>().map((e) => e.toInt()).toList();
    final extras = <int>[];
    if (game == 'euromilhoes') {
      extras.addAll((draw['stars'] as List).cast<num>().map((e) => e.toInt()));
    } else if (game == 'totoloto') {
      extras.add((draw['sorte'] as num).toInt());
    } else if (game == 'eurodreams') {
      extras.add((draw['sonho'] as num).toInt());
    }
    return Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (final n in nums) Ball('$n'),
      const Text('★', style: TextStyle(fontSize: 20, color: Color(0xFFc98f00))),
      for (final e in extras) Ball('$e', star: true),
    ]);
  }

  Widget _betCard(GameConfig cfg, int i, Bet bet, BetResult r) {
    final win = r.isWinner;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: win ? const Color(0xFFE7F6EC) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: win ? santaGreen : const Color(0xFFE2E2E2), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(cfg.isCode ? 'Código: ${bet.code}' : 'Aposta ${String.fromCharCode(65 + i)}',
            style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        if (!cfg.isCode)
          Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (final n in bet.nums)
              Ball('$n', size: 30, hit: r.hitNums.contains(n), miss: !r.hitNums.contains(n)),
            const Text('★', style: TextStyle(color: Color(0xFFc98f00))),
            for (final e in bet.extra)
              Ball('$e', star: true, size: 30, hit: r.hitExtra.contains(e), miss: !r.hitExtra.contains(e)),
          ]),
        const SizedBox(height: 10),
        if (win) ...[
          Text(r.tierKey != null ? (kTierLabels[game]?[r.tierKey] ?? r.label) : r.label,
              style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          Text(r.prize ?? '',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 22, color: santaGreen)),
        ] else
          const Text('Sem prémio',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF6B7280))),
      ]),
    );
  }

  Widget _totalBanner(bool anyWin, double total, bool special) {
    final fmt = NumberFormat.currency(locale: 'pt_PT', symbol: '€');
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: anyWin ? santaGreen : const Color(0xFF6B7280),
        borderRadius: BorderRadius.circular(14),
      ),
      width: double.infinity,
      child: Column(children: [
        Text(
          anyWin ? (special ? 'Total (+ prémio especial/jackpot)' : 'Total em prémios') : 'Sem prémio 😕',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          anyWin ? fmt.format(total) : 'Boa sorte no próximo!',
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
        ),
      ]),
    );
  }
}
