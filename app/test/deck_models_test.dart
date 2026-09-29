import 'package:digimon_scanner/models/deck_models.dart';
import 'package:flutter_test/flutter_test.dart';

DeckCard card(
  String code, {
  int qty = 1,
  String type = 'Digimon',
  int maxCopies = 4,
  bool banned = false,
  int? playCost,
}) =>
    DeckCard(
      cardCode: code,
      quantity: qty,
      name: 'Card $code',
      type: type,
      maxCopies: maxCopies,
      banned: banned,
      playCost: playCost,
    );

List<DeckCard> validDeck() => [
      card('EGG-001', qty: 3, type: 'Digi-Egg'),
      card('EGG-002', qty: 2, type: 'Digi-Egg'),
      for (var i = 0; i < 12; i++) card('BT1-${i.toString().padLeft(3, '0')}', qty: 4, playCost: i),
      card('BT1-012', qty: 2, playCost: 6),
    ];

void main() {
  group('DeckValidation', () {
    test('deck válido (50 + 5 ovos)', () {
      final v = DeckValidation.validate(validDeck());
      expect(v.mainCount, 50);
      expect(v.eggCount, 5);
      expect(v.errors, isEmpty);
      expect(v.isValid, isTrue);
    });

    test('menos de 50 cartas', () {
      final v = DeckValidation.validate([card('BT1-001', qty: 4)]);
      expect(v.isValid, isFalse);
      expect(v.errors.any((e) => e.contains('50')), isTrue);
    });

    test('mais de 5 ovos', () {
      final v = DeckValidation.validate([
        card('EGG-001', qty: 4, type: 'Digi-Egg'),
        card('EGG-002', qty: 4, type: 'Digi-Egg'),
      ]);
      expect(v.eggCount, 8);
      expect(v.errors.any((e) => e.contains('Digi-Eggs')), isTrue);
    });

    test('carta banida vem do dado, não de código fixo', () {
      final banned = DeckValidation.validate([card('ZZ1-001', banned: true)]);
      expect(banned.errors.any((e) => e.contains('banida')), isTrue);

      // BT15-003 sem a flag "banned" NÃO é tratada como banida.
      final plain = DeckValidation.validate([card('BT15-003', type: 'Digi-Egg')]);
      expect(plain.errors.any((e) => e.contains('banida')), isFalse);
    });

    test('restrita a 1 cópia (max_copies = 1)', () {
      final v = DeckValidation.validate([card('EX1-066', qty: 2, maxCopies: 1)]);
      expect(v.errors.any((e) => e.contains('restrita')), isTrue);
      final ok = DeckValidation.validate([card('EX1-066', qty: 1, maxCopies: 1)]);
      expect(ok.errors.any((e) => e.contains('restrita')), isFalse);
    });

    test('limite de cópias padrão e exceção de 50', () {
      final over = DeckValidation.validate([card('BT1-001', qty: 5)]);
      expect(over.errors.any((e) => e.contains('limite')), isTrue);
      final many = DeckValidation.validate([card('BT6-085', qty: 50, maxCopies: 50)]);
      expect(many.errors.any((e) => e.contains('limite')), isFalse);
      expect(many.mainCount, 50);
    });

    test('aviso quando não há Digi-Eggs', () {
      final v = DeckValidation.validate([card('BT1-001', qty: 4)]);
      expect(v.warnings, isNotEmpty);
    });
  });

  group('CostCurveEntry', () {
    test('soma por custo e ignora ovos', () {
      final curve = CostCurveEntry.fromCards([
        card('A-001', qty: 4, playCost: 3),
        card('A-002', qty: 3, playCost: 5),
        card('A-003', qty: 2, playCost: 3),
        card('EGG-001', type: 'Digi-Egg'),
      ]);
      expect(curve.length, 2);
      expect(curve[0].cost, 3);
      expect(curve[0].count, 6);
      expect(curve[1].cost, 5);
      expect(curve[1].count, 3);
    });
  });

  group('parsing', () {
    test('DeckCard.fromJson usa a impressão original como miniatura', () {
      final c = DeckCard.fromJson({
        'card_code': 'BT1-010',
        'quantity': 3,
        'cards': {
          'name': 'Agumon',
          'type': 'Digimon',
          'play_cost': 3,
          'max_copies': 4,
          'banned': false,
          'prints': [
            {'image_url': 'alt', 'is_alternate': true},
            {'image_url': 'orig', 'is_alternate': false},
          ],
        },
      });
      expect(c.imageUrl, 'orig');
      expect(c.copyWith(quantity: 1).quantity, 1);
      expect(c.copyWith(quantity: 1).name, 'Agumon');
    });

    test('DeckSummary.fromJson separa ovos e deck principal', () {
      final s = DeckSummary.fromJson({
        'id': 'd1',
        'name': 'Meu deck',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-02T00:00:00Z',
        'deck_cards': [
          {'quantity': 4, 'cards': {'type': 'Digimon'}},
          {'quantity': 3, 'cards': {'type': 'Digi-Egg'}},
        ],
      });
      expect(s.cardCount, 4);
      expect(s.eggCount, 3);
      expect(s.isComplete, isFalse);
    });
  });
}
