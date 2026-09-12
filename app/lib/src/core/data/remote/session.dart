import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Quem está logado na cópia da nuvem, ou ninguém.
///
/// O login **não** é porta de entrada do app. A agenda abre sem sinal e sem
/// conta: o barbeiro está com a tesoura na mão e não pode depender do wi-fi
/// para ver quem é o próximo. Entrar serve para outra coisa — ligar a cópia
/// no servidor, que é o que devolve tudo num celular novo.
///
/// Nulo quer dizer "só local". Não é estado de erro.
final sessionProvider = StreamProvider<Session?>((ref) {
  final auth = Supabase.instance.client.auth;

  // O primeiro valor sai na hora, com a sessão que o próprio Supabase já
  // guardou no aparelho: sem isto a tela pisca "desconectado" a cada abertura,
  // mesmo com o login feito.
  return auth.onAuthStateChange
      .map((state) => state.session)
      .distinct((a, b) => a?.accessToken == b?.accessToken);
});

/// O e-mail de quem entrou, para a tela ter o que mostrar.
final signedInEmailProvider = Provider<String?>((ref) {
  return ref.watch(sessionProvider).value?.user.email;
});

class AuthRepository {
  const new(this._auth);

  final GoTrueClient _auth;

  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithPassword(email: email.trim(), password: password);
  }

  /// Sair apaga a sessão, e **não** o banco do aparelho.
  ///
  /// O que está no celular é do barbeiro: sair da conta não pode significar
  /// perder a agenda de amanhã.
  Future<void> signOut() => _auth.signOut();
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(Supabase.instance.client.auth),
);
