import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marcos_barber/src/core/theme/app_colors.dart';
import 'package:marcos_barber/src/features/agenda/data/shop_settings_repository.dart';
import 'package:marcos_barber/src/features/settings/domain/shop_profile.dart';
import 'package:marcos_barber/src/shared/links.dart';
import 'package:marcos_barber/src/shared/widgets/app_snack.dart';
import 'package:marcos_barber/src/shared/widgets/page_bar.dart';
import 'package:marcos_barber/src/shared/widgets/screen_title.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:share_plus/share_plus.dart';

/// O cadastro da barbearia.
///
/// Não é perfil de usuário: não há login nem conta, e o app inteiro é de uma
/// pessoa só. O que falta em Ajustes é o cadastro do negócio.
///
/// Só entra campo que alguma coisa lê — nome e @ assinam o cartaz de divulgar
/// horário, e o endereço abre o mapa e vira mensagem pronta. Guardar dado que
/// ninguém consome é formulário para o Marcos preencher à toa.
class ShopScreen extends ConsumerStatefulWidget {
  const new({super.key});

  @override
  ConsumerState<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends ConsumerState<ShopScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _instagram = TextEditingController();

  /// O que já veio do banco, para não gravar o que não mudou e para não
  /// atropelar o que está sendo digitado a cada emissão do fluxo.
  ShopProfile _saved = const ShopProfile.unknown();
  bool _filled = false;

  /// Guardado na entrada, e não lido na hora de gravar.
  ///
  /// A última gravação acontece quando o campo perde o foco, e sair da tela é
  /// exatamente isso: o `ref` já morreu quando a hora chega. Lendo o
  /// repositório ali, o que se ganhava era uma exceção no meio do desmonte —
  /// e a aba inteira de Ajustes ficava em branco até reabrir o app.
  late final ShopSettingsRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(shopSettingsRepositoryProvider);
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _instagram.dispose();
    super.dispose();
  }

  /// Grava ao sair do campo, e não a cada tecla.
  ///
  /// Sem botão de salvar: a tela é de ajuste, e ajuste que precisa de
  /// confirmação é ajuste que fica pela metade quando o telefone toca. A cada
  /// tecla seriam dez escritas para digitar um nome, e o @ ficaria gravado
  /// pela metade enquanto se digita.
  Future<void> _save(ShopProfile shop) async {
    if (shop.name == _saved.name &&
        shop.address == _saved.address &&
        shop.instagram == _saved.instagram) {
      return;
    }

    // Fora do `mounted`: gravar é o que tem que acontecer justamente quando a
    // tela está indo embora.
    try {
      await _repository.saveProfile(shop);
      _saved = shop;
    } on Object {
      if (!mounted) return;
      showSnack(context, 'Não consegui salvar.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final shop =
        ref.watch(shopProfileProvider).value ?? const ShopProfile.unknown();

    // Uma vez só, quando o banco responde: depois disso quem manda nos campos
    // é quem está digitando.
    if (!_filled && ref.watch(shopProfileProvider).hasValue) {
      _filled = true;
      _saved = shop;
      _name.text = shop.name;
      _address.text = shop.address;
      _instagram.text = shop.instagram;
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          const PageBar(title: 'A barbearia'),
          const SliverToBoxAdapter(
            child: PageSubtitle('o que o cliente precisa saber'),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(bottom: Dimens.gapLarge),
            sliver: SliverList.list(
              children: [
                const _Why(),
                const SectionLabel('Nome'),
                _Field(
                  controller: _name,
                  hint: 'Marcos Barbearia',
                  icon: Symbols.storefront_rounded,
                  capitalize: true,
                  onDone: (text) => _save(_saved.copyWith(name: text.trim())),
                ),
                const SectionLabel('Endereço'),
                _Field(
                  controller: _address,
                  hint: 'Rua e número, bairro',
                  icon: Symbols.location_on_rounded,
                  capitalize: true,
                  onDone: (text) =>
                      _save(_saved.copyWith(address: text.trim())),
                ),
                if (shop.address.isNotEmpty) _SendAddress(shop: shop),
                const SectionLabel('Instagram'),
                _Field(
                  controller: _instagram,
                  hint: '@suabarbearia',
                  icon: Symbols.alternate_email_rounded,
                  onDone: (text) {
                    // Limpo na entrada: aceita `@marcos`, `marcos` e o link
                    // do perfil inteiro, e o campo passa a mostrar o que foi
                    // realmente guardado.
                    final handle = readHandle(text);
                    if (mounted) _instagram.text = handle;
                    return _save(_saved.copyWith(instagram: handle));
                  },
                ),
                if (shop.instagram.isNotEmpty) _OpenProfile(shop: shop),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Why extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        0,
        Dimens.screenGutter,
        Dimens.gapSmall,
      ),
      child: Text(
        'O nome e o @ assinam a imagem de divulgar horário — sem eles, quem '
        'receber encaminhada não sabe de quem é. O endereço vira mensagem '
        'pronta para mandar no WhatsApp.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Mandar o endereço para um cliente.
///
/// Um botão só, e de largura cheia como todos os outros do app. Não há
/// "ver no mapa": o barbeiro sabe onde fica a própria barbearia, e o link do
/// mapa já viaja dentro da mensagem, para quem precisa dele.
class _SendAddress extends StatelessWidget {
  const new({required this.shop});

  final ShopProfile shop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        Dimens.gapSmall,
        Dimens.screenGutter,
        0,
      ),
      child: OutlinedButton.icon(
        onPressed: () => unawaited(
          SharePlus.instance.share(ShareParams(text: shopAddressMessage(shop))),
        ),
        icon: const Icon(Symbols.send_rounded, size: 18, weight: 500),
        label: const Text('Mandar endereço'),
      ),
    );
  }
}

/// Abrir o perfil, que é como se confere que o @ está certo.
class _OpenProfile extends StatelessWidget {
  const new({required this.shop});

  final ShopProfile shop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Dimens.screenGutter,
        Dimens.gapSmall,
        Dimens.screenGutter,
        0,
      ),
      child: OutlinedButton.icon(
        onPressed: () => unawaited(_open(context)),
        icon: const Icon(Symbols.open_in_new_rounded, size: 18, weight: 500),
        label: Text('Abrir @${shop.instagram}'),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final opened = await openLink(instagramUri(shop.instagram));
    if (opened || !context.mounted) return;
    showSnack(context, 'Não consegui abrir o Instagram.');
  }
}

/// O mesmo campo do cadastro de cliente.
class _Field extends StatelessWidget {
  const new({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.onDone,
    this.capitalize = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;

  /// Chamado ao sair do campo e ao tocar em "concluído" no teclado.
  final Future<void> Function(String text) onDone;
  final bool capitalize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Dimens.screenGutter),
      child: Focus(
        // Sair do campo grava. É o gesto que já acontece — tocar no próximo
        // campo, fechar o teclado, voltar — e não um botão a mais.
        onFocusChange: (hasFocus) {
          if (!hasFocus) unawaited(onDone(controller.text));
        },
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.done,
          onSubmitted: (text) => unawaited(onDone(text)),
          textCapitalization: capitalize
              ? TextCapitalization.words
              : TextCapitalization.none,
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
            prefixIcon: Icon(icon, weight: 500, color: colors.onSurfaceVariant),
            filled: true,
            fillColor: colors.secondaryContainer,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(Dimens.pillRadius),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
    );
  }
}
