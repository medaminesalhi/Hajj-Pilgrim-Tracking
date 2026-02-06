import 'package:shared_preferences/shared_preferences.dart';

class SessionManager {
  static const _kDocId = 'session_docId';
  static const _kNom = 'session_nom';
  static const _kPrenom = 'session_prenom';
  static const _kTel = 'session_tel';
  static const _kBus = 'session_bus';

  static Future<void> saveUser({
    required String docId,
    required String nom,
    required String prenom,
    required String tel,
    required String bus,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_kDocId, docId);
    await sp.setString(_kNom, nom);
    await sp.setString(_kPrenom, prenom);
    await sp.setString(_kTel, tel);
    await sp.setString(_kBus, bus);
  }

  static Future<Map<String, String>?> getUser() async {
    final sp = await SharedPreferences.getInstance();
    final docId = sp.getString(_kDocId);
    if (docId == null || docId.isEmpty) return null;

    return {
      "docId": docId,
      "nom": sp.getString(_kNom) ?? "",
      "prenom": sp.getString(_kPrenom) ?? "",
      "tel": sp.getString(_kTel) ?? "",
      "bus": sp.getString(_kBus) ?? "",
    };
  }

  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_kDocId);
    await sp.remove(_kNom);
    await sp.remove(_kPrenom);
    await sp.remove(_kTel);
    await sp.remove(_kBus);
  }
}
