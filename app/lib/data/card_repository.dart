import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/card_models.dart';

const _keep = Object();

class CardFilters {
  final String query;
  final String? type;
  final String? color;
  final int? level;
  const CardFilters({this.query = '', this.type, this.color, this.level});

  /// Passe `null` explicitamente para limpar um filtro; omita para manter.
  CardFilters copyWith({
    String? query,
    Object? type = _keep,
    Object? color = _keep,
    Object? level = _keep,
  }) =>
      CardFilters(
        query: query ?? this.query,
        type: identical(type, _keep) ? this.type : type as String?,
        color: identical(color, _keep) ? this.color : color as String?,
        level: identical(level, _keep) ? this.level : level as int?,
      );
}

class CardRepository {
  CardRepository(this._db);
  final SupabaseClient _db;

  static const pageSize = 30;
  static const _listColumns =
      'code,name,type,color,color2,level,play_cost,max_copies,banned,'
      'prints(id,image_url,is_alternate)';

  /// Remove caracteres que quebram a sintaxe do filtro `or` do PostgREST.
  static String sanitize(String s) =>
      s.replaceAll(RegExp(r'[,()%*\\]'), ' ').trim();

  Future<List<CardModel>> search(CardFilters f, {int page = 0}) async {
    var q = _db.from('cards').select(_listColumns);

    final term = sanitize(f.query);
    if (term.isNotEmpty) {
      q = q.or('name.ilike.%$term%,code.ilike.%$term%');
    }
    if (f.type != null) q = q.eq('type', f.type!);
    if (f.color != null) q = q.or('color.eq.${f.color},color2.eq.${f.color}');
    if (f.level != null) q = q.eq('level', f.level!);

    final from = page * pageSize;
    final rows = await q.order('code').range(from, from + pageSize - 1);
    return rows
        .map((r) => CardModel.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<CardModel?> byCode(String code) async {
    final row = await _db
        .from('cards')
        .select('*, prints(id,image_url,rarity,artist,is_alternate)')
        .eq('code', code)
        .maybeSingle();
    return row == null ? null : CardModel.fromJson(Map<String, dynamic>.from(row));
  }
}
