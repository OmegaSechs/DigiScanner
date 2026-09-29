import 'package:digimon_scanner/data/card_repository.dart';
import 'package:digimon_scanner/models/card_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CardModel.fromJson ordena impressões (original primeiro)', () {
    final c = CardModel.fromJson({
      'code': 'BT1-010',
      'name': 'Agumon',
      'type': 'Digimon',
      'level': 3,
      'digi_types': ['Reptile'],
      'evolutions': [
        {'cost': 2, 'color': 'Red', 'level': 2}
      ],
      'prints': [
        {'id': 'BT1-010_P1', 'image_url': 'b', 'is_alternate': true},
        {'id': 'BT1-010', 'image_url': 'a', 'is_alternate': false},
      ],
    });
    expect(c.prints.first.id, 'BT1-010');
    expect(c.thumbnail, 'a');
    expect(c.digiTypes, ['Reptile']);
    expect(c.evolutions.first['cost'], 2);
  });

  test('CardModel tolera campos ausentes', () {
    final c = CardModel.fromJson({'code': 'X-1', 'name': 'X'});
    expect(c.type, 'Unknown');
    expect(c.prints, isEmpty);
    expect(c.thumbnail, isNull);
  });

  test('sanitize remove caracteres do filtro or', () {
    expect(CardRepository.sanitize('a,b(c)%'), 'a b c');
  });

  test('CardFilters.copyWith limpa um filtro com null', () {
    const f = CardFilters(type: 'Digimon', level: 3);
    expect(f.copyWith(type: null).type, isNull);
    expect(f.copyWith(query: 'x').type, 'Digimon');
  });

  test('CardModel lê max_copies e banned (com padrões)', () {
    final a = CardModel.fromJson({'code': 'X-1', 'name': 'X', 'max_copies': 1, 'banned': true});
    expect(a.maxCopies, 1);
    expect(a.banned, isTrue);
    final b = CardModel.fromJson({'code': 'X-2', 'name': 'Y'});
    expect(b.maxCopies, 4);
    expect(b.banned, isFalse);
  });
}
