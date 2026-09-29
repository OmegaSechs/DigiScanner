import 'package:flutter_test/flutter_test.dart';
import 'package:digimon_scanner/utils/ocr_utils.dart'; // ajuste ao caminho real

void main() {
  String? best(String s) => CardCodeExtractor.bestMatch(s);

  test('código sozinho', () => expect(best('BT1-010'), 'BT1-010'));

  test('nome da carta antes do código (caso real)', () {
    expect(best('DIGIMON CARD GAME\nAgumon\nBT1-010\nU Play Cost 3\nLv.3 1000 DP'),
        'BT1-010');
    expect(best('Greymon BT1-015'), 'BT1-015');
    expect(best('Garurumon\nST2-05'), 'ST2-05');
  });

  test('correções de OCR', () {
    expect(best('BT1-O1O'), 'BT1-010');
    expect(best('BTl-0l0'), 'BT1-010');
    expect(best('BT1 - 010'), 'BT1-010');
    expect(best('bt17-088'), 'BT17-088');
  });

  test('promo e RB', () {
    expect(best('P-001'), 'P-001');
    expect(best('RB1-025'), 'RB1-025');
  });

  test('vários códigos, na ordem do texto', () {
    expect(CardCodeExtractor.extractCodes('BT1-010 e BT15-088'),
        ['BT1-010', 'BT15-088']);
  });

  test('sem código', () {
    expect(best('Nenhum código aqui'), isNull);
    expect(best('Play-Cost 3, Lv.3-ish'), isNull);
  });
}
