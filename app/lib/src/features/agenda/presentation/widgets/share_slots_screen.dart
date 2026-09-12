import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mispar/src/core/theme/app_colors.dart';
import 'package:mispar/src/features/agenda/data/shop_settings_repository.dart';
import 'package:mispar/src/features/agenda/domain/day_schedule.dart';
import 'package:mispar/src/features/agenda/domain/free_slots_message.dart';
import 'package:mispar/src/features/agenda/domain/shop_hours.dart';
import 'package:mispar/src/features/agenda/presentation/day_view_model.dart';
import 'package:mispar/src/features/booking/presentation/new_appointment_view_model.dart';
import 'package:mispar/src/features/settings/domain/shop_profile.dart';
import 'package:mispar/src/shared/formatters/day_time.dart';
import 'package:mispar/src/shared/task_route.dart';
import 'package:mispar/src/shared/widgets/app_snack.dart';
import 'package:mispar/src/shared/widgets/bottom_action.dart';
import 'package:mispar/src/shared/widgets/task_bar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Quantos horários cabem no cartão.
///
/// Seis: uma lista maior deixa de ser convite e vira grade de agenda, e uma
/// agenda vazia divulgada não convida ninguém.
const _limit = 6;

/// O fundo do cartaz.
///
/// Fora da tela: o arquivo exportado é achatado sobre ele, e o fundo do PNG
/// tem que ser o mesmo que o olho viu na prévia.
const Color _ground = AppColors.lightFill;

/// Os horários livres do dia escolhido, prontos para divulgar.
///
/// Medidos pelo serviço mais curto do catálogo: o cartão anuncia que há
/// horário, e não promete que o platinado de uma hora e meia cabe nele — quem
/// confirma é o barbeiro, na conversa.
///
/// Vazio quando não há nada para oferecer, e é isso que esconde o botão: não
/// existe divulgar dia cheio.
final StreamProvider<List<DateTime>> slotsToAdvertiseProvider =
    StreamProvider.autoDispose<List<DateTime>>((ref) {
      final agenda = ref.watch(dayAgendaProvider).value;
      // O mesmo catalogo que a tela de marcar usa: produto nao tem duracao,
      // e horario se mede em servico.
      final bookable = ref.watch(bookableServicesProvider).value;
      final step = ref.watch(slotStepProvider).value ?? SlotRules.step;

      if (agenda == null || bookable == null || bookable.isEmpty) {
        return Stream.value(const []);
      }

      final shortest = bookable
          .map((item) => item.duration)
          .reduce((a, b) => a < b ? a : b);

      final starts = availableStarts(
        agenda.slots,
        shortest,
        step: step,
        // Horário que já passou não se vende.
        notBefore: DateTime.now(),
      );

      return Stream.value(starts.take(_limit).toList());
    });

/// Divulgar os horários que sobraram no dia.
///
/// É o que o barbeiro já faz digitando no status: "hoje ainda tenho 16:30".
/// Aqui sai uma imagem pronta, que ele joga no Stories ou no WhatsApp.
///
/// Imagem, e não texto, porque o lugar onde isso funciona é o Stories — e
/// Stories não aceita texto solto de outro app.
///
/// Nada de API do Instagram: publicar na conta de alguém exige conta Business,
/// página no Facebook e revisão da Meta. O compartilhar do Android resolve, e
/// quem escolhe onde postar é quem posta.
class ShareSlotsScreen extends StatefulWidget {
  const new({required this.day, required this.hours, super.key});

  final DateTime day;

  /// Os horários livres, já filtrados e cortados por quem chamou.
  final List<DateTime> hours;

  static Future<void> show(
    BuildContext context, {
    required DateTime day,
    required List<DateTime> hours,
  }) {
    return openTask(context, (_) => ShareSlotsScreen(day: day, hours: hours));
  }

  @override
  State<ShareSlotsScreen> createState() => _ShareSlotsScreenState();
}

