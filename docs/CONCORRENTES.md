# O que Fresha e Booksy fazem que a gente não faz

Análise feita em 10/09/2026, mexendo nos apps instalados no celular do Marcos —
**Fresha Business** e **Booksy Biz**, os dois do lado do barbeiro. Não é resenha
nem página de marketing: são telas abertas, tocadas e fotografadas. Os prints
estão em `E:\Apps\.templates`, numerados de `22` a `42`.

> A primeira versão deste documento só tinha as abas de cima e perdeu quase
> tudo que importa. As funções de verdade moram **dentro** de Clientes,
> Ajustes e Marketing.

Ordem: **quanto dinheiro cada buraco custa**, não quanto trabalho dá.

---

## 1. Importar clientes da agenda do celular

`35.png` — o estado vazio da aba Clientes do Booksy **é** o convite:

> **"Import clients from your phone's contacts first"**
> `ADD & INVITE CLIENTS FROM CONTACTS`

E o texto explica o truque: *"Create client cards **& invite** your existing
clients... **they can start booking you online 24/7**"*. Não é só cadastro —
**é aquisição**. Traz o contato e já convida a pessoa a marcar sozinha.

O Marcos tem centenas de clientes na agenda do celular. Hoje o nosso app
obriga a digitar um por um, e **o robô do WhatsApp precisa do telefone para
funcionar**. Importar entrega a lista inteira de uma vez e liga o robô no
mesmo gesto.

É a função de maior retorno da lista, e é a que o app começa precisando.

---

## 2. Walk-in — quem chega sem marcar

Fresha e Booksy usam **a mesma frase, palavra por palavra**:

> "Select a client or leave empty for walk-in"

Dois concorrentes que não se falam chegaram na mesma solução (`30.png`,
`32.png`). Isso não é coincidência de design; é o formato do problema.

**Hoje, no nosso app**, quem chega sem marcar não tem caminho. Para registrar,
o Marcos teria que criar um horário no passado — e a tela nem oferece, porque
horário que já passou não aparece. **Dinheiro que entrou na gaveta e não entra
no Caixa.**

Resolvem em dois lugares: "Walk-In" como opção no seletor de cliente, e
**"Sale" / "Quick payment"** no `+` — uma venda que não é agendamento nenhum
(`28.png`).

---

## 3. Desconto

O Checkout do Booksy tem **Discount** ao lado de "Add Item" (`32.png`), e o
valor devido é um campo livre digitável.

Barbeiro dá desconto toda semana — "hoje leva por 30", "a do seu filho é por
conta". Hoje o nosso app só sabe o preço de tabela, então **o Caixa mostra um
número que não foi o que entrou**, e o ticket médio mente junto.

---

## 4. Cartão fidelidade

`37.png` — **Loyalty Cards Program**, marcado como novidade: *"Create stamp
cards for clients and track their rewards"*.

"A cada dez cortes, um grátis" é a coisa mais barbearia da lista inteira. Prende
cliente, e o app já sabe contar quantas vezes cada um veio — o dado está lá,
falta a regra.

---

## 5. Posts prontos para o Instagram e o status do WhatsApp

`40.png`, `41.png`, `42.png` — e não é integração com o Instagram, é melhor.

O Booksy **gera o post**, com os dados do próprio barbeiro, em português, em
categorias feitas para barbearia: *Promova os serviços · Incentive
agendamentos · Compartilhe seu portfólio · Compartilhe avaliações · Frases
inspiradoras*.

Dentro de "Incentive agendamentos" existe **"Disponibilidade de última hora"**,
com legendas prontas:

> "Podemos encaixar você hoje! Acesse nosso Booksy para verificar nossos
> horários livres antes que eles acabem."

**E é aqui que a gente tem uma vantagem que eles não têm.** O nosso app já
calcula as brechas que valem uma mensagem — sabe que amanhã tem 14:00 e 16:30
livres. A legenda deles é genérica porque o app não sabe; a nossa podia ser
concreta:

> "Hoje ainda tenho 14:00 e 16:30. Chama aqui."

Hoje esse dado morre na tela da Semana. Virar imagem compartilhável é a ponte
entre o dado e o dinheiro.

---

## 6. Horário diferente numa data específica

`37.png` — **Schedule Management**: *"Edit your business hours, manage time-off,
and **adjust business hours for specific dates**"*.

Repare na diferença: não é só **fechar** o dia. É **abrir com horário
diferente** numa data — véspera de Natal fecha 14h, sábado de véspera abre mais
cedo.

O nosso bloqueio só sabe fechar. Quem quiser trabalhar meio período tem que
fechar o dia e marcar na mão.

---

## 7. Bloquear um pedaço do dia, de qualquer tela

No Fresha, **"Blocked time" está no `+`** (`28.png`) — um toque, de onde
estiver, e bloqueia um intervalo qualquer.

O nosso "Fechar um dia" está em Ajustes → Horários → rolar até o fim: três
toques e uma tela de configuração. E só fecha dia inteiro; não dá para tirar
duas horas da tarde para ir ao dentista.

---

## 8. Proteção contra falta

`37.png` — **No-Show Protection**, dentro de Payments & Checkout: guardar
cartão ou cobrar sinal de quem já faltou.

