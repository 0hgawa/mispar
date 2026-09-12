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

/// O telefone no formato internacional, que é como o servidor guarda.
///
/// `11 99640-2210` vira `+5511996402210`. É o formato que o WhatsApp usa para
/// achar a pessoa, e por isso é o que o robô precisa encontrar no Postgres —
/// digitado de qualquer jeito no balcão, sobe sempre igual.
///
/// Nulo quando não há número. Vazio não serve: no servidor o telefone é único,
/// e dois textos vazios colidiriam; nulo é como se diz "ninguém anotou".
///
/// Nulo também quando o que foi digitado não dá um número de verdade — dez
/// dígitos são o mínimo de um celular brasileiro com DDD. Subir "123" faria o
/// servidor recusar a linha, e com ela a lista inteira de clientes.
String? phoneWire(String phone) {
  final digits = phoneKey(phone);
  if (digits.length < 10 || digits.length > 13) return null;
  return '+55$digits';
}
