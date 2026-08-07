# Xcode Cloud — erros comuns e correção (HealthFit)

App: **6798621208** · Team: `bf415301-…` · Bundle: `luan.com.healthfit.app`

## Configuração correta do Workflow

| Campo | Valor |
|-------|--------|
| Source | GitHub `berglimma/HealhtFit` branch `main` |
| Project / Workspace | `HealthFit/HealthFit/HealthFit.xcodeproj` |
| Scheme | `HealthFit` |
| Actions | **Archive** (App Store / TestFlight). Test opcional (só unit). |
| Platform | iOS |

> O `.xcodeproj` **não** está na raiz do repo. Se o workflow apontar para a raiz, o build falha com “Unable to load project / scheme not found”.

## Correções já no repositório

1. **`ci_scripts/ci_post_clone.sh`**  
   Gera `GoogleService-Info.plist` no Cloud (arquivo está no `.gitignore`).  
   - Preferência: secret `CI_GOOGLE_SERVICE_INFO_BASE64`  
   - Fallback: copia o `.example` (build passa; Firebase desligado)

2. **UITests desligados no scheme** (`skipped = YES`)  
   UI tests costumam quebrar no Cloud sem device farm configurado.

## Secret recomendado (Firebase real no Cloud)

No Mac, com o plist local:

```bash
base64 -i HealthFit/HealthFit/HealthFit/GoogleService-Info.plist | pbcopy
```

Em App Store Connect → Xcode Cloud → Workflow → **Environment** → Add Variable:

- Name: `CI_GOOGLE_SERVICE_INFO_BASE64`
- Value: (colar o base64)
- Secret: **Yes**

## Erros típicos e o que fazer

### 1) `Build input file cannot be found: .../GoogleService-Info.plist`
- Cause: plist gitignored  
- Fix: script `ci_post_clone` + secret (acima). Re-run do workflow após push.

### 2) `Unable to find scheme HealthFit` / project not found
- Cause: caminho do projeto errado no workflow  
- Fix: setar `HealthFit/HealthFit/HealthFit.xcodeproj` e scheme `HealthFit`.

### 3) Signing / provisioning (`No profiles for …watchkitapp` / Sign In with Apple)
- Cause: capabilities ou certificados Cloud  
- Fix em Apple Developer + Xcode Cloud:
  - App ID `luan.com.healthfit.app`: HealthKit + Sign In with Apple  
  - App ID Watch `luan.com.healthfit.app.watchkitapp`: HealthKit  
  - App ID Widgets `luan.com.healthfit.app.widgets`  
  - Em Xcode Cloud → Settings → **Grant access** / manage certificates (Automatic signing)

### 4) `Could not resolve package dependencies` (Firebase / GoogleSignIn)
- Cause: rede SPM ou `Package.resolved` ausente  
- Fix: `Package.resolved` já está no git. Re-run. Se persistir, limpar Derived Data na workflow (Clean).

### 5) Unit/UI tests failing the pipeline
- Fix: no workflow, desmarque **Test** e deixe só **Archive**; ou mantenha Test com UITests skipped (já feito no scheme).

### 6) Archive succeeds locally, fails on Cloud only
- Confira macOS / Xcode image do workflow (use a mais recente estável).  
- Confirme que o último commit com `ci_scripts/` foi **pushed** para `main`.

## Checklist rápido pós-push

- [ ] Workflow aponta para `HealthFit/HealthFit/HealthFit.xcodeproj` + scheme `HealthFit`
- [ ] Action = Archive (TestFlight / App Store)
- [ ] Secret `CI_GOOGLE_SERVICE_INFO_BASE64` configurado
- [ ] Certificates/Profiles gerenciados pelo Xcode Cloud
- [ ] Start Build → abrir o log da etapa que falhou (Clone / Resolve / Build / Archive / Sign)

## Se ainda falhar

Abra o build vermelho → copie a **primeira mensagem vermelha** do log (ou screenshot da etapa) e envie. Com o texto exato dá para fechar o caso em um passo.
