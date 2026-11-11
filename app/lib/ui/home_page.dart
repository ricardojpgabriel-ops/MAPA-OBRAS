import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../data/game_config.dart';
import '../engine/prize_engine.dart';
import '../services/ocr_service.dart';
import '../services/results_service.dart';
import 'result_page.dart';
import 'scan_page.dart';
import 'theme.dart';
import 'widgets.dart';

/// Campos editáveis de UMA aposta.
class _BetFields {
  final List<TextEditingController> nums;
  final List<TextEditingController> extra;
  final TextEditingController code;
  _BetFields(GameConfig cfg)
      : nums = List.generate(cfg.nums, (_) => TextEditingController()),
        extra = List.generate(cfg.extraCount, (_) => TextEditingController()),
        code = TextEditingController();
  void dispose() {
    for (final c in nums) c.dispose();
    for (final c in extra) c.dispose();
    code.dispose();
  }
}

class HomePage extends StatefulWidget {
  final ResultsService results;
  const HomePage({super.key, required this.results});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String game = 'euromilhoes';
  int drawIndex = 0;
  bool loading = true;
  List<_BetFields> bets = [];

  @override
  void initState() {
    super.initState();
    _resetBets();
    _load();
  }

  GameConfig get cfg => kGames[game]!;

  void _resetBets([int count = 1]) {
    for (final b in bets) b.dispose();
    bets = List.generate(count < 1 ? 1 : count, (_) => _BetFields(cfg));
  }

  Future<void> _load({bool force = false}) async {
    setState(() => loading = true);
    await widget.results.load(forceRefresh: force);
    setState(() { drawIndex = 0; loading = false; });
  }

  void _selectGame(String g) {
    setState(() { game = g; drawIndex = 0; _resetBets(); });
  }

  void _addBet() => setState(() => bets.add(_BetFields(cfg)));
  void _removeBet(int i) => setState(() { bets[i].dispose(); bets.removeAt(i); });

