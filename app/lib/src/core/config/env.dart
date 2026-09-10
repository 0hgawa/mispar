/// Valores injetados no build via `--dart-define-from-file=config/<flavor>.json`.
///
/// A publishable key do Supabase e publica por design: quem protege os dados e
/// a RLS no Postgres. A `service_role` nunca entra no app — ela so existe
/// dentro das edge functions.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  /// Sem backend configurado o app roda so com o banco local.
  ///
  /// Isto nao e contorno: a agenda **tem** que abrir sem rede. O Supabase e a
  /// fonte de verdade quando existe, e o SQLite continua sendo o que a tela le.
  static bool get hasBackend =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
