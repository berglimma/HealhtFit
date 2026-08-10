# App Privacy — questionário App Store Connect

Marque apenas o que o app realmente coleta. Base: `privacy_notes.txt` + Firebase + HealthKit + fotos.

## Data Types

### Contact Info
| Tipo | Coleta | Vinculado ao usuário | Usado para tracking | Finalidade |
|------|--------|----------------------|---------------------|------------|
| Email Address | Sim | Sim | Não | App Functionality, Account |
| Name | Sim | Sim | Não | App Functionality |

### Health & Fitness
| Tipo | Coleta | Vinculado | Tracking | Finalidade |
|------|--------|-----------|----------|------------|
| Health | Sim (HealthKit com permissão) | Sim | Não | App Functionality |
| Fitness | Sim (treinos, passos, FC) | Sim | Não | App Functionality |

### User Content
| Tipo | Coleta | Vinculado | Tracking | Finalidade |
|------|--------|-----------|----------|------------|
| Photos or Videos | Sim (perfil / evolução, opcional) | Sim | Não | App Functionality |
| Other User Content | Sim (check-ins, notas) | Sim | Não | App Functionality |

### Identifiers
| Tipo | Coleta | Vinculado | Tracking | Finalidade |
|------|--------|-----------|----------|------------|
| User ID | Sim (Firebase Auth uid) | Sim | Não | App Functionality |
| Device ID / session (logs Marco Civil) | Sim (sessionId + IP quando disponível) | Sim | Não | App Functionality (obrigação legal — retenção 6 meses) |

### Diagnostics (Firebase Analytics / Crashlytics ativos no app)
| Tipo | Coleta | Vinculado | Tracking | Finalidade |
|------|--------|-----------|----------|------------|
| Crash Data | Sim | Sim (User ID opcional) | Não | App Functionality |
| Performance Data | Sim | Não | Não | Analytics |
| Product Interaction | Sim (eventos de funil: login, paywall, purchase, workout) | Sim | Não | Analytics / App Functionality |

Declare Crash Data + Product Interaction. **Não** marque como tracking (sem IDFA / ads).

## NÃO declarar
- Advertising Data
- Precise Location for ads (location is only for workout maps — se Connect perguntar Location, marque **Precise Location** com finalidade **App Functionality**, não tracking)
- Purchases history as sold to third parties

## Privacy Policy URL
`https://berglimma.github.io/HealhtFit/privacidade/`

## Account deletion
Disponível em **Perfil → Excluir conta** (obrigatório Guideline 5.1.1(v)). Apaga Auth, Firestore (perfil, treinos, wellness, meal plan, evolução corporal) e Storage do usuário.