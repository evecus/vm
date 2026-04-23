import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class ServerStorage {
  static const _key = 'vps_servers';
  static const _selectedKey = 'vps_selected';

  static Future<List<ServerConfig>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((e) => ServerConfig.fromJson(jsonDecode(e)))
        .toList();
  }

  static Future<void> saveAll(List<ServerConfig> servers) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = servers.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, raw);
  }

  static Future<void> add(ServerConfig server) async {
    final list = await loadAll();
    list.add(server);
    await saveAll(list);
  }

  static Future<void> update(ServerConfig server) async {
    final list = await loadAll();
    final idx = list.indexWhere((s) => s.id == server.id);
    if (idx >= 0) {
      list[idx] = server;
      await saveAll(list);
    }
  }

  static Future<void> remove(String id) async {
    final list = await loadAll();
    list.removeWhere((s) => s.id == id);
    await saveAll(list);
  }

  static Future<String?> getSelectedId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey);
  }

  static Future<void> setSelectedId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, id);
  }

  static String generateId() => const Uuid().v4();
}
