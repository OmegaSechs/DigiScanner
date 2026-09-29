class CollectionModel {
  final String id;
  final String name;
  final int totalCards;
  final int uniquePrints;

  const CollectionModel({
    required this.id,
    required this.name,
    this.totalCards = 0,
    this.uniquePrints = 0,
  });

  factory CollectionModel.fromJson(Map<String, dynamic> j) {
    final items = (j['collection_items'] as List?) ?? const [];
    var total = 0;
    for (final i in items) {
      total += ((i as Map)['quantity'] as num?)?.toInt() ?? 0;
    }
    return CollectionModel(
      id: j['id'] as String,
      name: j['name'] as String,
      totalCards: total,
      uniquePrints: items.length,
    );
  }
}

class CollectionItem {
  final String printId;
  final int quantity;
  final String? condition;
  final String language;
  final String cardCode;
  final String cardName;
  final String? imageUrl;
  final String? rarity;
  final bool isAlternate;

  const CollectionItem({
    required this.printId,
    required this.quantity,
    required this.language,
    required this.cardCode,
    required this.cardName,
    this.condition,
    this.imageUrl,
    this.rarity,
    this.isAlternate = false,
  });

  CollectionItem withQuantity(int q) => CollectionItem(
        printId: printId,
        quantity: q,
        language: language,
        cardCode: cardCode,
        cardName: cardName,
        condition: condition,
        imageUrl: imageUrl,
        rarity: rarity,
        isAlternate: isAlternate,
      );

  factory CollectionItem.fromJson(Map<String, dynamic> j) {
    final p = Map<String, dynamic>.from((j['prints'] as Map?) ?? const {});
    final c = Map<String, dynamic>.from((p['cards'] as Map?) ?? const {});
    return CollectionItem(
      printId: j['print_id'] as String,
      quantity: (j['quantity'] as num).toInt(),
      condition: j['condition'] as String?,
      language: (j['language'] as String?) ?? 'EN',
      cardCode: (p['card_code'] as String?) ?? (c['code'] as String?) ?? '?',
      cardName: (c['name'] as String?) ?? (p['card_code'] as String?) ?? '?',
      imageUrl: p['image_url'] as String?,
      rarity: p['rarity'] as String?,
      isAlternate: (p['is_alternate'] as bool?) ?? false,
    );
  }
}
