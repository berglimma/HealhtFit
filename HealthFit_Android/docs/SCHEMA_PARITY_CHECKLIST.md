# Schema parity checklist (before any Firestore write from Android)

Do **not** enable cloud writes until each row is verified against the current iOS encoder/decoder.

| Feature | iOS type / path | Android status |
|---------|-----------------|----------------|
| Auth profile | `users/{uid}` | Auth only (Phase 1) |
| Workout sessions | `users/{uid}/workoutSessions/{id}` | **Local only** |
| Workout sheets | local + optional cloud | Local catalog |
| Meal plan (user) | `users/{uid}/mealPlan` | Phase 2 — no write |
| Coach links | `coachLinks/{id}` | **Read-only** via `CoachCloudRepository` |
| Assigned workouts | `coachLinks/.../assignedWorkouts` | **Read-only** |
| Coach meal plan | `coachLinks/.../mealPlan/current` | **Read-only** |
| Nutrition care publish | `coachLinks/.../nutritionCare` | **Blocked** (`WRITES_HARD_DISABLED`) |
| Coach chat / invite accept | messages / invites | **Blocked** (writes) |
| Consultations | existing coach paths | Later |
| Pulse posts | `pulsePosts` (+ Storage) | Phase 4 |
| Duo teams | `duoTeams/{id}` | Later |
| `appConfig/android` | remote flags | **Read-only** |

When enabling a write: compare field names/types with the Swift `Codable` model, write an instrumented integration test, flip `CoachCloudGates.WRITES_HARD_DISABLED` only after dual-platform review, and keep `coachCloudWriteEnabled: false` until ready.
