import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Carrega os resultados oficiais.
/// 1) tenta a rede (JSON central atualizado pela GitHub Action),
/// 2) cai para a última cópia em cache,
/// 3) cai para o asset incluído na app (funciona no 1.º arranque, offline).
class ResultsService {
  // ⚠️ Atualizar para a URL onde o resultados.json fica publicado
  // (GitHub Pages ou raw.githubusercontent depois do merge para main).
  static const String remoteUrl =
      'https://raw.githubusercontent.com/ricardojpgabriel-ops/MAPA-OBRAS/main/euromilhoes/resultados.json';
  static const String _cacheKey = 'resultados_cache';

  Map<String, dynamic>? data;

  Future<Map<String, dynamic>> load({bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();

    if (!forceRefresh) {
      final cached = prefs.getString(_cacheKey);
      if (cached != null) {
        data = jsonDecode(cached) as Map<String, dynamic>;
      } else {
        final asset = await rootBundle.loadString('assets/resultados.json');
        data = jsonDecode(asset) as Map<String, dynamic>;
      }
    }

    // refresca da rede em segundo plano / a pedido
    try {
      final res = await http
          .get(Uri.parse(remoteUrl))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final fresh = jsonDecode(res.body) as Map<String, dynamic>;
        data = fresh;
        await prefs.setString(_cacheKey, res.body);
      }
    } catch (_) {
      // offline: mantém o que já temos
    }

    data ??= jsonDecode(await rootBundle.loadString('assets/resultados.json'))
        as Map<String, dynamic>;
    return data!;
  }

  List<Map<String, dynamic>> draws(String game) {
    final list = data?['games']?[game]?['draws'] as List?;
    return list?.cast<Map<String, dynamic>>() ?? const [];
  }

  String get updated => data?['updated']?.toString() ?? '';
}
