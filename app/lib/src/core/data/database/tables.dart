import 'package:drift/drift.dart';

/// Catalogo de servicos. Preco em centavos — nunca double para dinheiro.
@DataClassName('ServiceRow')
class Services extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get durationMinutes => integer()();
  IntColumn get priceCents => integer()();
  BoolColumn get requiresDeposit =>
      boolean().withDefault(const Constant(false))();

  /// Servico aposentado sai da lista sem apagar o historico de quem ja pagou.
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  /// Nome do valor de CatalogueKind. Produto e vendido mas nao marcado: e o
  /// que tira a venda de shampoo da agenda sem tirar do Caixa.
  TextColumn get kind => text().withDefault(const Constant('service'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ClientRow')
class Clients extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get phone => text()();

  /// O gosto do cliente: "maquina 2 nas laterais".
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// Cliente fora da lista sai da busca ao marcar, sem apagar o historico —
  /// o mesmo que "No cardapio" faz com o servico. Quem nunca veio se apaga
  /// de vez; quem ja sentou na cadeira so sai de vista.
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Horario de funcionamento, uma linha por dia da semana.
///
/// Fica no banco e nao em constante: e o mesmo dado que o robo le no Postgres,
/// e o Marcos precisa poder mudar sem app novo. Guardado em minutos desde a
/// meia-noite — simples de comparar e sem depender de tipo de hora.
@DataClassName('ShopHoursRow')
class ShopHours extends Table {
  /// 1 = segunda ... 7 = domingo (isoweekday).
  IntColumn get weekday => integer()();
  BoolColumn get isOpen => boolean().withDefault(const Constant(true))();
  IntColumn get opensMinutes => integer()();
  IntColumn get closesMinutes => integer()();
  IntColumn get lunchStartMinutes => integer().nullable()();
  IntColumn get lunchEndMinutes => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {weekday};
}

/// No que o dinheiro da barbearia sai. Cadastravel, igual ao catalogo de
/// servicos: os custos de cada barbearia sao os dela.
@DataClassName('ExpenseCategoryRow')
class ExpenseCategories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Tipo aposentado sai da lista sem apagar o que ja foi lancado nele.
  BoolColumn get active => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Gasto da barbearia. Sem ele o Caixa so mostra o que entrou, e faturamento
/// nao e lucro.
@DataClassName('ExpenseRow')
class Expenses extends Table {
  TextColumn get id => text()();
  DateTimeColumn get spentAt => dateTime()();

  /// A coluna se chama "category" desde a v4, quando o tipo ainda era uma
  /// constante do codigo. O nome no SQL fica: renomear custaria migracao e
  /// nao mudaria nada.
  TextColumn get categoryId =>
      text().named('category').references(ExpenseCategories, #id)();
  IntColumn get cents => integer()();
  TextColumn get note => text().nullable()();

  /// Aluguel, internet, contador: sai todo mes sem ninguem lembrar de lancar.
  /// Sem isto o lucro so estaria certo no mes em que o Marcos digitasse tudo.
  BoolColumn get repeatsMonthly =>
      boolean().withDefault(const Constant(false))();

  /// Liga as copias mensais a um mesmo gasto. O primeiro da serie carrega o
  /// proprio id aqui.
  TextColumn get seriesId => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// O que se ajusta uma vez e vale para a barbearia inteira.
///
/// Uma linha so: o id fixo em 1 impede uma segunda. Tabela, e nao constante no
/// codigo, porque o robo do WhatsApp precisa ler o mesmo numero — dois lugares
/// guardando a mesma regra e a receita para o app oferecer 10:05 e o robo
/// oferecer 10:00.
@DataClassName('ShopSettingsRow')
class ShopSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// De quanto em quanto tempo os horarios sao oferecidos.
  IntColumn get slotStepMinutes => integer().withDefault(const Constant(15))();

  /// Mandar o lembrete da véspera pelo WhatsApp.
  ///
  /// Desligado de fábrica: é a única mensagem do robô que custa dinheiro, e
  /// nada que custa se liga sozinho.
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// Quantas horas antes do atendimento o lembrete sai.
  IntColumn get reminderHoursBefore =>
      integer().withDefault(const Constant(24))();

  /// Avisar quando um cliente para de vir.
  ///
  /// Só existe no aparelho: quem lê é a lista de clientes, e o robô do
  /// WhatsApp não tem nada a ver com isso.
  BoolColumn get driftedEnabled =>
      boolean().withDefault(const Constant(true))();

  /// Quantos dias sem aparecer contam como sumido.
  IntColumn get driftedDays => integer().withDefault(const Constant(60))();

  /// Como a barbearia se chama, onde fica, e o @ dela.
  ///
  /// Texto vazio quer dizer "não preenchido" — nulo aqui só daria um segundo
  /// jeito de dizer a mesma coisa, e quem lê teria que tratar os dois.
  TextColumn get shopName => text().withDefault(const Constant(''))();
  TextColumn get shopAddress => text().withDefault(const Constant(''))();

  /// O @ do Instagram, sem arroba e em minúscula. Guardado limpo porque é
  /// assim que ele entra no endereço do perfil.
  TextColumn get shopInstagram => text().withDefault(const Constant(''))();

  /// As formas de pagamento aceitas, separadas por vírgula.
  ///
  /// Texto e não três colunas: uma quarta forma um dia não vira migração.
  TextColumn get acceptedPayments =>
      text().withDefault(const Constant('cash,pix,card'))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Fechamento fora da semana padrao: feriado, medico, viagem.
///
/// Espelha `time_blocks` do Postgres, que e onde o robo do WhatsApp olha
/// antes de oferecer horario.
@DataClassName('TimeBlockRow')
class TimeBlocks extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startsAt => dateTime()();

  /// Exclusivo, como toda faixa no app.
  DateTimeColumn get endsAt => dateTime()();
  TextColumn get reason => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AppointmentRow')
class Appointments extends Table {
  TextColumn get id => text()();

  /// Nulo no que foi lançado direto no Caixa: quem chega sem marcar quase
  /// nunca é cadastrado, e exigir um nome ali faria o dinheiro não ser
  /// lançado — que é o problema que este campo vazio resolve.
  TextColumn get clientId => text().nullable().references(Clients, #id)();
  TextColumn get serviceId => text().references(Services, #id)();
  DateTimeColumn get startsAt => dateTime()();

  /// Copia do servico no momento da marcacao, de proposito: se o preco subir
  /// amanha, o que ja passou continua valendo o que foi cobrado.
  IntColumn get durationMinutes => integer()();
  IntColumn get priceCents => integer()();

  /// Nome do valor de AppointmentStatus. Guardado como texto para o banco nao
  /// depender do dominio.
  TextColumn get status => text()();

  /// Nome do valor de PaymentMethod. Nulo enquanto ninguem anotou: sem isto
  /// nao da para conferir a maquininha contra o que o dia rendeu.
  TextColumn get paymentMethod => text().nullable()();

  /// Digitado direto no Caixa, sem ter passado pela agenda.
  ///
  /// Coluna, e nao "sem cliente": o balcao tambem se cadastra, e quem lancou
  /// com nome continua tendo lancamento para corrigir. Sem isto, escolher o
  /// cliente trancava a edicao do proprio lancamento.
  BoolColumn get walkIn => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// O livro dos apagados, igual ao do servidor.
///
/// Consulta não enxerga o que sumiu: a linha não está mais lá para dizer que
/// se foi. Sem este livro, apagar um cliente no celular o deixaria no servidor
/// para sempre — e a cópia, que existe para devolver a barbearia inteira,
/// devolveria gente que o Marcos tirou de propósito.
///
/// Quem escreve aqui é gatilho do SQLite, e não as telas: espalhar essa
/// responsabilidade por seis repositórios é garantir que um deles esqueça.
class DeletedRows extends Table {
  /// `sourceTable` e nao `tableName`: o Drift ja usa esse nome para a propria
  /// tabela. O nome no banco continua `table_name`, igual ao do servidor.
  TextColumn get sourceTable => text().named('table_name')();
  TextColumn get rowId => text()();
  DateTimeColumn get deletedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {sourceTable, rowId};
}

/// Onde a sincronia parou.
///
/// Fica fora de [ShopSettings] de propósito: ajuste da barbearia sobe para o
/// servidor, e isto é do aparelho. Dois celulares do mesmo dono param em
/// lugares diferentes.
class SyncState extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  /// A hora do servidor na última descida completa. É a partir dela que se
  /// pergunta "o que foi apagado desde então?".
  DateTimeColumn get lastPulledAt => dateTime().nullable()();

  /// A tela de entrada já foi respondida — entrando ou dispensando.
  ///
  /// Uma vez só, na primeira abertura. Depois disso o app abre direto na
  /// agenda, com ou sem conta: quem está com a tesoura na mão não pode
  /// esbarrar num formulário todo dia.
  BoolColumn get welcomed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