class _ShareSlotsScreenState extends State<ShareSlotsScreen> {
  /// Onde a imagem é recortada da tela.
  ///
  /// O cartão fica **visível** de propósito: gerar escondido exigiria montar
  /// uma árvore fora da tela só para tirar a foto, e o que se ganha de graça
  /// é ver o que vai ser postado antes de postar.
  final GlobalKey _poster = GlobalKey();
  bool _sharing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TaskBar(title: 'Divulgar horário'),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.screenGutter),
          child: AspectRatio(
            // 4:5, e não o 9:16 do Stories.
            //
            // O WhatsApp corta pelo meio a imagem alta demais na bolha da
            // conversa: em 9:16 o primeiro e o último horário sumiam, e só
            // apareciam abrindo a imagem. 4:5 é o retrato mais alto que passa
            // inteiro na conversa, no status e no Stories — lá ele não enche a
            // tela toda, e é o preço certo a pagar.
            aspectRatio: 4 / 5,
            child: RepaintBoundary(
              key: _poster,
              child: _Poster(day: widget.day, hours: widget.hours),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAction(
        // Dois destinos, dois botões. O Stories só aceita imagem; a conversa
        // de um para um pede texto, que o cliente copia e responde citando.
        // Um botão só obrigaria a escolher errado metade das vezes.
        //
        // Empilhados, e não lado a lado: em dois botões numa linha só, "Mandar
        // imagem" quebrava em duas linhas. A imagem manda porque é ela que
        // está desenhada logo acima.
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: _sharing ? null : () => unawaited(_share()),
              child: _sharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Mandar imagem'),
            ),
            TextButton(
              onPressed: _sharing ? null : _shareText,
              child: const Text('Mandar só o texto'),
            ),
          ],
        ),
      ),
    );
  }

  /// O mesmo desenho, sem um pingo de transparência.
  ///
  /// A borda do recorte cai em pixel quebrado, e a última coluna sai meio
  /// transparente. WhatsApp e Instagram pintam transparência de preto — era
  /// dali que vinha o fio escuro na lateral do cartaz. Desenhar por cima de um
  /// fundo cheio resolve de uma vez, sem depender de a conta dar redonda.
  Future<ui.Image> _onSolidGround(ui.Image shot) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Rect.fromLTWH(
      0,
      0,
      shot.width.toDouble(),
      shot.height.toDouble(),
    );

    canvas
      ..drawRect(size, Paint()..color = _ground)
      ..drawImage(shot, Offset.zero, Paint());

    final picture = recorder.endRecording();
    final flat = await picture.toImage(shot.width, shot.height);
    picture.dispose();
    return flat;
  }

  /// Manda a frase pela folha do Android: de lá ele escolhe a conversa, e o
  /// "Copiar" do topo ainda atende quem vai colar em outro lugar.
  void _shareText() {
    unawaited(
      SharePlus.instance.share(
        ShareParams(
          text: freeSlotsMessage(
            day: widget.day,
            hours: widget.hours,
            now: DateTime.now(),
          ),
        ),
      ),
    );
  }

  Future<void> _share() async {
    setState(() => _sharing = true);

    try {
      final boundary =
          _poster.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      // 3x: o cartão na tela tem uns 300 de largura, e o Stories quer 1080.
      final shot = await boundary.toImage(pixelRatio: 3);
      final image = await _onSolidGround(shot);
      shot.dispose();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      final folder = await getTemporaryDirectory();
      final file = File('${folder.path}/horarios.png');
      await file.writeAsBytes(bytes!.buffer.asUint8List());

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'image/png')]),
      );

      if (!mounted) return;
      setState(() => _sharing = false);
    } on Object {
      if (!mounted) return;
      setState(() => _sharing = false);
      showSnack(context, 'Não consegui gerar a imagem.');
    }
  }
}

