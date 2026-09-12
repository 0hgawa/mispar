# Arquitetura — Marcos Barber

Flutter 3.47 · Dart 3.13 · Impeller · Material 3

## O padrão: MVVM + feature-first

É o que o próprio time do Flutter recomenda no guia oficial de arquitetura.
Cada feature tem quatro peças: **View**, **ViewModel**, **Repository**, **Service**.

```
View ──eventos──► ViewModel ──► Repository ──► Service (Supabase / Drift)
  ▲                    │
  └──── estado ────────┘
```

Regras que não se quebram:

- **View não conhece fonte de dados.** Nunca importa `supabase` nem `drift`.
- **Repository é a única fonte de verdade** de uma feature. Decide cache vs rede.
- **ViewModel não importa `material.dart`.** Se importar, virou View.
- **Estado desce, evento sobe.**
- **Camada `domain/` só quando precisar.** O guia do Flutter é explícito: use-case
  só existe quando há regra de negócio real. Não criar por simetria.

## Pastas

```
app/lib/
├─ main.dart                    # bootstrap: erro global, .env, Supabase, runApp
└─ src/
   ├─ app.dart                  # MaterialApp.router + tema + rotas
   │
   ├─ core/                     # transversal — nenhuma feature mora aqui
   │  ├─ config/                # env, flavors (dev/prod), constantes
   │  ├─ theme/                 # M3: color scheme, tipografia, shape, motion
   │  ├─ router/                # go_router, rotas tipadas, deep link
   │  ├─ data/                  # cliente Supabase, banco Drift, conectividade
   │  ├─ errors/                # Failure tipado + mensagem legível pro usuário
   │  └─ extensions/            # extensions de BuildContext, DateTime, num
   │
   ├─ shared/                   # design system — widgets sem regra de negócio
   │  ├─ widgets/               # Botão, Card, Sheet, EmptyState, ErrorState…
   │  └─ formatters/            # data pt-BR, moeda, telefone
   │
   └─ features/
      ├─ auth/
      ├─ booking/               # marcar horário
      ├─ agenda/                # agenda do barbeiro
      ├─ clients/               # ficha do cliente
      ├─ services/              # catálogo e preços
      ├─ payments/              # PIX / sinal
      └─ reports/               # relatório semanal
```

Toda feature tem a mesma forma:

```
features/agenda/
├─ data/            agenda_repository.dart · agenda_dto.dart
├─ domain/          appointment.dart  (freezed — só se houver regra própria)
└─ presentation/    agenda_screen.dart · agenda_view_model.dart · widgets/
```

Achou um arquivo? Já sabe onde estão os outros três. É esse o ponto.

## Como o dado anda

O robo escreve no Postgres. A tela le o SQLite. Nada no meio fala com os dois.

```
robo do WhatsApp ──► Postgres (Supabase) ──realtime──► AgendaSync ──► SQLite
                          ▲                                            │
                          │                                        .watch()
                    updateStatus                                       ▼
                          └──────────────── tela ◄────────────────  Riverpod
```

**A tela nunca fala com a rede.** Ela le o banco local, que o Drift reemite a
cada escrita. O `AgendaSync` so empurra o que vem de fora para dentro. Tres
consequencias que valem o desenho:

- A agenda **abre sem sinal**, com o que foi visto por ultimo.
- Horario marcado pelo robo **aparece sozinho**, sem puxar para atualizar.
- Falha de rede nao vira tela de erro: fica o que ja tinha, e a proxima passada
  reconcilia.

**Escrita e local primeiro, e sobe depois.** Concluir, marcar falta, lancar
uma despesa: tudo grava no SQLite e a tela ja reage. A subida acontece quando
houver rede.

> Ate 12/09/2026 este trecho dizia o contrario — "escrita vai para o servidor
> primeiro" — e o codigo nunca fez isso: `AgendaApi.updateStatus` existia sem
> ninguem chamar, e o `AgendaSync` so puxava. O plano antigo tambem estava
> errado para uma barbearia: com a escrita indo direto ao servidor, concluir
> atendimento para de funcionar quando o wi-fi cai, que e justamente a hora em
> que o Marcos esta com a tesoura na mao.

