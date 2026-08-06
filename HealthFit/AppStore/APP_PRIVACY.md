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

### Diagnostics (se Firebase Analytics/Crashlytics estiver ativo)
| Tipo | Coleta | Vinculado | Tracking | Finalidade |
|------|--------|-----------|----------|------------|
| Crash Data | Sim* | Não / Sim conforme config | Não | Analytics / App Functionality |
| Performance Data | Sim* | Não | Não | Analytics |

\*Confirme no Firebase Console se Analytics/Crashlytics estão ligados no build de release. Se não, não declare.

## NÃO declarar
- Advertising Data
- Precise Location for ads (location is only for workout maps — se Connect perguntar Location, marque **Precise Location** com finalidade **App Functionality**, não tracking)
- Purchases history as sold to third parties

## Privacy Policy URL
`https://berglimma.github.io/HealhtFit/privacidade/`

## Account deletion
Disponível em **Perfil → Excluir conta** (obrigatório Guideline 5.1.1(v)).
