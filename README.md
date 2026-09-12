# Mispar

Agenda e gestão para barbearia. Agendamento pelo WhatsApp, sem mensalidade.

- **O produto e as decisões:** [PROJETO.md](PROJETO.md)
- **A arquitetura do app:** [docs/ARQUITETURA.md](docs/ARQUITETURA.md)

## Rodar

```bash
cd app
flutter run --dart-define-from-file=config/dev.json
```

Antes do primeiro run, preencha `config/dev.json` (copie de `config/example.json`)
com a URL e a publishable key do projeto Supabase.

## Comandos

| | |
|---|---|
| `flutter analyze` | Lint — tem que sair zero |
| `flutter test` | Testes |
| `dart format .` | Formatação (a CI reprova se estiver fora) |
| `dart run build_runner watch -d` | Codegen do Riverpod, Freezed e Drift |
| `flutter build appbundle --dart-define-from-file=config/prod.json` | Release Android |

## Ambiente desta máquina

| | |
|---|---|
| Flutter | 3.47.3 stable · `E:\flutter` |
| Dart | 3.13.3 |
| JDK | Temurin 21 · `E:\jdk21\jdk-21.0.12.1+1` |
| Android SDK | 37.0.0 · `%LOCALAPPDATA%\Android\Sdk` |
| Pub cache | `E:\pub-cache` — veja o porquê abaixo |

## Armadilhas desta máquina

**`PUB_CACHE` tem que ficar no mesmo drive do projeto.** O padrão fica em
`%LOCALAPPDATA%\Pub\Cache`, no `C:`. Com o projeto no `E:`, a compilação
incremental do Kotlin quebra: ela calcula o caminho relativo entre os fontes do
plugin e o projeto, e `relativeTo()` estoura quando os drives são diferentes
(`this and base files have different roots`). Resolvido — `PUB_CACHE` aponta
para `E:\pub-cache`.

**Desugaring desligado.** Estava ligado só por causa do
`flutter_local_notifications`, que saiu do projeto sem nunca ter sido usado.
Se um dia entrar lembrete agendado no celular, volta o
`isCoreLibraryDesugaringEnabled` e a dependência `desugar_jdk_libs` no
`android/app/build.gradle.kts`.

## iOS

Windows não compila iOS — é limitação da Apple, não do Flutter. A pasta `ios/`
já existe e o job `ios` da CI compila num runner macOS do GitHub Actions
(2.000 min/mês grátis, mas minuto de macOS conta 10x). Publicar na App Store
exige a conta de dev da Apple: **US$ 99/ano**.

## Pendências conhecidas

- **Push:** `firebase_messaging` entra quando o projeto Firebase existir — sem
  o `google-services.json` o build Android quebra, então ficou de fora agora.
- **`riverpod_lint`:** trava o `riverpod` em 3.1.0 e o runtime já está em 3.4.3.
  Entra quando alcançar.
