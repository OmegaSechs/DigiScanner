int? _int(dynamic v) => v == null ? null : (v is int ? v : int.tryParse('$v'));

class PrintModel {
  final String id;
  final String? imageUrl;
  final String? rarity;
  final String? artist;
  final bool isAlternate;

  const PrintModel({
    required this.id,
    this.imageUrl,
    this.rarity,
    this.artist,
    this.isAlternate = false,
  });

  factory PrintModel.fromJson(Map<String, dynamic> j) => PrintModel(
        id: j['id'] as String,
        imageUrl: j['image_url'] as String?,
        rarity: j['rarity'] as String?,
        artist: j['artist'] as String?,
        isAlternate: (j['is_alternate'] as bool?) ?? false,
      );
}

class CardModel {
  final String code;
  final String name;
  final String type;
  final String? color;
  final String? color2;
  final int? level;
  final int? playCost;
  final int? dp;
  final String? form;
  final String? attribute;
  final List<String> digiTypes;
  final String? mainEffect;
  final String? sourceEffect;
  final String? altEffect;
  final List<Map<String, dynamic>> evolutions;
  final List<PrintModel> prints;
  final int maxCopies;
  final bool banned;

  const CardModel({
    required this.code,
    required this.name,
    required this.type,
    this.color,
    this.color2,
    this.level,
    this.playCost,
    this.dp,
    this.form,
    this.attribute,
    this.digiTypes = const [],
    this.mainEffect,
    this.sourceEffect,
    this.altEffect,
    this.evolutions = const [],
    this.prints = const [],
    this.maxCopies = 4,
    this.banned = false,
  });

  /// Primeira impressão (a original vem antes das alternativas).
  String? get thumbnail => prints.isEmpty ? null : prints.first.imageUrl;

  factory CardModel.fromJson(Map<String, dynamic> j) {
    final prints = ((j['prints'] as List?) ?? [])
        .map((p) => PrintModel.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList()
      ..sort((a, b) {
        if (a.isAlternate != b.isAlternate) return a.isAlternate ? 1 : -1;
        return a.id.compareTo(b.id);
      });
    return CardModel(
      code: j['code'] as String,
      name: j['name'] as String,
      type: (j['type'] as String?) ?? 'Unknown',
      color: j['color'] as String?,
      color2: j['color2'] as String?,
      level: _int(j['level']),
      playCost: _int(j['play_cost']),
      dp: _int(j['dp']),
      form: j['form'] as String?,
      attribute: j['attribute'] as String?,
      digiTypes: ((j['digi_types'] as List?) ?? []).map((e) => '$e').toList(),
      mainEffect: j['main_effect'] as String?,
      sourceEffect: j['source_effect'] as String?,
      altEffect: j['alt_effect'] as String?,
      evolutions: ((j['evolutions'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      prints: prints,
      maxCopies: _int(j['max_copies']) ?? 4,
      banned: (j['banned'] as bool?) ?? false,
    );
  }
}
