# Marcos Barber — Agendamento por WhatsApp

Bot de WhatsApp que marca horário na agenda do barbeiro, sem mensalidade.
Este documento é o resultado do benchmark dos melhores apps de agendamento do
mundo (beleza e saúde) e define o que vale copiar, o que vale ignorar e em que
ordem construir.

---

## 1. Benchmark — quem é referência e por quê

| App | Mercado | O que faz melhor que todo mundo |
|---|---|---|
| **Booksy** | EUA/PL/BR — barbearia | Marketplace que traz cliente novo; lembretes que cortam no-show >50% em lojas reais |
| **Fresha** | Global — beleza | Modelo sem mensalidade (ganha em pagamento/marketplace); no-show protection e multi-loja inclusos |
| **Square Appointments** | Global | Agenda + pagamento no mesmo lugar; plano grátis de verdade para 1 profissional |
| **Squire** | EUA — só barbearia | Fala a língua da barbearia: fila de walk-in, split de comissão, fechamento de caixa |
| **GlossGenius** | EUA — beleza | Interface bonita e rápida; onboarding em minutos, sem manual |
| **Zocdoc** | EUA — saúde | Disponibilidade ao vivo sincronizada; **"Zo"**, atendente de IA 24/7 que entende linguagem natural no telefone |
| **Trinks / Avec** | Brasil | Agendamento a partir do WhatsApp com link para hotsite; lembrete e confirmação automáticos |
| **TopAgenda / AppBarber / Prit** | Brasil | PIX nativo, horário fixo do cliente semanal, app Android leve |

**A leitura:** ninguém no mundo resolveu o problema *dentro* do WhatsApp. Todos
usam o WhatsApp como porta de entrada e jogam o cliente para um site ou app.
Quem conclui a marcação sem sair da conversa tem uma vantagem real — e é
exatamente o que dá para fazer aqui.

---

## 2. Os números que justificam cada função

- No-show sem lembrete automático: **20–30%**. Com lembrete: cai até **40%**.
- Sinal/depósito na reserva derruba falta em até **65%** (média relatada: 29%).
- SMS/WhatsApp tem **98%** de taxa de abertura — nenhum outro canal chega perto.
- Cliente que marcou online volta **78%** das vezes; walk-in volta **39%**. Dobro.
- **74%** dos brasileiros preferem agendar pelo celular (Sebrae); barbearias com
  agendamento online relatam até **+30%** de clientes.

Ou seja: lembrete e rebooking não são enfeite. São a maior parte do retorno.

---

## 3. Funções — em ordem de construção

### P0 — sem isto o produto não existe
1. **Marcar horário na conversa.** Serviço → dia → horário → confirma. Nada de link.
2. **Disponibilidade real.** Lê o Google Calendar do Marcos; horário ocupado nunca aparece.
3. **Horário de funcionamento + duração por serviço.** Corte 30min, corte+barba 50min, etc.
4. **Confirmação imediata** com resumo (serviço, dia, hora, preço, endereço) e evento criado na agenda.
5. **Cancelar e remarcar pela conversa.** Uma frase, sem ligar para a loja.
6. **Bloqueio manual.** Marcos escreve "fechado sexta 15h às 18h" e some da grade.

### P1 — o que traz dinheiro de volta
7. **Lembrete 24h antes**, com botão de confirmar / remarcar / cancelar na própria mensagem.
8. **Rebooking automático.** Depois do corte: "mesmo horário daqui a 3 semanas?" — um toque.
9. **Fila de espera.** Cliente pede horário lotado, entra na fila; se abrir vaga, recebe o aviso primeiro.
10. **Ficha do cliente.** Histórico, serviço preferido, observação ("máquina 2 nas laterais"), aniversário.
11. **Reconhecer quem é.** Cliente que já veio não repete nome nem serviço — o bot já sabe.

### P2 — quando o volume pedir
12. **Sinal via PIX** para cliente que já faltou, ou para serviço longo.
13. **Multi-barbeiro** com agenda e comissão por profissional.
14. **Relatório semanal** no WhatsApp do Marcos: faturamento, faltas, clientes novos, ocupação.
15. **Link público** (hotsite) para bio do Instagram e Google Maps — quem prefere clicar, clica.

### Fora de escopo — decidido
- Marketplace de descoberta. É o negócio da Booksy, não o nosso.
- App próprio. O WhatsApp já está instalado; app novo é atrito, não feature.
- Estoque, folha, fiscal. Barbearia de bairro não precisa de ERP.

---

## 4. O caminho de ouro

O objetivo é **marcar em 4 mensagens**, sem sair do WhatsApp:

```
Cliente: oi, tem horário sábado?
Bot:     Oi, Rafael! Corte + barba, como da última vez? (50min, R$ 60)
         Sábado tenho: 09:00 · 11:30 · 14:00 · 16:30
Cliente: 14h
Bot:     Fechado — sábado, 14/03, às 14:00. Corte + barba, R$ 60.
         Rua X, 123. Te mando um lembrete na sexta.
```

Regras que sustentam isso:
- **Nunca mais de 4 opções de horário por vez.** Lista longa trava a decisão.
- **Sempre propor o provável.** Último serviço, horário parecido com o de sempre.
- **Toda mensagem do bot cabe na tela** sem rolar.
- **Resposta em menos de 2 segundos.** Acima disso a conversa parece quebrada.
- **Texto livre funciona.** "sábado à tarde", "amanhã cedo", "tem hoje?" precisam ser entendidos.
- **Toda mensagem tem saída.** "falar com o Marcos" transfere para humano a qualquer momento.

---

## 5. Stack e custo

| Camada | Escolha | Custo |
|---|---|---|
| Mensageria | WhatsApp Cloud API (Meta, oficial) | R$ 0 — conversa iniciada pelo cliente é grátis |
| Backend | Supabase Edge Function (Deno) | R$ 0 — 500 mil chamadas/mês no plano gratuito |
| Agenda | Postgres no Supabase | R$ 0 |
| Base de clientes | Postgres no Supabase | R$ 0 |
| Lembrete 24h | Template utility (fora da janela de 24h) | ~R$ 0,04 por envio (~R$ 4/mês com 100 lembretes) |

> **Mudou desde a primeira versão deste documento:** o backend era Google
> Apps Script + Sheets. Passou a ser Supabase quando o app entrou em Flutter —
> o robô grava no mesmo Postgres que o app lê, sem cola no meio, e a regra de
> "duas pessoas não ocupam a mesma cadeira" passa a ser garantida pelo banco.
> O custo continua zero.

**Mensalidade: zero.** O único custo variável é o lembrete proativo — e ele se
paga com o primeiro no-show evitado.

**Pré-requisitos:** número dedicado que não esteja em uso no app do WhatsApp, e
conta Meta Business verificada.

**Descartado:** Baileys / whatsapp-web.js. É grátis e usa o número comum, mas
viola os termos e o número pode ser banido. Não se aposta o telefone do negócio.

---

## 6. Como saber se deu certo

- Marcações concluídas sem intervenção do Marcos: **> 80%**
- Tempo médio da conversa até o horário fechado: **< 60 segundos**
- Taxa de falta: **abaixo de 10%**
- Rebooking na saída: **> 50%** dos atendimentos
- Ocupação da agenda: acompanhar semana a semana

---

## 7. Próximo passo

Montar o P0: webhook, leitura de intenção, consulta de horário livre no
Calendar e confirmação. Depois plugar o número.
