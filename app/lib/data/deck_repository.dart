import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/deck_models.dart';

class ImportResult {
  const ImportResult({
    required this.added,
    this.clamped = const [],
    this.banned = const [],
    this.notFound = const [],
  });

  /// Total de cartas gravadas no deck.
  final int added;

  /// Códigos cuja quantidade foi reduzida ao limite de cópias.
  final List<String> clamped;
  final List<String> banned;
  final List<String> notFound;
}

class DeckRepository {
  DeckRepository(this._db);
  final SupabaseClient _db;

  static const _cardColumns =
      'card_code,quantity,cards(code,name,type,color,color2,level,play_cost,dp,'
      'max_copies,banned,prints(id,image_url,is_alternate))';

  Future<List<DeckSummary>> list() async {
    final rows = await _db
        .from('decks')
        .select('id,name,notes,created_at,updated_at,deck_cards(quantity,cards(type))')
        .order('updated_at', ascending: false);
    return rows
        .map((r) => DeckSummary.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> create(String name) async {
    await _db.from('decks').insert({'name': name.trim()});
  }

  Future<void> rename(String id, String name) async {
    await _db.from('decks').update({'name': name.trim()}).eq('id', id);
  }

  Future<void> updateNotes(String id, String? notes) async {
    await _db.from('decks').update({'notes': notes}).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _db.from('decks').delete().eq('id', id);
  }

  Future<List<DeckCard>> cards(String deckId) async {
    final rows =
        await _db.from('deck_cards').select(_cardColumns).eq('deck_id', deckId);
    final result = rows
        .map((r) => DeckCard.fromJson(Map<String, dynamic>.from(r)))
        .toList()
      ..sort((a, b) {
        if (a.isEgg != b.isEgg) return a.isEgg ? -1 : 1;
        final c = (a.playCost ?? 0).compareTo(b.playCost ?? 0);
        return c != 0 ? c : a.cardCode.compareTo(b.cardCode);
      });
    return result;
  }

  Future<void> setCard(String deckId, String cardCode, int quantity) async {
    if (quantity <= 0) {
      await _db
          .from('deck_cards')
          .delete()
          .eq('deck_id', deckId)
          .eq('card_code', cardCode);
    } else {
      await _db.from('deck_cards').upsert(
        {'deck_id': deckId, 'card_code': cardCode, 'quantity': quantity},
        onConflict: 'deck_id,card_code',
      );
    }
  }

  Future<void> clearCards(String deckId) async {
    await _db.from('deck_cards').delete().eq('deck_id', deckId);
  }

  // ---------- texto: exportar / importar ----------

  Future<String> exportText(String deckId) async {
    final info =
        await _db.from('decks').select('name,notes').eq('id', deckId).single();
    return formatDeck(
      name: info['name'] as String,
      notes: info['notes'] as String?,
      cards: await cards(deckId),
    );
  }

  static String formatDeck({
    required String name,
    String? notes,
    required List<DeckCard> cards,
  }) {
    final b = StringBuffer('// Deck name: $name\n');
    if (notes != null && notes.trim().isNotEmpty) b.writeln('// Notes: ${notes.trim()}');
    b.writeln();
    final eggs = cards.where((c) => c.isEgg);
    final main = cards.where((c) => !c.isEgg);
    if (eggs.isNotEmpty) {
      b.writeln('// Digi-Eggs');
      for (final c in eggs) {
        b.writeln('${c.quantity} ${c.cardCode} ${c.name}');
      }
      b.writeln();
    }
    if (main.isNotEmpty) {
      b.writeln('// Main Deck');
      for (final c in main) {
        b.writeln('${c.quantity} ${c.cardCode} ${c.name}');
      }
    }
    return b.toString().trim();
  }

  static final _codeRe = RegExp(r'\b([A-Za-z]{1,3}\d{0,2}-\d{2,3})\b');
  static final _leadQty = RegExp(r'^\s*(\d{1,2})\s*[xX]?\s');
  static final _trailQty = RegExp(r'(?:^|\s)[xX]\s*(\d{1,2})\s*$');

  /// Lê uma lista de texto e devolve {código: quantidade}. Aceita "4 BT1-010 Agumon",
  /// "4x BT1-010", "BT1-010 x4" e "BT1-010" (1 cópia). Linhas com // ou # são ignoradas.
  static Map<String, int> parseList(String text) {
    final result = <String, int>{};
    for (final raw in text.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('//') || line.startsWith('#')) continue;
      final codeMatch = _codeRe.firstMatch(line);
      if (codeMatch == null) continue;
      final code = codeMatch.group(1)!.toUpperCase();
      final qty = int.tryParse(_leadQty.firstMatch(line)?.group(1) ??
              _trailQty.firstMatch(line)?.group(1) ??
              '') ??
          1;
      if (qty <= 0) continue;
      result[code] = (result[code] ?? 0) + qty;
    }
    return result;
  }

  /// Define a quantidade de cada carta da lista (não apaga as que já estão no deck).
  /// Quantidades acima do limite são reduzidas; cartas banidas ficam de fora.
  Future<ImportResult> importText(String deckId, String text) async {
    final wanted = parseList(text);
    if (wanted.isEmpty) return const ImportResult(added: 0);

    final rows = await _db
        .from('cards')
        .select('code,max_copies,banned')
        .inFilter('code', wanted.keys.toList());
    final known = {for (final r in rows) r['code'] as String: r};

    final upserts = <Map<String, dynamic>>[];
    final clamped = <String>[];
    final banned = <String>[];
    final notFound = <String>[];
    var added = 0;

    wanted.forEach((code, qty) {
      final info = known[code];
      if (info == null) {
        notFound.add(code);
        return;
      }
      if (info['banned'] == true) {
        banned.add(code);
        return;
      }
      final max = (info['max_copies'] as num?)?.toInt() ?? 4;
      var q = qty;
      if (q > max) {
        q = max;
        clamped.add(code);
      }
      if (q <= 0) return;
      upserts.add({'deck_id': deckId, 'card_code': code, 'quantity': q});
      added += q;
    });

    if (upserts.isNotEmpty) {
      await _db.from('deck_cards').upsert(upserts, onConflict: 'deck_id,card_code');
    }
    return ImportResult(
      added: added,
      clamped: clamped,
      banned: banned,
      notFound: notFound,
    );
  }
}
