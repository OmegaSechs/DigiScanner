int? _int(dynamic v) => v == null ? null : (v is int ? v : int.tryParse('$v'));

class DeckSummary {
  final String id;
  final String name;
  final String? notes;
  final int cardCount;
  final int eggCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const DeckSummary({
    required this.id,
    required this.name,
    this.notes,
    required this.cardCount,
    required this.eggCount,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Contagens simples (a validação completa está em [DeckValidation]).
  bool get isComplete => cardCount == 50 && eggCount <= 5;

  DeckSummary copyWith({String? notes}) => DeckSummary(
        id: id,
        name: name,
        notes: notes ?? this.notes,
        cardCount: cardCount,
        eggCount: eggCount,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory DeckSummary.fromJson(Map<String, dynamic> json) {
    var main = 0;
    var egg = 0;
    for (final dc in (json['deck_cards'] as List?) ?? const []) {
      final qty = _int((dc as Map)['quantity']) ?? 0;
      final type = (dc['cards'] as Map?)?['type'] as String?;
      if (type == 'Digi-Egg') {
        egg += qty;
      } else if (type != null) {
        main += qty;
      }
    }
    return DeckSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      notes: json['notes'] as String?,
      cardCount: main,
      eggCount: egg,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class DeckCard {
  final String cardCode;
  final int quantity;
  final String name;
  final String type;
  final String? color;
  final String? color2;
  final int? level;
  final int? playCost;
  final int? dp;
  final String? imageUrl;
  final int maxCopies;
  final bool banned;

  const DeckCard({
    required this.cardCode,
    required this.quantity,
    required this.name,
    required this.type,
    this.color,
    this.color2,
    this.level,
    this.playCost,
    this.dp,
    this.imageUrl,
    this.maxCopies = 4,
    this.banned = false,
  });

  bool get isEgg => type == 'Digi-Egg';

  DeckCard copyWith({int? quantity}) => DeckCard(
        cardCode: cardCode,
        quantity: quantity ?? this.quantity,
        name: name,
        type: type,
        color: color,
        color2: color2,
        level: level,
        playCost: playCost,
        dp: dp,
        imageUrl: imageUrl,
        maxCopies: maxCopies,
        banned: banned,
      );

  factory DeckCard.fromJson(Map<String, dynamic> json) {
    final cardData = Map<String, dynamic>.from(json['cards'] as Map);
    final prints = (cardData['prints'] as List?) ?? const [];

    // Miniatura: impressão original primeiro, senão a primeira disponível.
    String? thumb;
    for (final p in prints) {
      if ((p as Map)['is_alternate'] != true) {
        thumb = p['image_url'] as String?;
        break;
      }
    }
    if (thumb == null && prints.isNotEmpty) {
      thumb = (prints.first as Map)['image_url'] as String?;
    }

    return DeckCard(
      cardCode: json['card_code'] as String,
      quantity: _int(json['quantity']) ?? 0,
      name: cardData['name'] as String,
      type: (cardData['type'] as String?) ?? 'Unknown',
      color: cardData['color'] as String?,
      color2: cardData['color2'] as String?,
      level: _int(cardData['level']),
      playCost: _int(cardData['play_cost']),
      dp: _int(cardData['dp']),
      imageUrl: thumb,
      maxCopies: _int(cardData['max_copies']) ?? 4,
      banned: (cardData['banned'] as bool?) ?? false,
    );
  }
}

class DeckValidation {
  final bool isValid;
  final int mainCount;
  final int eggCount;
  final List<String> errors;
  final List<String> warnings;

  const DeckValidation({
    required this.isValid,
    required this.mainCount,
    required this.eggCount,
    required this.errors,
    required this.warnings,
  });

  /// Regras: 50 cartas no deck principal, 0 a 5 no deck de Digi-Eggs, limite de
  /// cópias por código e cartas banidas. Os limites vêm de `cards.max_copies` e
  /// `cards.banned` (preenchidos com tools/apply_rules.py), sem códigos fixos aqui.
  factory DeckValidation.validate(List<DeckCard> cards) {
    var main = 0;
    var eggs = 0;
    final errs = <String>[];
    final warns = <String>[];

    for (final c in cards) {
      if (c.isEgg) {
        eggs += c.quantity;
      } else {
        main += c.quantity;
      }
      if (c.banned) {
        errs.add('${c.name} (${c.cardCode}) está banida.');
      } else if (c.quantity > c.maxCopies) {
        errs.add(c.maxCopies == 1
            ? '${c.name} (${c.cardCode}) é restrita a 1 cópia.'
            : '${c.name} (${c.cardCode}) excede o limite de ${c.maxCopies} cópias.');
      }
    }

    if (main != 50) {
      errs.add('O deck principal deve ter exatamente 50 cartas (atual: $main).');
    }
    if (eggs > 5) {
      errs.add('O deck de Digi-Eggs pode ter no máximo 5 cartas (atual: $eggs).');
    }
    if (eggs == 0) {
      warns.add('O deck não tem Digi-Eggs.');
    }

    return DeckValidation(
      isValid: errs.isEmpty,
      mainCount: main,
      eggCount: eggs,
      errors: errs,
      warnings: warns,
    );
  }
}

class CostCurveEntry {
  final int cost;
  final int count;
  const CostCurveEntry(this.cost, this.count);

  static List<CostCurveEntry> fromCards(List<DeckCard> cards) {
    final counts = <int, int>{};
    for (final c in cards) {
      final cost = c.playCost;
      if (!c.isEgg && cost != null) {
        counts[cost] = (counts[cost] ?? 0) + c.quantity;
      }
    }
    final entries =
        counts.entries.map((e) => CostCurveEntry(e.key, e.value)).toList()
          ..sort((a, b) => a.cost.compareTo(b.cost));
    return entries;
  }
}
