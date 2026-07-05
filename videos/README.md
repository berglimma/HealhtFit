# Vídeos demonstrativos — HealthFit

Coloque os arquivos MP4 nestas pastas antes de rodar o script de upload.

## Grupos musculares (obrigatório)

Pasta: `videos/groups/`

| Arquivo local | Destino no Storage |
|---------------|-------------------|
| `peito.mp4` | `exerciseVideos/groups/peito.mp4` |
| `costas.mp4` | `exerciseVideos/groups/costas.mp4` |
| `pernas.mp4` | `exerciseVideos/groups/pernas.mp4` |
| `ombros.mp4` | `exerciseVideos/groups/ombros.mp4` |
| `bracos.mp4` | `exerciseVideos/groups/bracos.mp4` |
| `abdomen.mp4` | `exerciseVideos/groups/abdomen.mp4` |
| `corpo_inteiro.mp4` | `exerciseVideos/groups/corpo_inteiro.mp4` |

## Exercícios individuais (opcional)

Pasta: `videos/exercises/`

Nomeie cada arquivo com o slug do exercício, por exemplo:

- `supino-reto.mp4` → `exerciseVideos/exercises/supino-reto.mp4`
- `agachamento-livre.mp4` → `exerciseVideos/exercises/agachamento-livre.mp4`

O slug segue a mesma regra de `ExerciseVideoRecord.slug(for:)` no app.

## Upload

```bash
chmod +x scripts/upload_exercise_videos.sh
./scripts/upload_exercise_videos.sh
```

Pré-requisitos: [Google Cloud SDK](https://cloud.google.com/sdk/docs/install) (`gcloud` ou `gsutil`) e login:

```bash
gcloud auth login
gcloud config set project healthfit-30d87
```
