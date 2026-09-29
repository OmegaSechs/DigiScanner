/// Extrai códigos de cartas Digimon (ex: BT1-010, ST2-05, P-001) do texto do OCR.
///
/// Diferenças em relação à versão anterior:
/// - Não remove espaços do texto inteiro (isso colava letras vizinhas ao
///   prefixo, gerando "NBT1-010" quando havia o nome da carta antes do código).
/// - Só corrige O/I/L -> 0/1/1 dentro do próprio candidato a código.
/// - Só aceita prefixos conhecidos (lista abaixo, fácil de estender).
/// - Preserva a ordem de aparição no texto.
class CardCodeExtractor {
  /// Prefixos de set aceitos. Acrescente outros conforme aparecerem no catálogo.
  static const prefixes = ['BT', 'ST', 'EX', 'RB', 'P'];

  static final RegExp _pattern = RegExp(
    r'\b(' + prefixes.join('|') + r')([0-9OIL]{0,2})\s*[-–—]\s*([0-9OIL]{2,3})\b',
  );

  static String _digits(String s) =>
      s.replaceAll('O', '0').replaceAll('I', '1').replaceAll('L', '1');

  /// Todos os códigos encontrados, sem repetição, na ordem do texto.
  static List<String> extractCodes(String rawText) {
    final found = <String>[];
    for (final m in _pattern.allMatches(rawText.toUpperCase())) {
      final code = '${m.group(1)}${_digits(m.group(2)!)}-${_digits(m.group(3)!)}';
      if (!found.contains(code)) found.add(code);
    }
    return found;
  }

  /// Primeiro código do texto, ou null.
  static String? bestMatch(String rawText) {
    final codes = extractCodes(rawText);
    return codes.isEmpty ? null : codes.first;
  }

  /// Maiúsculas e sem espaços nas pontas.
  static String normalize(String code) => code.trim().toUpperCase();
}
