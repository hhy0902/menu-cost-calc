import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_settings.dart';
import '../models/ingredient.dart';
import '../models/menu.dart';

class CostRepository {
  CostRepository(this._db, this._uid);

  final FirebaseFirestore _db;
  final String _uid;

  DocumentReference<Map<String, dynamic>> get _user => _db.collection('users').doc(_uid);
  CollectionReference<Map<String, dynamic>> get _ingredients => _user.collection('ingredients');
  CollectionReference<Map<String, dynamic>> get _menus => _user.collection('menus');
  DocumentReference<Map<String, dynamic>> get _settings =>
      _user.collection('settings').doc('default');

  // ---------- 식자재 ----------

  Stream<List<Ingredient>> watchIngredients() => _ingredients
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Ingredient.fromDoc).toList());

  Future<void> saveIngredient(Ingredient ing) {
    if (ing.id.isEmpty) return _ingredients.add(ing.toMap());
    return _ingredients.doc(ing.id).set(ing.toMap());
  }

  Future<void> deleteIngredient(String id) => _ingredients.doc(id).delete();

  // ---------- 메뉴 ----------

  Stream<List<Menu>> watchMenus() => _menus
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Menu.fromDoc).toList());

  Future<void> saveMenu(Menu menu) {
    if (menu.id.isEmpty) return _menus.add(menu.toMap());
    return _menus.doc(menu.id).set(menu.toMap());
  }

  Future<void> deleteMenu(String id) => _menus.doc(id).delete();

  // ---------- 설정 ----------

  Stream<AppSettings> watchSettings() => _settings.snapshots().map((d) {
        final data = d.data();
        return data == null ? AppSettings.defaults : AppSettings.fromMap(data);
      });

  Future<void> saveSettings(AppSettings settings) => _settings.set(settings.toMap());
}
