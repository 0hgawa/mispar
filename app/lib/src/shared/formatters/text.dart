/// Tira acento e caixa: quem digita "jonas" tem que achar "Jônas".
String normalizeForSearch(String text) {
  const withAccent = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
  const without = 'aaaaaeeeeiiiiooooouuuucn';

  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = withAccent.indexOf(char);
    buffer.write(index == -1 ? char : without[index]);
  }
  return buffer.toString();
}

/// So os digitos — para casar telefone digitado de qualquer jeito.
String digitsOf(String text) => text.replaceAll(RegExp(r'\D'), '');
