# Backend — Supabase

Postgres + o robô do WhatsApp. Custo: **R$ 0/mês** no plano gratuito.

```
migrations/   esquema em SQL, aplicado em ordem
functions/    edge functions (Deno)
tests/        as migrations rodando num Postgres de verdade
```

## Rodar os testes do banco

Não precisa de Docker nem de conta no Supabase: o [PGlite](https://pglite.dev)
roda Postgres de verdade em WASM.

```bash
cd supabase/tests
npm install
node schema.test.mjs
```

23 checagens: as migrations aplicam, a sobreposição é recusada, o almoço some
da disponibilidade, domingo não devolve horário, telefone errado não cancela o
corte do vizinho.

## Testes do robô

```bash
cd supabase/functions/whatsapp
deno test --allow-env dates.test.ts
deno check index.ts
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
