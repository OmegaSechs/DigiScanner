import 'package:digimon_scanner/data/deck_repository.dart';
import 'package:digimon_scanner/models/deck_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DeckRepository.parseList', () {
    test('formatos aceitos', () {
      final m = DeckRepository.parseList(
        '// Deck\n4 BT1-010 Agumon\n2x st1-16\nBT2-030 x3\nEX1-066\n\n# nota\n',
      );
      expect(m, {'BT1-010': 4, 'ST1-16': 2, 'BT2-030': 3, 'EX1-066': 1});
    });

    test('linhas repetidas somam', () {
      expect(DeckRepository.parseList('2 BT1-010\n2 BT1-010'), {'BT1-010': 4});
    });

    test('ignora linhas sem código e nomes terminando em "x"', () {
      final m = DeckRepository.parseList('texto qualquer\nAgumon Max 2 BT5-001');
      expect(m, {'BT5-001': 1});
    });

    test('CRLF', () {
      expect(DeckRepository.parseList('4 BT1-010\r\n3 BT1-011'),
          {'BT1-010': 4, 'BT1-011': 3});
    });
  });

  test('formatDeck separa ovos e deck principal', () {
    final text = DeckRepository.formatDeck(name: 'Teste', notes: 'nota', cards: [
      const DeckCard(cardCode: 'BT1-001', quantity: 4, name: 'Koromon', type: 'Digi-Egg'),
      const DeckCard(cardCode: 'BT1-010', quantity: 3, name: 'Agumon', type: 'Digimon'),
    ]);
    expect(text, contains('// Digi-Eggs\n4 BT1-001 Koromon'));
    expect(text, contains('// Main Deck\n3 BT1-010 Agumon'));
    // O que exportamos precisa voltar igual pelo importador.
    expect(DeckRepository.parseList(text), {'BT1-001': 4, 'BT1-010': 3});
  });
}