**Sem Supabase configurado o app roda so local.** `Env.hasBackend` decide. Isso
nao e contorno: o local-first e a arquitetura, a nuvem e a copia de tudo e a
fonte do que o robo escreve.

**A nuvem guarda tudo, e nao so o que o robo le.** Desde a migracao 0010 o
Postgres espelha o schema do Drift, inclusive ajustes que o robo nunca vai
consultar. Eles estao la para nao se perderem: celular quebrado entra com
e-mail e senha e volta inteiro. A RLS ja e escrita para `authenticated` desde
a 0001 — o login e o modelo assumido desde o comeco.

## Uma palavra por conceito

`AppointmentStatus.wireName` e o mesmo texto no Postgres e no SQLite:
`deposit_paid`, `no_show`. `fromWire` **estoura** em valor desconhecido em vez
de escolher um — situacao nova no servidor tem que aparecer como erro, nao virar
"confirmado" sem ninguem perceber.

## O que ja esta construido

```
app/lib/src/
├─ core/
│  ├─ data/database/   Drift: tabelas, banco, seed
│  ├─ router/          go_router + StatefulShellRoute (as 4 abas)
│  └─ theme/           paleta V1, ColorScheme M3, StatusColors
├─ shared/
│  ├─ formatters/      dinheiro em centavos, data pt-BR
│  └─ widgets/         AsyncView, EmptyState, ScreenTitle
└─ features/
   ├─ agenda/          Hoje + Semana · a grade de vagas mora aqui
   ├─ clients/         lista com o gosto de cada um
   ├─ services/        catalogo e precos
   └─ reports/         Caixa do mes
```

**Navegacao:** `StatefulShellRoute.indexedStack` com quatro ramos. Cada aba
guarda o proprio estado e a propria rolagem — trocar de aba nao reconstroi
lista nenhuma. Tocar na aba ja aberta volta ao topo.

**Dados:** Drift local, com `.watch()`. Toda tela e um `Stream`: escreveu no
banco, a tela redesenha sozinha. Sem `setState`, sem recarregar na mao.

**Dinheiro em centavos (`int`), nunca `double`.** Ponto flutuante e errado
para dinheiro e a barbearia fecha o caixa com isso.

## Fora do app

```
supabase/migrations/    schema versionado em SQL
supabase/functions/     edge functions (webhook WhatsApp, lembrete 24h)
bot/                    bot do WhatsApp (P0 do PROJETO.md)
design/tokens/          paleta, tipografia, espaçamento — fonte da verdade
.github/workflows/      analyze · test · build Android · build iOS (runner macOS)
```

## Pacotes e por quê

| Pacote | Papel | Por que este |
|---|---|---|
| `flutter_riverpod` + `riverpod_generator` | Estado | Seguro em tempo de compilação, `AsyncValue` resolve loading/erro/dado sem `if` espalhado |
| `go_router` | Navegação | Mantido pelo time do Flutter; deep link e rota tipada de graça |
| `freezed` + `json_serializable` | Modelos | Imutável, `copyWith`, união selada — erro vira falha de compilação |
| `supabase_flutter` | Backend | Postgres + Auth + Realtime + RLS numa dependência |
| `drift` | Offline | A agenda **tem** que abrir sem internet. SQLite tipado, query reativa |
| `intl` | pt-BR | Data e moeda no formato certo |
| `url_launcher` | WhatsApp | O lembrete e a conversa saem do app com o texto pronto — quem manda é o Marcos |
| `--dart-define-from-file` | Config por ambiente | Nativo do Flutter, zero dependência. A `publishableKey` do Supabase é pública por design — quem protege é a RLS |
| `share_plus` + `path_provider` | Exportar o caixa | A planilha do período sai pela folha de compartilhar do sistema — o Marcos manda no WhatsApp do contador sem sair do app |
| `very_good_analysis` | Lint | O conjunto mais rígido em uso real. Lint fraco não pega nada |
| `mocktail` | Teste | Mock sem code-gen |

