# HealthFit_Android

Cliente **nativo Android** do HealthFit (paridade fiel com o app iOS), usando:

| Camada | Tecnologia |
|--------|------------|
| Phone UI | Kotlin + Jetpack Compose |
| Watch | Wear OS (Galaxy Watch 4+) |
| Design | Módulo `:designsystem` (cores/cards = iOS `AppTheme`) |
| Backend | Firebase **shared** (`healthfit-30d87`) — **sem deploy de rules/Functions daqui** |
| Saúde | Health Connect (+ Samsung Health SDK nas fases avançadas) |
| Assinaturas | Google Play Billing |

## Módulos

```
HealthFit_Android/
  app/            # telefone
  wear/           # Galaxy Watch / Wear OS
  core/           # auth, health, billing, workouts, firebase helpers
  designsystem/   # tema + HealthFitCard / PrimaryButton
  docs/           # segurança Firebase
  ROADMAP.md      # fases
```

## Abrir no Android Studio

1. Instale Android Studio (Ladybug+) + JDK 17.
2. **File → Open** → pasta `HealthFit_Android`.
3. Copie `local.properties.example` → `local.properties` e ajuste `sdk.dir`.
4. No Firebase Console, adicione o app Android `com.healthfit.android` e coloque `app/google-services.json` (veja `docs/FIREBASE_SAFETY.md`). **Não altere rules.**
5. Sync Gradle e rode `app` num emulador/device API 28+.

O plugin Google Services só aplica se `app/google-services.json` existir.

## Segurança iOS

Este diretório **não publica** nada no Firebase. O app iOS em produção não é afetado por este scaffold.  
Writes de sessão de treino na nuvem estão **desligados** na Fase 1.

## Relógio Samsung

Target Wear OS (`:wear`). Tizen não é suportado (Watch4+ = Wear OS).
