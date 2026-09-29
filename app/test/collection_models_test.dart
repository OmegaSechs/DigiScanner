import 'package:digimon_scanner/models/collection_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CollectionModel soma quantidades e conta únicas', () {
    final c = CollectionModel.fromJson({
      'id': 'a',
      'name': 'Minha coleção',
      'collection_items': [
        {'quantity': 3},
        {'quantity': 2},
      ],
    });
    expect(c.totalCards, 5);
    expect(c.uniquePrints, 2);
  });

  test('CollectionModel sem itens', () {
    final c = CollectionModel.fromJson({'id': 'a', 'name': 'x'});
    expect(c.totalCards, 0);
    expect(c.uniquePrints, 0);
  });

  test('CollectionItem.fromJson lê impressão e carta aninhadas', () {
    final i = CollectionItem.fromJson({
      'print_id': 'BT1-010_P1',
      'quantity': 2,
      'language': 'JA',
      'condition': 'NM',
      'prints': {
        'card_code': 'BT1-010',
        'image_url': 'u',
        'rarity': 'C',
        'is_alternate': true,
        'cards': {'code': 'BT1-010', 'name': 'Agumon'},
      },
    });
    expect(i.cardName, 'Agumon');
    expect(i.cardCode, 'BT1-010');
    expect(i.isAlternate, isTrue);
    expect(i.withQuantity(5).quantity, 5);
    expect(i.withQuantity(5).language, 'JA');
  });

  test('CollectionItem tolera impressão ausente', () {
    final i = CollectionItem.fromJson(
        {'print_id': 'X-1', 'quantity': 1});
    expect(i.cardCode, '?');
    expect(i.language, 'EN');
  });
}
