package com.healthfit.android.ui.workouts

enum class Muscle { chest, back, legs, shoulders, arms, core, fullBody }

data class WorkoutExercise(
    val name: String,
    val sets: Int,
    val reps: Int,
    val weightKg: Float?,
    val muscle: Muscle,
    val restSeconds: Int = 60,
)

data class WorkoutSheet(
    val title: String,
    val description: String,
    val exercises: List<WorkoutExercise>,
) {
    val minutes: Int
        get() = (exercises.sumOf { it.sets * (40 + it.restSeconds) } / 60).coerceAtLeast(8)
}

private fun ex(name: String, sets: Int, reps: Int, weight: Number?, muscle: Muscle, rest: Int = 75) =
    WorkoutExercise(name, sets, reps, weight?.toFloat(), muscle, rest)

private fun sheet(title: String, description: String, exercises: List<WorkoutExercise>) =
    WorkoutSheet(title, description, exercises)

object WorkoutCatalog {
    val male: List<WorkoutSheet> = listOf(
        sheet(
            "Masculino A — Peito e Tríceps",
            "Hipertrofia de peitoral e tríceps — perfil masculino",
            listOf(
            ex("Supino Reto", 4, 8, 70, Muscle.chest),
            ex("Supino Inclinado", 4, 10, 55, Muscle.chest),
            ex("Supino Declinado", 3, 10, 60, Muscle.chest),
            ex("Crucifixo Reto", 3, 12, 16, Muscle.chest),
            ex("Crossover", 3, 12, 12, Muscle.chest),
            ex("Flexão de Braços", 3, 15, null, Muscle.chest),
            ex("Tríceps Pulley", 4, 10, 30, Muscle.arms),
            ex("Tríceps Testa", 3, 10, 25, Muscle.arms),
            ex("Tríceps Francês", 3, 12, 16, Muscle.arms),
            ex("Mergulho no Banco", 3, 12, null, Muscle.arms),
            ),
        ),
        sheet(
            "Masculino B — Costas e Bíceps",
            "Largura dorsal e bíceps — perfil masculino",
            listOf(
            ex("Barra Fixa", 4, 8, null, Muscle.back),
            ex("Remada Curvada", 4, 8, 60, Muscle.back),
            ex("Puxada Frontal", 4, 10, 50, Muscle.back),
            ex("Remada Unilateral", 3, 10, 26, Muscle.back),
            ex("Pulldown Triângulo", 3, 12, 45, Muscle.back),
            ex("Levantamento Terra", 3, 6, 90, Muscle.fullBody),
            ex("Rosca Direta", 4, 10, 16, Muscle.arms),
            ex("Rosca Martelo", 3, 10, 14, Muscle.arms),
            ex("Rosca Scott", 3, 12, 12, Muscle.arms),
            ex("Rosca Concentrada", 3, 12, 10, Muscle.arms),
            ),
        ),
        sheet(
            "Masculino C — Pernas",
            "Força e volume de membros inferiores — perfil masculino",
            listOf(
            ex("Agachamento Livre", 4, 8, 90, Muscle.legs),
            ex("Leg Press 45°", 4, 10, 180, Muscle.legs),
            ex("Hack Squat", 3, 10, 120, Muscle.legs),
            ex("Cadeira Extensora", 3, 12, 45, Muscle.legs),
            ex("Mesa Flexora", 4, 10, 40, Muscle.legs),
            ex("Stiff", 3, 10, 60, Muscle.legs),
            ex("Afundo", 3, 10, 24, Muscle.legs),
            ex("Panturrilha em Pé", 4, 15, 90, Muscle.legs),
            ex("Panturrilha Sentado", 4, 15, 55, Muscle.legs),
            ),
        ),
        sheet(
            "Masculino D — Ombros e Trapézio",
            "Deltoides e trapézio para estrutura — perfil masculino",
            listOf(
            ex("Desenvolvimento Militar", 4, 8, 45, Muscle.shoulders),
            ex("Desenvolvimento com Halteres", 3, 10, 20, Muscle.shoulders),
            ex("Elevação Lateral", 4, 12, 12, Muscle.shoulders),
            ex("Elevação Frontal", 3, 12, 12, Muscle.shoulders),
            ex("Remada Alta", 4, 10, 35, Muscle.shoulders),
            ex("Encolhimento com Barra", 4, 12, 70, Muscle.back),
            ex("Encolhimento com Halteres", 3, 15, 26, Muscle.back),
            ex("Face Pull", 3, 15, 22, Muscle.back),
            ex("Crucifixo Inverso", 3, 12, 10, Muscle.shoulders),
            ),
        ),
        sheet(
            "Masculino E — Superior Completo",
            "Peito, costas, ombros e braços — hipertrofia de membros superiores",
            listOf(
            ex("Supino Reto", 4, 8, 70, Muscle.chest),
            ex("Supino Inclinado com Halteres", 3, 10, 28, Muscle.chest),
            ex("Puxada Frontal", 4, 10, 50, Muscle.back),
            ex("Remada Curvada", 4, 8, 60, Muscle.back),
            ex("Desenvolvimento com Halteres", 3, 10, 20, Muscle.shoulders),
            ex("Elevação Lateral", 3, 12, 10, Muscle.shoulders),
            ex("Rosca Direta", 3, 10, 16, Muscle.arms),
            ex("Tríceps Pulley", 3, 12, 28, Muscle.arms),
            ),
        ),
        sheet(
            "Masculino F — Inferior Completo",
            "Quadríceps, posteriores, glúteos e panturrilhas — membros inferiores",
            listOf(
            ex("Agachamento Livre", 4, 8, 90, Muscle.legs),
            ex("Leg Press 45°", 4, 10, 180, Muscle.legs),
            ex("Stiff", 4, 8, 70, Muscle.legs),
            ex("Elevação Pélvica (Hip Thrust)", 3, 10, 80, Muscle.legs),
            ex("Afundo Búlgaro", 3, 10, 22, Muscle.legs),
            ex("Mesa Flexora", 3, 12, 40, Muscle.legs),
            ex("Panturrilha em Pé", 4, 15, 90, Muscle.legs),
            ),
        ),
        sheet(
            "Masculino G — Pernas Hipertrofia",
            "Volume alto de pernas para crescimento — perfil masculino",
            listOf(
            ex("Hack Squat", 4, 10, 120, Muscle.legs),
            ex("Leg Press 45°", 4, 12, 170, Muscle.legs),
            ex("Cadeira Extensora", 4, 12, 45, Muscle.legs),
            ex("Mesa Flexora", 4, 12, 40, Muscle.legs),
            ex("Afundo", 3, 12, 24, Muscle.legs),
            ex("Stiff", 3, 10, 60, Muscle.legs),
            ex("Panturrilha Sentado", 4, 15, 55, Muscle.legs),
            ex("Panturrilha em Pé", 3, 15, 80, Muscle.legs),
            ),
        ),
    )

