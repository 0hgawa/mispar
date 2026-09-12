import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/data/shop_settings_repository.dart';
import 'package:marcos_barber/src/features/agenda/domain/day_schedule.dart';
import 'package:marcos_barber/src/features/agenda/domain/shop_hours.dart';
import 'package:marcos_barber/src/features/agenda/presentation/day_view_model.dart';
import 'package:marcos_barber/src/features/booking/presentation/new_appointment_view_model.dart';
import 'package:marcos_barber/src/shared/formatters/day_time.dart';
import 'package:marcos_barber/src/shared/task_route.dart';
import 'package:marcos_barber/src/shared/widgets/app_snack.dart';
import 'package:marcos_barber/src/shared/widgets/bottom_action.dart';
import 'package:marcos_barber/src/shared/widgets/task_bar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Quantos horários cabem no cartão.
///
/// Seis: uma lista maior deixa de ser convite e vira grade de agenda, e uma
/// agenda vazia divulgada não convida ninguém.
const _limit = 6;

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
            // Retrato de Stories. Postado fora dele, continua cabendo.
            aspectRatio: 9 / 16,
            child: RepaintBoundary(
              key: _poster,
              child: _Poster(day: widget.day, hours: widget.hours),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomAction(
        child: FilledButton(
          onPressed: _sharing ? null : () => unawaited(_share()),
          child: _sharing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Compartilhar'),
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
      final image = await boundary.toImage(pixelRatio: 3);
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
/// Sem nome nem logo da barbearia: ele sai na conta dela, e a conta já diz de
/// quem é. Repetir ali seria assinar a própria carta duas vezes.
class _Poster extends StatelessWidget {
  const new({required this.day, required this.hours});

  final DateTime day;
  final List<DateTime> hours;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;

    // Invertido: preto, com as horas em branco.
    //
    // Claro, o cartão sumia — ficava da cor da tela, e não dava para ver o que
    // ia ser postado. E no Stories, no meio de foto, é o preto que para o
    // dedo. É o mesmo preto do botão de marcar: a voz do app.
    final ink = colors.onSurface;
    final paper = colors.surface;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: ink,
        borderRadius: BorderRadius.circular(Dimens.cardRadius * 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isToday ? 'HOJE' : formatShortWeekday(day).toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: paper.withValues(alpha: 0.6),
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hours.length == 1 ? 'Tenho um horário' : 'Tenho horário',
              style: theme.textTheme.headlineMedium?.copyWith(color: paper),
            ),
            // Entre o título e a hora, e entre a hora e o convite, o mesmo
            // vazio: a hora fica no meio do cartão, que é onde o olho cai.
            // Empilhada no topo, sobrava um buraco embaixo.
            const Spacer(),
            for (final hour in hours) ...[
              Text(
                formatHour(hour),
                style: theme.textTheme.displayMedium?.copyWith(
                  color: paper,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
            ],
            const Spacer(),
            Text(
              'Chama no WhatsApp',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: paper.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