> `riverpod_lint` ficou de fora: a versao atual trava o `riverpod` em 3.1.0 e o
> runtime ja esta em 3.4.3. Entra quando alcancar.

> Cinco pacotes saíram em 10/09/2026 por nunca terem sido usados:
> `flutter_local_notifications`, `timezone`, `cached_network_image`,
> `connectivity_plus` e `flutter_animate`. Dependência que ninguém chama é
> peso no APK e configuração de build para manter — o do primeiro obrigava
> desugaring da core library. Voltam no dia em que houver código chamando.

## Apagar e aposentar — a mesma regra em três lugares

Serviço, tipo de despesa e cliente seguem o mesmo desenho, e não por acaso:

- **Nunca foi usado** → apaga de vez. É erro de digitação ou cadastro
  repetido, e não há histórico para perder.
- **Já foi usado** → o botão de apagar nem aparece; o caminho é o interruptor
  (*No cardápio*, *Na lista*), que tira da escolha sem tocar no passado.
- **O banco recusa de qualquer jeito.** As três colunas são chave estrangeira
  e o `PRAGMA foreign_keys` fica ligado. Se a tela deixasse passar, o SQLite
  não deixa — apagar levaria junto o atendimento, e com ele o Caixa.

A contagem que decide qual dos dois oferecer sai de um fluxo que a tela **já
escuta** (o histórico do cliente, o `usageCount` do formulário) — nenhum bloco
desses abre consulta própria.

## O Caixa — as regras do dinheiro

Quatro regras seguram o número. Se alguma cair, o Marcos toma decisão em cima
de um número que mente.

1. **Faturado é só o que foi concluído.** Horário marcado para daqui a uma hora
   é promessa, não faturamento. Aparece separado, como "a receber".
2. **Faturamento não é lucro.** O Caixa tem dois lados — *Entrou* e *Saiu* — e
   o que interessa é a diferença. São telas diferentes porque são coisas
   diferentes: o que entra tem cliente, serviço e horário; o que sai tem tipo e
   nota.
3. **Despesa que se repete é lançada sozinha.** Aluguel, internet e contador
   entram no mês novo sem ninguém lembrar — senão o lucro só fecharia no mês em
   que o Marcos digitasse tudo. Quais meses entram é [`monthsToCatchUp`][r] quem
   decide, e nunca um do futuro: dinheiro que ainda não saiu não é saída.
4. **O tipo de despesa é cadastro, não lista fixa.** Os custos de cada
   barbearia são os dela; sem cadastro, tudo vira "Outros" e o detalhamento
   deixa de servir.

A forma de pagamento (dinheiro, Pix, cartão) fica no atendimento e só existe em
atendimento concluído — reabrir limpa. É com ela que o Marcos confere a
maquininha, cujo extrato chega dois dias depois.

O `AgendaSync` grava atendimento com `insertAllOnConflictUpdate` e **não**
inclui `payment_method` no companion: coluna ausente não entra no `DO UPDATE`,
então o que foi anotado no balcão sobrevive à sincronia. Se alguém acrescentar
o campo ao companion, tem que trazer o valor do servidor junto.

[r]: ../app/lib/src/features/reports/domain/recurring.dart

## Performance — o que Impeller pede

- `const` em todo widget que puder. É o corte de rebuild mais barato que existe.
- Escopo de rebuild pequeno: `Consumer` na folha, nunca na raiz da tela.
- `ListView.builder` sempre — nunca `Column` dentro de `SingleChildScrollView` para lista.
- `RepaintBoundary` em item de lista com animação.
- Zero I/O na `build()`.
- Shader warm-up no primeiro run — Impeller compila antes, mas transição pesada
  na primeira abertura ainda merece medição.

## Definição de pronto

- [ ] `flutter analyze` sem aviso
- [ ] Teste do ViewModel passando
- [ ] Estado vazio e estado de erro desenhados — nunca tela branca
- [ ] Alvo de toque ≥ 48dp
- [ ] Contraste conferido no claro e no escuro
- [ ] Cor semântica do M3, nunca hex solto
