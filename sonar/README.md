# HealthFit · SonarQube local

Colima (Docker) precisa estar ligado — neste Mac não há Docker Desktop:

```bash
colima start
./sonar/scripts/up.sh
```

Portal: **http://127.0.0.1:9040**  
SonarQube: **http://127.0.0.1:9000/dashboard?id=healthfit**

Login local (após `up` limpo): `admin` / `HealthFitSonar1!`  
(Se for a 1ª subida sem reset, use `admin`/`admin` e troque a senha.)

## Analisar

```bash
export SONAR_PASSWORD='HealthFitSonar1!'
./sonar/scripts/scan.sh
```


## Analisar

```bash
./sonar/scripts/scan.sh
```

Depois abra o portal em http://localhost:9040 (Quality Gate, vulnerabilidades, issues).

## Parar

```bash
./sonar/scripts/down.sh
```

## O que é analisado

| Área | Engine Community |
|------|------------------|
| `functions/src` (TypeScript) | Sim |
| `Docs/` (HTML) | Sim |
| `firestore.rules` / `storage.rules` | Texto |
| Swift (`HealthFit/...`) | Inventário limitado — análise profunda = Developer Edition / SonarCloud |

## Hardening alinhado ao Sonar (já aplicado)

- Segredos de seed (`COURTESY_SEED_KEY`) e OAuth CLI fora do código (env)
- Spotify client secret no Keychain (não UserDefaults)
- Remoção de `fatalError` / `as!` em pontos sensíveis
- Scripts de cortesia/demo exigem env

Defina localmente (nunca commit):

```bash
export COURTESY_SEED_KEY='…'
export FIREBASE_TOOLS_CLIENT_SECRET='…'
```

No deploy das Cloud Functions, configure `COURTESY_SEED_KEY` no ambiente/Secret Manager do Cloud Functions.