  Future<void> _scan() async {
    final scan = await Navigator.push<TicketScan>(
      context,
      MaterialPageRoute(builder: (_) => ScanPage(fallbackGame: game)),
    );
    if (scan == null) return;
    setState(() {
      if (scan.game != null && scan.game != game) { game = scan.game!; }
      final c = cfg;
      _resetBets(scan.bets.isEmpty ? 1 : scan.bets.length);
      for (var b = 0; b < scan.bets.length && b < bets.length; b++) {
        final src = scan.bets[b], dst = bets[b];
        if (c.isCode) {
          dst.code.text = src.code ?? '';
        } else {
          for (var i = 0; i < c.nums; i++) dst.nums[i].text = i < src.nums.length ? '${src.nums[i]}' : '';
          for (var i = 0; i < c.extraCount; i++) dst.extra[i].text = i < src.extra.length ? '${src.extra[i]}' : '';
        }
      }
      if (scan.date != null) {
        final idx = widget.results.draws(game).indexWhere((d) => d['date'] == scan.date);
        if (idx >= 0) drawIndex = idx;
      }
    });
    if (mounted) {
      final n = scan.bets.length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Li $n aposta${n == 1 ? '' : 's'} — confirme os números antes de verificar.'),
      ));
    }
  }

  void _check() {
    final draws = widget.results.draws(game);
    if (draws.isEmpty) return;
    final list = <Bet>[];
    for (final bf in bets) {
      if (cfg.isCode) {
        final code = bf.code.text.trim();
        if (code.isNotEmpty) list.add(Bet(code: code));
      } else {
        final nums = bf.nums.map((c) => int.tryParse(c.text)).whereType<int>().toList();
        final extra = bf.extra.map((c) => int.tryParse(c.text)).whereType<int>().toList();
        if (nums.isNotEmpty) list.add(Bet(nums: nums, extra: extra));
      }
    }
    if (list.isEmpty) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ResultPage(game: game, draw: draws[drawIndex.clamp(0, draws.length - 1)], bets: list),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final draws = widget.results.draws(game);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: santaGreen,
        foregroundColor: Colors.white,
        title: const Text('EuroScanner', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: loading ? null : () => _load(force: true), icon: const Icon(Icons.refresh), tooltip: 'Atualizar resultados'),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionTitle('1 · Escolha o jogo'),
                  Wrap(spacing: 8, runSpacing: 8, children: kGames.values.map((g) {
                    final sel = g.key == game;
                    return ChoiceChip(
                      label: Text(g.name),
                      selected: sel,
                      onSelected: (_) => _selectGame(g.key),
                      labelStyle: TextStyle(fontWeight: FontWeight.w700, color: sel ? Colors.white : g.color),
                      selectedColor: g.color,
                      backgroundColor: g.color.withOpacity(.08),
                      shape: StadiumBorder(side: BorderSide(color: g.color, width: 1.4)),
                    );
                  }).toList()),
                ])),
                const SizedBox(height: 14),
                _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionTitle('2 · Digitalizar talão'),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: santaGreen),
                    onPressed: _scan,
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Abrir câmara'),
                  ),
                  const SizedBox(height: 6),
                  const Text('A leitura é feita no telemóvel (privada). Lê todas as apostas do talão — confirme sempre os números.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                ])),
                const SizedBox(height: 14),
                _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SectionTitle('3 · Confirme as apostas e o sorteio'),
                  if (draws.isEmpty)
                    const Text('Sem dados de resultados. Toque em atualizar.')
                  else ...[
                    DropdownButtonFormField<int>(
                      value: drawIndex.clamp(0, draws.length - 1),
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Sorteio (data no canto sup. direito do talão)',
                        border: OutlineInputBorder(),
                      ),
                      items: List.generate(draws.length, (i) {
                        final d = draws[i];
                        final dt = DateTime.tryParse('${d['date']}T12:00:00');
                        final label = dt != null ? '${d['id']} · ${DateFormat('dd/MM/yyyy').format(dt)}' : '${d['id']}';
                        return DropdownMenuItem(value: i, child: Text(label, overflow: TextOverflow.ellipsis));
                      }),
                      onChanged: (v) => setState(() => drawIndex = v ?? 0),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < bets.length; i++) _betEditor(i),
                    if (!cfg.isCode)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _addBet,
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar aposta'),
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: santaGreen),
                    onPressed: draws.isEmpty ? null : _check,
                    icon: const Icon(Icons.check_circle),
                    label: Text(cfg.isCode ? 'Verificar resultado' : 'Verificar ${bets.length} aposta${bets.length == 1 ? '' : 's'}'),
                  ),
                ])),
                const SizedBox(height: 14),
                Text(widget.results.updated.isEmpty ? '' : 'Resultados de ${_fmt(widget.results.updated)}',
                    textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                const SizedBox(height: 24),
                const Text('App não oficial. Confirme sempre em jogossantacasa.pt antes de reclamar.\nJogo para maiores de 18. Jogue com responsabilidade.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: Color(0xFF9aa0a6))),
              ],
            ),
    );
  }

  Widget _betEditor(int index) {
    final bf = bets[index];
    final letter = String.fromCharCode(65 + index);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE2E2E2), width: 1.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(cfg.isCode ? 'Código M1lhão' : 'Aposta $letter',
              style: const TextStyle(fontWeight: FontWeight.w800, color: santaGreen)),
          if (bets.length > 1 && !cfg.isCode)
            InkWell(onTap: () => _removeBet(index), child: const Icon(Icons.close, size: 20, color: Color(0xFFd32f2f))),
        ]),
        const SizedBox(height: 8),
        if (cfg.isCode)
          TextField(
            controller: bf.code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'ex.: KVJ 19583', border: OutlineInputBorder(), isDense: true),
          )
        else ...[
          Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            for (var i = 0; i < cfg.nums; i++) _numField(bf.nums[i], false),
            const Text('★', style: TextStyle(fontSize: 22, color: Color(0xFFc98f00), fontWeight: FontWeight.w900)),
            for (var i = 0; i < cfg.extraCount; i++) _numField(bf.extra[i], true),
          ]),
          const SizedBox(height: 6),
          Text('Números 1–${cfg.numMax} · ${cfg.extraLabel} 1–${cfg.extraMax}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ]),
    );
  }

  Widget _numField(TextEditingController c, bool star) {
    return SizedBox(
      width: 48,
      child: TextField(
        controller: c,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 2,
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          filled: true,
          fillColor: star ? const Color(0xFFFFFAF0) : Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: star ? santaGold : const Color(0xFFE2E2E2), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: santaGreen, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Card(child: Padding(padding: const EdgeInsets.all(16), child: child));

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
  }

  @override
  void dispose() {
    for (final b in bets) b.dispose();
    super.dispose();
  }
}