    val female: List<WorkoutSheet> = listOf(
        sheet(
            "Feminino A — Glúteos e Posteriores",
            "Ativação e hipertrofia de glúteos e cadeia posterior — perfil feminino",
            listOf(
            ex("Elevação Pélvica (Hip Thrust)", 4, 12, 40, Muscle.legs),
            ex("Agachamento Sumô", 4, 12, 40, Muscle.legs),
            ex("Stiff", 4, 12, 30, Muscle.legs),
            ex("Afundo Búlgaro", 3, 12, 12, Muscle.legs),
            ex("Cadeira Abdutora", 4, 15, 40, Muscle.legs),
            ex("Coice na Polia", 3, 15, 15, Muscle.legs),
            ex("Mesa Flexora", 3, 12, 25, Muscle.legs),
            ex("Panturrilha em Pé", 3, 15, 40, Muscle.legs),
            ),
        ),
        sheet(
            "Feminino B — Pernas e Core",
            "Quadríceps, adutores e abdômen — perfil feminino",
            listOf(
            ex("Agachamento Livre", 4, 12, 35, Muscle.legs),
            ex("Leg Press 45°", 4, 15, 80, Muscle.legs),
            ex("Cadeira Extensora", 4, 15, 30, Muscle.legs),
            ex("Cadeira Adutora", 3, 15, 40, Muscle.legs),
            ex("Afundo", 3, 12, 10, Muscle.legs),
            ex("Panturrilha Sentado", 3, 20, 30, Muscle.legs),
            ),
        ),
        sheet(
            "Feminino C — Costas e Postura",
            "Costas, ombros posteriores e braços leves — perfil feminino",
            listOf(
            ex("Puxada Frontal", 4, 12, 30, Muscle.back),
            ex("Remada Unilateral", 3, 12, 12, Muscle.back),
            ex("Pulldown Triângulo", 3, 12, 25, Muscle.back),
            ex("Remada Curvada", 3, 12, 25, Muscle.back),
            ex("Face Pull", 3, 15, 12, Muscle.back),
            ex("Crucifixo Inverso", 3, 15, 6, Muscle.shoulders),
            ex("Elevação Lateral", 3, 15, 6, Muscle.shoulders),
            ex("Rosca Direta", 3, 12, 8, Muscle.arms),
            ex("Tríceps Pulley", 3, 12, 15, Muscle.arms),
            ),
        ),
        sheet(
            "Feminino D — Full Body e Ombros",
            "Corpo inteiro com ênfase em ombros e core — perfil feminino",
            listOf(
            ex("Agachamento Livre", 3, 12, 30, Muscle.legs),
            ex("Elevação Pélvica (Hip Thrust)", 3, 12, 35, Muscle.legs),
            ex("Puxada Frontal", 3, 12, 25, Muscle.back),
            ex("Desenvolvimento com Halteres", 3, 12, 8, Muscle.shoulders),
            ex("Elevação Lateral", 3, 15, 5, Muscle.shoulders),
            ex("Flexão de Braços", 3, 10, null, Muscle.chest),
            ex("Remada Unilateral", 3, 12, 10, Muscle.back),
            ex("Kettlebell Swing", 3, 15, 12, Muscle.fullBody),
            ),
        ),
        sheet(
            "Feminino E — Superior",
            "Costas, ombros, peito e braços — membros superiores feminino",
            listOf(
            ex("Puxada Frontal", 4, 12, 30, Muscle.back),
            ex("Remada Unilateral", 3, 12, 12, Muscle.back),
            ex("Desenvolvimento com Halteres", 3, 12, 8, Muscle.shoulders),
            ex("Elevação Lateral", 4, 15, 5, Muscle.shoulders),
            ex("Supino Inclinado com Halteres", 3, 12, 10, Muscle.chest),
            ex("Face Pull", 3, 15, 10, Muscle.back),
            ex("Rosca Direta", 3, 12, 8, Muscle.arms),
            ex("Tríceps Pulley", 3, 12, 14, Muscle.arms),
            ),
        ),
        sheet(
            "Feminino F — Inferior",
            "Quadríceps, posteriores e glúteos — membros inferiores feminino",
            listOf(
            ex("Agachamento Livre", 4, 12, 35, Muscle.legs),
            ex("Leg Press 45°", 4, 12, 80, Muscle.legs),
            ex("Stiff", 3, 12, 30, Muscle.legs),
            ex("Elevação Pélvica (Hip Thrust)", 4, 12, 40, Muscle.legs),
            ex("Afundo", 3, 12, 10, Muscle.legs),
            ex("Cadeira Extensora", 3, 15, 28, Muscle.legs),
            ex("Panturrilha em Pé", 3, 15, 40, Muscle.legs),
            ),
        ),
        sheet(
            "Feminino G — Glúteos Crescimento",
            "Alto volume para hipertrofia de glúteos — perfil feminino",
            listOf(
            ex("Elevação Pélvica (Hip Thrust)", 5, 12, 45, Muscle.legs),
            ex("Agachamento Sumô", 4, 12, 40, Muscle.legs),
            ex("Afundo Búlgaro", 4, 12, 12, Muscle.legs),
            ex("Stiff", 4, 10, 30, Muscle.legs),
            ex("Coice na Polia", 4, 15, 14, Muscle.legs),
            ex("Cadeira Abdutora", 4, 15, 40, Muscle.legs),
            ex("Mesa Flexora", 3, 12, 25, Muscle.legs),
            ),
        ),
        sheet(
            "Feminino H — Pernas Crescimento",
            "Volume de pernas para crescimento — perfil feminino",
            listOf(
            ex("Agachamento Livre", 4, 10, 40, Muscle.legs),
            ex("Hack Squat", 4, 12, 55, Muscle.legs),
            ex("Leg Press 45°", 4, 12, 90, Muscle.legs),
            ex("Cadeira Extensora", 4, 15, 30, Muscle.legs),
            ex("Mesa Flexora", 4, 12, 28, Muscle.legs),
            ex("Cadeira Adutora", 3, 15, 40, Muscle.legs),
            ex("Afundo", 3, 12, 10, Muscle.legs),
            ex("Panturrilha Sentado", 4, 15, 30, Muscle.legs),
            ),
        ),
    )