/// O cartão que vai para o Stories.
///
/// Assinado com o @ da barbearia, quando ele existe. No Stories da própria
/// conta a assinatura é redundante — mas a imagem é encaminhada, cai em grupo
/// e é salva na galeria, e aí ela é a única coisa que diz de quem é e onde
/// achar. Em branco, o rodapé simplesmente não tem a linha.
///
/// **A hora é o desenho.** Nada de ícone, fio ou moldura: no meio das fotos
/// do Stories, o que para o dedo é uma coisa grande e mais nada. Foi assim
/// que o vazio sumiu — não preenchendo o buraco com enfeite, mas deixando o
/// conteúdo ocupar o cartão.
///
/// **Cores fixas, e não as do tema.** Isto vira um arquivo que sai do
/// aparelho: a imagem postada não pode depender de o celular estar no modo
/// escuro naquela hora, senão o mesmo botão gera cartaz claro hoje e escuro
/// amanhã.
class _Poster extends ConsumerWidget {
  const new({required this.day, required this.hours});

  final DateTime day;
  final List<DateTime> hours;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final shop =
        ref.watch(shopProfileProvider).value ?? const ShopProfile.unknown();
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final label = '${formatShortWeekday(day)} ${day.day}'.toUpperCase();

    // Invertido: preto, com as horas em branco.
    //
    // Claro, o cartão sumia — ficava da cor da tela, e não dava para ver o que
    // ia ser postado. E no Stories, no meio de foto, é o preto que para o
    // dedo. É o mesmo preto do botão de marcar: a voz do app.
    const ink = AppColors.lightInk;
    const soft = AppColors.lightInkSoft;

    // Canto reto, e não arredondado como os cartões do app.
    //
    // O que sai daqui é um arquivo. Arredondar deixa os quatro cantos
    // transparentes no PNG, e WhatsApp e Instagram pintam transparência de
    // preto — o cartaz chegava com quatro cunhas pretas em volta. Reto, a
    // prévia também passa a ser exatamente o que vai ser postado.
    return ColoredBox(
      color: _ground,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // A data à esquerda, a assinatura à direita: a linha de cima
            // estava com metade vazia, e é lá que uma marca costuma morar num
            // cartaz. Junto do convite ela espremia o "Chama no WhatsApp" e
            // estouraria com um @ comprido.
            Row(
              children: [
                Text(
                  isToday ? 'HOJE · $label' : label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: soft,
                    letterSpacing: 2,
                  ),
                ),
                if (shop.signature.isNotEmpty) ...[
                  const SizedBox(width: Dimens.gapMedium),
                  Expanded(
                    child: Text(
                      shop.signature,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(color: soft),
                    ),
                  ),
                ],
              ],
            ),
            // Um respiro em cima e outro embaixo: coladas na etiqueta e na
            // frase, as horas pareciam espremidas em vez de grandes.
            const SizedBox(height: Dimens.gapMedium),
            Expanded(
              // As horas crescem até encostar nas bordas do que sobrou.
              //
              // Escala geométrica, e não um tamanho novo: o estilo continua
              // sendo o do tema, e um horário só sai enorme enquanto seis
              // saem grandes. Era isto que faltava — no tamanho de tela, seis
              // numeros pequenos num cartao de retrato deixam metade dele
              // vazia, e vazio num cartaz parece erro.
              child: FittedBox(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final hour in hours)
                      Text(
                        formatHour(hour),
                        style: theme.textTheme.displayLarge?.copyWith(
                          color: ink,
                          height: 1.1,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Dimens.gapMedium),
            Text(
              hours.length == 1 ? 'Tenho um horário.' : 'Tenho horário.',
              style: theme.textTheme.bodyLarge?.copyWith(color: ink),
            ),
            Text(
              'Chama no WhatsApp',
              style: theme.textTheme.bodyLarge?.copyWith(color: soft),
            ),
          ],
        ),
      ),
    );
  }
}
