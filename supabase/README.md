# Backend — Supabase

Postgres + o robô do WhatsApp. Custo: **R$ 0/mês** no plano gratuito.

```
migrations/   esquema em SQL, aplicado em ordem
functions/    edge functions (Deno)
tests/        as migrations rodando num Postgres de verdade
```

## Conferir o robô

O código das edge functions roda em Deno, e não no Flutter — então ele não
entra no `flutter analyze` nem nos testes do app. Precisa ser conferido à
parte, e ficou **um ano sem ser**: até 12/09/2026 nenhuma dessas três linhas
tinha rodado uma vez.

```bash
cd supabase/functions
deno check whatsapp/index.ts reminders/index.ts
deno lint
deno test
```

Rode antes de publicar qualquer função. Erro de tipo aqui só aparece quando o
cliente manda mensagem — e aí quem descobre é ele.

## Rodar os testes do banco

Não precisa de Docker nem de conta no Supabase: o [PGlite](https://pglite.dev)
roda Postgres de verdade em WASM.

```bash
cd supabase/tests
npm install
node schema.test.mjs
```

59 checagens: as migrations aplicam, a sobreposição é recusada, o almoço some
da disponibilidade, domingo não devolve horário, telefone errado não cancela o
corte do vizinho, e o lembrete desligado não manda nada.

## Testes do robô

```bash
cd supabase/functions
deno test --allow-env _shared/dates.test.ts
deno check whatsapp/index.ts reminders/index.ts
deno lint
```

## As duas decisões que sustentam o banco

**1. Quem impede horário em cima do outro é o Postgres, não o app.**

```sql
exclude using gist (tstzrange(starts_at, ends_at, '[)') with &&)
where (status not in ('cancelled', 'no_show'))
```

O robô e o celular do Marcos escrevem ao mesmo tempo. Nenhum "consulta antes de
gravar" resolve corrida — dois pedidos podem passar pela consulta juntos e
gravar os dois. A constraint de exclusão não deixa: um dos dois recebe
`HORARIO_OCUPADO` e o robô oferece outro horário. Esse é o motivo de a regra
morar aqui e não no aplicativo.

**2. Preço e duração ficam gravados no agendamento.**

São cópia do serviço no momento da marcação. Se o Marcos subir o corte de R$ 40
para R$ 45 amanhã, o que já passou continua valendo o que foi combinado — senão
o relatório do mês passado muda sozinho.

## Subir

```bash
supabase link --project-ref <ref>
supabase db push
supabase functions deploy whatsapp --no-verify-jwt
supabase functions deploy reminders
```

`--no-verify-jwt` é obrigatório: quem chama é a Meta, que não tem JWT do
Supabase. Quem protege o endereço é o `WHATSAPP_VERIFY_TOKEN` e a assinatura da
própria Meta.

### Segredos

```bash
supabase secrets set \
  WHATSAPP_TOKEN=... \
  WHATSAPP_PHONE_ID=... \
  WHATSAPP_VERIFY_TOKEN=<qualquer string sua>
```

`SUPABASE_URL` e `SUPABASE_SERVICE_ROLE_KEY` já vêm injetadas. A serviceRole
passa por cima da RLS e **nunca** entra no app do celular.

### Ligar o webhook na Meta

No app do WhatsApp em `developers.facebook.com`, Webhooks → Callback URL:

```
https://<ref>.supabase.co/functions/v1/whatsapp
```

Verify token: o mesmo que você definiu acima. Assine o campo `messages`.

## O lembrete da véspera

É a única mensagem que custa: vai fora da janela de 24h, então precisa de
template aprovado pela Meta (~R$ 0,05 por envio). Nasce **desligado** — quem
liga é o Marcos, em Ajustes → Lembrete, onde a tela mostra antes quanto isso
custaria na semana que vem.

### O template

Em `developers.facebook.com` → WhatsApp Manager → Modelos de mensagem:

- Nome: `lembrete_horario`
- Categoria: **Utilidade** — mais barata que Marketing e sem precisar de opt-in
- Idioma: Português (BR)
- Corpo: `Oi, {{1}}! Seu {{2}} está marcado para {{3}}. Confirma?`
- Botões de resposta rápida, **nesta ordem**: *Confirmar*, *Desmarcar*

A ordem importa: a varredura manda o id do horário no botão 0 como
`confirm:<id>` e no botão 1 como `cancel:<id>`.

### A varredura

De hora em hora, pelo pg_cron:

```sql
select cron.schedule(
  'lembretes', '0 * * * *',
  $select net.http_post(
      url     := 'https://<ref>.supabase.co/functions/v1/reminders',
      headers := '{"Authorization": "Bearer <service_role_key>"}'::jsonb
  )$
);
```

Quem decide quem recebe é `due_reminders()` no Postgres, e não o código do
robô: só horário que ainda vai acontecer, só cliente com cadastro, e nunca o
mesmo horário duas vezes — `reminder_sent_at` só é gravado depois que a Meta
aceita o envio, então falha de rede faz tentar de novo, não pagar de novo.

## A conversa

Meta: horário fechado em **quatro mensagens**, sem sair do WhatsApp.

```
Cliente: oi
Bot:     Oi, Rafael! Corte + Barba, como da última vez?
         [Corte + Barba] [Corte] [Barba] …
Cliente: (toca)
Bot:     Que dia fica bom?
         [Hoje · 3 livres] [Amanhã · 6 livres] [Sáb 12/09 · 2 livres]
Cliente: (toca)
Bot:     Sábado, 12 de setembro. Tenho estes horários:
         [09:00] [11:30] [14:00] [Outro horário]
Cliente: (toca)
Bot:     Fechado — sábado, 12 de setembro, às 14:00.
         Corte + Barba · R$ 60
```

Regras que sustentam isso:

- **Quatro horários por vez.** Lista longa trava a decisão.
- **O de sempre vem primeiro** para quem já veio.
- **Texto livre também funciona**: "sábado", "amanhã", "25/12".
- **Toda mensagem tem saída**: escrever *atendente* passa para o Marcos.
- Se alguém pegar o horário no meio da conversa, o robô oferece os que sobraram
  em vez de dar erro.
