# Schema parity checklist (before any Firestore write from Android)

Do **not** enable cloud writes until each row is verified against the current iOS encoder/decoder.

| Feature | iOS type / path | Android status |
|---------|-----------------|----------------|
| Auth profile | `users/{uid}` | Auth only (Phase 1) |
| Workout sessions | `users/{uid}/workoutSessions/{id}` | **Local only** |
| Workout sheets | local + optional cloud | Local catalog |
| Meal plan | `users/{uid}/mealPlan` | Phase 2 |
| Coach links | `coachLinks/{id}` | Phase 2 |
| Consultations | existing coach paths | Phase 2 |
| Pulse posts | `pulsePosts` (+ Storage) | Phase 4 |
| Duo teams | `duoTeams/{id}` | Later |

When enabling a write: compare field names/types with the Swift `Codable` model, write an instrumented integration test, and ship behind a remote flag if needed.
