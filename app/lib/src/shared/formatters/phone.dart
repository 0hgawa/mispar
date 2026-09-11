/// So os digitos que identificam a linha.
///
/// Tira pontuacao e o codigo do pais, entao `+55 11 99640-2210`,
/// `11996402210` e `(11) 9 9640-2210` viram a mesma coisa. E a chave para
/// saber se dois cadastros sao a mesma pessoa — telefone e identidade de
/// cliente, nome nao e.
///
/// O corte do `55` so acontece quando sobra numero suficiente: um fixo antigo
/// de oito digitos que comece com 55 nao pode perder o prefixo.
String phoneKey(String phone) {
  final digits = phone.replaceAll(RegExp('[^0-9]'), '');
  if (digits.startsWith('55') && digits.length > 11) {
    return digits.substring(2);
  }
  return digits;
}
