import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/collection_models.dart';

class CollectionRepository {
  CollectionRepository(this._db);
  final SupabaseClient _db;

  static const defaultName = 'Minha coleção';

  Future<List<CollectionModel>> list() async {
    final rows = await _db
        .from('collections')
        .select('id,name,created_at,collection_items(quantity)')
        .order('created_at');
    return rows
        .map((r) => CollectionModel.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Garante que o usuário tenha ao menos uma coleção.
  Future<List<CollectionModel>> listEnsuringDefault() async {
    final all = await list();
    if (all.isNotEmpty) return all;
    await create(defaultName);
    return list();
  }

  Future<void> create(String name) async {
    await _db.from('collections').insert({'name': name.trim()});
  }

  Future<void> rename(String id, String name) async {
    await _db.from('collections').update({'name': name.trim()}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _db.from('collections').delete().eq('id', id);
  }

  Future<List<CollectionItem>> items(String collectionId) async {
    final rows = await _db
        .from('collection_items')
        .select('print_id,quantity,condition,language,'
            'prints(id,card_code,image_url,rarity,is_alternate,cards(code,name))')
        .eq('collection_id', collectionId);
    final items = rows
        .map((r) => CollectionItem.fromJson(Map<String, dynamic>.from(r)))
        .toList()
      ..sort((a, b) {
        final c = a.cardCode.compareTo(b.cardCode);
        return c != 0 ? c : a.printId.compareTo(b.printId);
      });
    return items;
  }

  Future<void> add({
    required String collectionId,
    required String printId,
    int quantity = 1,
    String language = 'EN',
    String? condition,
  }) async {
    await _db.rpc('add_to_collection', params: {
      'p_collection': collectionId,
      'p_print': printId,
      'p_quantity': quantity,
      'p_language': language,
      'p_condition': condition,
    });
  }

  /// Define a quantidade exata; 0 ou menos remove o item.
  Future<void> setQuantity(String collectionId, CollectionItem item, int q) async {
    if (q <= 0) {
      await _db
          .from('collection_items')
          .delete()
          .eq('collection_id', collectionId)
          .eq('print_id', item.printId)
          .eq('language', item.language);
    } else {
      await _db
          .from('collection_items')
          .update({'quantity': q})
          .eq('collection_id', collectionId)
          .eq('print_id', item.printId)
          .eq('language', item.language);
    }
  }
}
