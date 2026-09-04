# App Privacy — questionário App Store Connect

Marque apenas o que o app realmente coleta. Base: `privacy_notes.txt` + Firebase + HealthKit + fotos + Kite Spot Buddy.

**Privacy Policy URL (obrigatório):** `https://healthfit-30d87.web.app/privacidade/`

## Data Types

### Contact Info
| Tipo | Coleta | Vinculado ao usuário | Usado para tracking | Finalidade |
|------|--------|----------------------|---------------------|------------|
| Email Address | Sim | Sim | Não | App Functionality, Account |
| Name | Sim | Sim | Não | App Functionality |

### Location
| Tipo | Coleta | Vinculado | Tracking | Finalidade |
|------|--------|-----------|----------|------------|
| Precise Location | Sim | Sim | Não | App Functionality |

**Quando / por quê:** mapa e rota em sessões outdoor ativas (corrida, caminhada, bike, surf, kitesurf etc.) e, com opt-in, **Kite Spot Buddy** (compartilhamento temporário com amigos da equipe só durante kitesurf). **Não** usar para ads / tracking.

### Health & Fitness
| Tipo | Coleta | Vinculado | Tracking | Finalidade |
|------|--------|-----------|----------|------------|
| Health | Sim (HealthKit com permissão) | Sim | Não | App Functionality |
| Fitness | Sim (treinos, passos, FC) | Sim | Não | App Functionality |

### User Content
| Tipo | Coleta | Vinculado | Tracking | Finalidade |
|------|--------|-----------|----------|------------|
| Photos or Videos | Sim (perfil / evolução, opcional) | Sim | Não | App Functionality |
| Other User Content | Sim (check-ins, notas, chat Duo) | Sim | Não | App Functionality |

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
- Location para ads
- Purchases history as sold to third parties

## Account deletion
Disponível em **Perfil → Excluir conta** (Guideline 5.1.1(v)). Apaga Auth, Firestore (perfil, treinos, wellness, meal plan, evolução, presença Spot Buddy) e Storage do usuário.
