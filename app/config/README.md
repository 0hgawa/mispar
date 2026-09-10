# config/

Valores injetados no build, nao no codigo:

```
flutter run   --dart-define-from-file=config/dev.json
flutter build appbundle --dart-define-from-file=config/prod.json
```

`dev.json` e `prod.json` sao ignorados pelo git. Copie de `example.json`.

A `SUPABASE_PUBLISHABLE_KEY` e publica por design — quem protege os dados e a RLS
no Postgres. A `service_role` **nunca** entra no app: ela vive so em edge
function.