    val home: List<WorkoutSheet> = listOf(
        sheet(
            "Casa A — Full Body",
            "Corpo inteiro sem equipamentos — ideal para iniciar em casa",
            listOf(
                ex("Agachamento Livre", 3, 15, null, Muscle.legs),
                ex("Flexão de Braços", 3, 12, null, Muscle.chest),
                ex("Afundo", 3, 12, null, Muscle.legs),
                ex("Mergulho no Banco", 3, 12, null, Muscle.arms),
                ex("Prancha", 3, 40, null, Muscle.core),
                ex("Mountain Climber", 3, 20, null, Muscle.fullBody),
                ex("Burpee", 3, 10, null, Muscle.fullBody),
                ex("Polichinelo", 3, 30, null, Muscle.fullBody),
            ),
        ),
        sheet(
            "Casa B — Core e Abdômen",
            "Abdômen, oblíquos e estabilidade — só o peso do corpo",
            listOf(
                ex("Prancha", 3, 45, null, Muscle.core),
                ex("Prancha Lateral", 3, 30, null, Muscle.core),
                ex("Abdominal Crunch", 3, 20, null, Muscle.core),
                ex("Abdominal Infra", 3, 15, null, Muscle.core),
                ex("Abdominal Oblíquo", 3, 20, null, Muscle.core),
                ex("Elevação de Pernas", 3, 12, null, Muscle.core),
                ex("Bicicleta no Ar", 3, 24, null, Muscle.core),
                ex("Russian Twist", 3, 24, null, Muscle.core),
            ),
        ),
        sheet(
            "Casa C — HIIT Em Casa",
            "Alta intensidade em circuitos curtos — cardio + força",
            listOf(
                ex("Polichinelo", 4, 40, null, Muscle.fullBody),
                ex("Burpee", 4, 10, null, Muscle.fullBody),
                ex("Mountain Climber", 4, 30, null, Muscle.fullBody),
                ex("Agachamento Livre", 4, 20, null, Muscle.legs),
                ex("Flexão de Braços", 4, 12, null, Muscle.chest),
                ex("Prancha", 3, 40, null, Muscle.core),
                ex("Afundo", 3, 16, null, Muscle.legs),
                ex("Polichinelo", 3, 35, null, Muscle.fullBody),
            ),
        ),
        sheet(
            "Casa D — Pernas e Glúteos",
            "Inferiores em casa — agachamentos, afundos e ponte",
            listOf(
                ex("Agachamento Livre", 4, 15, null, Muscle.legs),
                ex("Afundo", 3, 12, null, Muscle.legs),
                ex("Ponte de Glúteos", 4, 15, null, Muscle.legs),
                ex("Elevação Pélvica (Hip Thrust)", 3, 15, null, Muscle.legs),
                ex("Isometria na Parede", 3, 40, null, Muscle.legs),
                ex("Agachamento Sumô", 3, 15, null, Muscle.legs),
                ex("Panturrilha Corporal", 4, 20, null, Muscle.legs),
                ex("Prancha", 3, 35, null, Muscle.core),
            ),
        ),
        sheet(
            "Casa E — Superiores",
            "Peito, tríceps e postura — flexões e isometrias",
            listOf(
                ex("Flexão de Braços", 4, 12, null, Muscle.chest),
                ex("Flexão Diamante", 3, 10, null, Muscle.arms),
                ex("Flexão Inclinada", 3, 12, null, Muscle.chest),
                ex("Mergulho no Banco", 3, 12, null, Muscle.arms),
                ex("Superman", 3, 15, null, Muscle.back),
                ex("Prancha", 3, 40, null, Muscle.core),
                ex("Prancha Lateral", 3, 30, null, Muscle.core),
                ex("Flexão de Braços", 2, 10, null, Muscle.chest),
            ),
        ),
        sheet(
            "Casa F — Mobilidade e Postura",
            "Core, lombar e estabilidade para o dia a dia",
            listOf(
                ex("Superman", 3, 12, null, Muscle.back),
                ex("Ponte de Glúteos", 3, 15, null, Muscle.legs),
                ex("Prancha", 3, 40, null, Muscle.core),
                ex("Prancha Lateral", 3, 30, null, Muscle.core),
                ex("Elevação de Pernas", 3, 12, null, Muscle.core),
                ex("Russian Twist", 3, 20, null, Muscle.core),
                ex("Bicicleta no Ar", 3, 24, null, Muscle.core),
                ex("Isometria na Parede", 3, 35, null, Muscle.legs),
            ),
        ),
    )

