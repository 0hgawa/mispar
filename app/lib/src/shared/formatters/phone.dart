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

/// O telefone escrito do jeito que se lê em voz alta: `(11) 99640-2210`.
///
/// A sincronia guarda o número na forma internacional, que é a que o robô
/// precisa para achar a pessoa no WhatsApp — e que ninguém quer ler na tela.
/// Aqui ele volta ao formato de quem mora no Brasil.
///
/// O que não for um telefone brasileiro sai como veio. Um número estrangeiro,
/// ou um campo que alguém usou para outra coisa, não pode virar parênteses
/// tortos só porque a função tentou.
String formatPhone(String phone) {
  // Numero de fora sai intacto. Sem esta linha, `+1 415 555 2671` tem onze
  // digitos como um celular daqui e virava `(14) 15555-2671` — um telefone
  // que nao existe, com a cara de que existe.
  final texto = phone.trim();
  if (texto.startsWith('+') && !texto.startsWith('+55')) return phone;

  final digits = phoneKey(phone);

  return switch (digits.length) {
    11 =>
      '(${digits.substring(0, 2)}) ${digits.substring(2, 7)}'
          '-${digits.substring(7)}',
    10 =>
      '(${digits.substring(0, 2)}) ${digits.substring(2, 6)}'
          '-${digits.substring(6)}',
    _ => phone,
  };
}
