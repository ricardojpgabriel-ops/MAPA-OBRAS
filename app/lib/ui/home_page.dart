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

  // controladores de uma aposta (MVP: 1 aposta)
  late List<TextEditingController> numCtrls;
  late List<TextEditingController> extraCtrls;
  final codeCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rebuildControllers();
    _load();
  }

  void _rebuildControllers() {
    final cfg = kGames[game]!;
    numCtrls = List.generate(cfg.nums, (_) => TextEditingController());
    extraCtrls = List.generate(cfg.extraCount, (_) => TextEditingController());
  }

  Future<void> _load({bool force = false}) async {
    setState(() => loading = true);
    await widget.results.load(forceRefresh: force);
    setState(() {
      drawIndex = 0;
      loading = false;
    });
  }

  void _selectGame(String g) {
    setState(() {
      game = g;
      drawIndex = 0;
      _rebuildControllers();
      codeCtrl.clear();
    });
  }

  Future<void> _scan() async {
    final cfg = kGames[game]!;
    final scan = await Navigator.push<TicketScan>(
      context,
      MaterialPageRoute(builder: (_) => ScanPage(fallbackGame: game)),
    );
    if (scan == null) return;
    setState(() {
      if (scan.game != null && scan.game != game) {
        game = scan.game!;
        _rebuildControllers();
      }
      final c = kGames[game]!;
      for (var i = 0; i < c.nums; i++) {
        numCtrls[i].text = i < scan.bet.nums.length ? '${scan.bet.nums[i]}' : '';
      }
      for (var i = 0; i < c.extraCount; i++) {
        extraCtrls[i].text = i < scan.bet.extra.length ? '${scan.bet.extra[i]}' : '';
      }
      if (c.isCode && scan.bet.code != null) codeCtrl.text = scan.bet.code!;
      if (scan.date != null) {
        final idx = widget.results.draws(game).indexWhere((d) => d['date'] == scan.date);
        if (idx >= 0) drawIndex = idx;
      }
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Leitura concluída — confirme os números antes de verificar.'),
      ));
    }
    // ignore: use_build_context_synchronously
  }

  void _check() {
    final cfg = kGames[game]!;
    final draws = widget.results.draws(game);
    if (draws.isEmpty) return;
    final bet = Bet();
    if (cfg.isCode) {
      bet.code = codeCtrl.text.trim();
    } else {
      bet.nums = numCtrls.map((c) => int.tryParse(c.text)).whereType<int>().toList();
      bet.extra = extraCtrls.map((c) => int.tryParse(c.text)).whereType<int>().toList();
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultPage(
          game: game,
          draw: draws[drawIndex.clamp(0, draws.length - 1)],
          bets: [bet],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cfg = kGames[game]!;
    final draws = widget.results.draws(game);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: santaGreen,
        foregroundColor: Colors.white,
        title: const Text('Scanner de Talões', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            onPressed: loading ? null : () => _load(force: true),
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar resultados',
          )
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SectionTitle('1 · Escolha o jogo'),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: kGames.values.map((g) {
                        final sel = g.key == game;
                        return ChoiceChip(
                          label: Text(g.name),
                          selected: sel,
                          onSelected: (_) => _selectGame(g.key),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : g.color,
                          ),
                          selectedColor: g.color,
                          backgroundColor: g.color.withOpacity(.08),
                          shape: StadiumBorder(side: BorderSide(color: g.color, width: 1.4)),
                        );
                      }).toList(),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                _card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SectionTitle('2 · Digitalizar talão'),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: santaGreen),
                      onPressed: _scan,
                      icon: const Icon(Icons.photo_camera),
                      label: const Text('Abrir câmara'),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'A leitura é feita no telemóvel (privada). Confirme sempre os números lidos.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                _card(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SectionTitle('3 · Confirme a aposta e o sorteio'),
                    if (draws.isEmpty)
                      const Text('Sem dados de resultados. Toque em atualizar.')
                    else ...[
                      DropdownButtonFormField<int>(
                        value: drawIndex.clamp(0, draws.length - 1),
                        decoration: const InputDecoration(
                          labelText: 'Sorteio (data no canto sup. direito do talão)',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(draws.length, (i) {
                          final d = draws[i];
                          final dt = DateTime.tryParse('${d['date']}T12:00:00');
                          final label = dt != null
                              ? '${d['id']} · ${DateFormat('dd/MM/yyyy').format(dt)}'
                              : '${d['id']}';
                          return DropdownMenuItem(value: i, child: Text(label, overflow: TextOverflow.ellipsis));
                        }),
                        onChanged: (v) => setState(() => drawIndex = v ?? 0),
                      ),
                      const SizedBox(height: 14),
                      if (cfg.isCode)
                        TextField(
                          controller: codeCtrl,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Código M1lhão',
                            hintText: 'ex.: KVJ 19583',
                            border: OutlineInputBorder(),
                          ),
                        )
                      else
                        _betEditor(cfg),
                    ],
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: santaGreen),
                      onPressed: draws.isEmpty ? null : _check,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Verificar resultado'),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
                Text(
                  widget.results.updated.isEmpty
                      ? ''
                      : 'Resultados de ${_fmt(widget.results.updated)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 30),
                const Text(
                  'App não oficial. Confirme sempre em jogossantacasa.pt antes de reclamar.\nJogo para maiores de 18. Jogue com responsabilidade.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Color(0xFF9aa0a6)),
                ),
              ],
            ),
    );
  }

  Widget _betEditor(GameConfig cfg) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        for (var i = 0; i < cfg.nums; i++) _numField(numCtrls[i], cfg.numMax, false),
        const Text('★', style: TextStyle(fontSize: 22, color: Color(0xFFc98f00), fontWeight: FontWeight.w900)),
        for (var i = 0; i < cfg.extraCount; i++) _numField(extraCtrls[i], cfg.extraMax, true),
      ]),
      const SizedBox(height: 6),
      Text('Números 1–${cfg.numMax} · ${cfg.extraLabel} 1–${cfg.extraMax}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
    ]);
  }

  Widget _numField(TextEditingController c, int max, bool star) {
    return SizedBox(
      width: 50,
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

  Widget _card({required Widget child}) =>
      Card(child: Padding(padding: const EdgeInsets.all(16), child: child));

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('dd/MM/yyyy HH:mm').format(d.toLocal());
  }

  @override
  void dispose() {
    for (final c in numCtrls) c.dispose();
    for (final c in extraCtrls) c.dispose();
    codeCtrl.dispose();
    super.dispose();
  }
}