Está no nosso `PROJETO.md` como P2 ("sinal via PIX para cliente que já
faltou"). O app já sabe quem faltou — a coluna existe, o Caixa já conta. Falta
a regra.

---

## 9. A agenda como grade

Os dois desenham o dia como **grade de horário**: hora no eixo, o dia como
coluna, hachurado onde está fechado (`22.png`, `24.png`, `31.png`).

A grade mostra **proporção**: um Platinado de 1h30 ocupa o triplo de um
Pezinho. Na nossa lista, os dois viram cards do mesmo tamanho.

O outro lado: lista lê melhor no celular quando o dia tem poucos horários, e é
mais fácil de tocar. Não é troca óbvia — é escolha.

**O que dá para levar sem virar grade:**

- **Linha do "agora"** — traço vermelho com a hora numa pílula (`22.png`), e
  **só na coluna de hoje** (`24.png`). A nossa agenda não marca em lugar nenhum
  onde o dia está.
- **Três estados no cabeçalho do dia**: passado cinza, hoje preenchido, futuro
  preto (`24.png`). A gente só distingue hoje, com um pontinho.
- **Horário de funcionamento no cabeçalho** — o Booksy escreve `10:00 - 19:00`
  embaixo do "Today" (`31.png`).
- **Quarto de hora marcado** na grade, tracejado (`31.png`).

---

## 10. Visão de 3 dias

O Fresha tem quatro visões — `Day · 3 day · Week · Month` (`23.png`), num
seletor em folha onde **o ícone desenha o layout**.

Sete colunas num celular ficam estreitas demais; três é o meio-termo. A gente
pulou de Dia direto para Semana.

---

## 11. Fila de espera

`Waitlist` é item de primeira classe no menu do calendário do Fresha
(`23.png`). Está no nosso `PROJETO.md` como P1 desde o começo e nunca foi
construído. É o que transforma "não tenho horário hoje" em venda quando alguém
desmarca.

---

## 12. Pacote, plano e vale-presente

Fresha e Booksy vendem, além de serviço: **Packages** (10 cortes por R$ 350),
**Memberships** (plano mensal) e **Gift cards** (`25.png`, `37.png`, `38.png`).

Pacote é receita adiantada e prende cliente. É a função que mais muda o
faturamento de uma barbearia de bairro, e a que dá mais trabalho.

---

## 13. Perfil público da barbearia

`34.png` — o Booksy tem **capa, logo, nome, avaliações** e um botão **Share
Profile**. É a página que o cliente vê, e o barbeiro compartilha o link.

No nosso plano isso é o "hotsite" do P2. O robô do WhatsApp cobre a marcação,
mas não cobre "onde fica, que horas abre, quanto custa" para quem ainda não é
cliente.

---

## 14. Coisas pequenas que melhoram o que já existe

- **"Add new client" explícito** como primeira linha do seletor (`30.png`). No
  nosso, o nome digitado vira cliente novo em silêncio.
- **O total dentro do botão**: `R$ 0,00 • CONTINUE` (`32.png`) → o nosso
  "Concluir atendimento" viraria `R$ 40 • Concluir`.
- **Pílula de status em cada card de função** — `Inactive`, `Not invited`
  (`36.png`). Vira lista de pendências sem banner nem badge vermelho.
- **Busca dentro dos ajustes** (`37.png`).
- **Serviço com categoria** (`37.png`); o nosso é lista plana.
- **Formulário personalizado para o cliente** — ficha de anamnese (`38.png`).
- **⚠ laranja na linha** de ajuste que precisa de atenção (`38.png`).
- **Modo com faixa explicando** — ao escolher horário, o topo vira "Select a
  time" com um `✕` para sair (`29.png`).
- **Contador ao lado do título**: `Clients list ②` (`28.png`).

---

## O que a gente faz melhor

Vale registrar, para não copiar o que não deve.

**O Caixa.** O "Sales" do Fresha é um **índice de relatórios** (`25.png`): você
escolhe qual abrir. Para um barbeiro sozinho é um toque a mais para responder
"quanto entrou hoje". O nosso mostra Entrou / Saiu / Sobrou na hora.

**A despesa.** Nenhum dos dois tem lançamento de despesa com repetição mensal
no app do celular. O lucro deles é faturamento menos nada.

**O tamanho.** Os dois carregam Marketing, Team, Add-ons, Memberships, Gift
cards — coisas que uma cadeira só não usa e que pesam em toda tela. O Fresha
ainda cobre o topo com uma faixa roxa de "Continue setup" que não sai, e o
Booksy tem barra de progresso de onboarding gamificada ("Novice — 0 of 5").

---

## Ordem sugerida

**Conserto — dinheiro que hoje escapa ou número que hoje mente:**

1. **Importar clientes dos contatos** (item 1)
2. **Walk-in** — atendimento sem cliente nomeado (item 2)
3. **Desconto** no concluir (item 3)
4. **Linha do agora** e horário de funcionamento no cabeçalho (item 9)
5. **Bloquear pedaço do dia** pelo `+`, e **horário diferente por data**
   (itens 6 e 7)

**Crescimento — quando o conserto estiver feito:**

6. Post de "vaga de hoje" para Instagram e status (item 5)
7. Cartão fidelidade (item 4)
8. Fila de espera (item 11)
9. Pacote e plano (item 12)
10. Perfil público (item 13)

Os cinco primeiros são pequenos. Do seis em diante é crescimento, não conserto.
