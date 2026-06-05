import 'package:flutter/material.dart';

/// Definição de cada jogo: nº de números, intervalos e tipo de "extra".
class GameConfig {
  final String key;
  final String name;
  final int nums;
  final int numMax;
  final String extra; // 'stars' | 'sorte' | 'sonho' | 'code'
  final int extraCount;
  final int extraMax;
  final String extraLabel;
  final Color color;

  const GameConfig({
    required this.key,
    required this.name,
    this.nums = 0,
    this.numMax = 0,
    this.extra = '',
    this.extraCount = 0,
    this.extraMax = 0,
    this.extraLabel = '',
    this.color = const Color(0xFF00843D),
  });

  bool get isCode => extra == 'code';
}

const Map<String, GameConfig> kGames = {
  'euromilhoes': GameConfig(
    key: 'euromilhoes', name: 'Euromilhões', nums: 5, numMax: 50,
    extra: 'stars', extraCount: 2, extraMax: 12, extraLabel: 'Estrelas',
    color: Color(0xFF0061A8),
  ),
  'totoloto': GameConfig(
    key: 'totoloto', name: 'Totoloto', nums: 5, numMax: 49,
    extra: 'sorte', extraCount: 1, extraMax: 13, extraLabel: 'Nº da Sorte',
    color: Color(0xFFD32F2F),
  ),
  'eurodreams': GameConfig(
    key: 'eurodreams', name: 'EuroDreams', nums: 6, numMax: 40,
    extra: 'sonho', extraCount: 1, extraMax: 5, extraLabel: 'Nº de Sonho',
    color: Color(0xFF6A1B9A),
  ),
  'm1lhao': GameConfig(
    key: 'm1lhao', name: 'M1lhão', extra: 'code', color: Color(0xFFE65100),
  ),
};

/// Rótulos das categorias de prémio, por jogo.
const Map<String, Map<String, String>> kTierLabels = {
  'euromilhoes': {
    '5+2': '5 Números + 2 Estrelas', '5+1': '5 Números + 1 Estrela', '5+0': '5 Números',
    '4+2': '4 Números + 2 Estrelas', '4+1': '4 Números + 1 Estrela', '3+2': '3 Números + 2 Estrelas',
    '4+0': '4 Números', '2+2': '2 Números + 2 Estrelas', '3+1': '3 Números + 1 Estrela',
    '3+0': '3 Números', '1+2': '1 Número + 2 Estrelas', '2+1': '2 Números + 1 Estrela', '2+0': '2 Números',
  },
  'totoloto': {
    '5+S': '5 Números + Nº da Sorte', '5': '5 Números', '4': '4 Números',
    '3': '3 Números', '2': '2 Números', 'S': 'Nº da Sorte',
  },
  'eurodreams': {
    '6+D': '6 Números + Nº de Sonho', '6': '6 Números', '5': '5 Números',
    '4': '4 Números', '3': '3 Números', '2': '2 Números',
  },
};