    val mobility: List<WorkoutSheet> = listOf(
        sheet(
            "Mobilidade A — Aquecimento Geral",
            "Ativação articular antes de treinar com carga — 8–10 min",
            listOf(
                ex("Círculos de Tornozelo", 2, 12, null, Muscle.legs),
                ex("Círculos de Punho", 2, 12, null, Muscle.arms),
                ex("Inchworm", 2, 8, null, Muscle.fullBody),
                ex("Alongamento Mundial", 2, 6, null, Muscle.fullBody),
                ex("Alongamento de Coluna", 2, 10, null, Muscle.back),
                ex("Alongamento de Costas Altas", 2, 10, null, Muscle.back),
                ex("Alongamento de Panturrilha", 2, 30, null, Muscle.legs),
            ),
        ),
        sheet(
            "Mobilidade E — Pós-treino",
            "Alongamento estático para recuperação após a musculação",
            listOf(
                ex("Alongamento de Peito", 2, 40, null, Muscle.chest),
                ex("Alongamento de Dorsal", 2, 40, null, Muscle.back),
                ex("Alongamento de Posterior", 2, 40, null, Muscle.legs),
                ex("Alongamento de Flexor de Quadril", 2, 40, null, Muscle.legs),
                ex("Alongamento de Glúteo", 2, 40, null, Muscle.legs),
                ex("Alongamento de Tríceps", 2, 35, null, Muscle.arms),
                ex("Alongamento de Panturrilha", 2, 35, null, Muscle.legs),
                ex("Alongamento de Pescoço", 2, 25, null, Muscle.shoulders),
            ),
        ),
    )
}
