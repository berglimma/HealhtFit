import Foundation

enum MealCatalog {
    static let allTemplates: [MealTemplate] = simpleOptions
        + breakfastOptions
        + morningSnackOptions
        + lunchOptions
        + afternoonSnackOptions
        + dinnerOptions
        + supperOptions
        + fatLossOptions

    static func templates(
        for mealType: MealType,
        sweetLevel: SweetConsumptionLevel,
        goal: FitnessGoal,
        lactoseTolerance: LactoseTolerance
    ) -> [MealTemplate] {
        var base = allTemplates.filter { $0.mealType == mealType }

        if lactoseTolerance == .intolerant {
            base = base.filter { !$0.containsLactose }
        }

        let simple = base.filter(\.isSimpleBasic)
        let rest = base.filter { !$0.isSimpleBasic }

        if goal == .fatLoss {
            let fatLoss = rest.filter(\.isFatLossFocused)
            let general = rest.filter { !$0.isFatLossFocused }
            base = simple + fatLoss + general
        } else {
            base = simple + rest
        }

        switch sweetLevel {
        case .low:
            let savory = base.filter { !$0.isSweet }
            let sweets = base.filter { $0.isSweet }.prefix(goal == .fatLoss ? 0 : 1)
            return savory + sweets
        case .moderate:
            return base
        case .high:
            let sweets = base.filter { $0.isSweet }
            let others = base.filter { !$0.isSweet }
            return sweets + others
        }
    }

    static func template(id: UUID) -> MealTemplate? {
        allTemplates.first { $0.id == id }
    }

    static func defaultTemplate(
        for mealType: MealType,
        sweetLevel: SweetConsumptionLevel,
        goal: FitnessGoal,
        lactoseTolerance: LactoseTolerance,
        index: Int
    ) -> MealTemplate {
        let options = templates(for: mealType, sweetLevel: sweetLevel, goal: goal, lactoseTolerance: lactoseTolerance)
        guard !options.isEmpty else {
            return allTemplates.first { $0.mealType == mealType }!
        }
        return options[index % options.count]
    }

    // MARK: - Opção simples (alimentos básicos, serve todos os objetivos)

    private static let simpleOptions: [MealTemplate] = [
        MealTemplate(
            id: UUID(uuidString: "B1000001-0000-4000-8000-000000000001")!,
            name: "Simples — ovos, pão e banana",
            mealType: .breakfast,
            calories: 380, protein: 24, carbs: 42, fat: 12,
            ingredients: ["2 ovos", "2 fatias pão", "1 banana", "Café ou chá"],
            instructions: "Frite ou cozinhe os ovos e coma com pão e banana. As porções sobem no ganho de massa e descem na perda de gordura.",
            isSweet: false,
            isSimpleBasic: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B2000001-0000-4000-8000-000000000001")!,
            name: "Simples — banana e ovos",
            mealType: .morningSnack,
            calories: 220, protein: 14, carbs: 24, fat: 8,
            ingredients: ["1 banana", "2 ovos"],
            instructions: "Lanche rápido com proteína e carboidrato. Ajuste a quantidade ao objetivo (massa, déficit, manutenção ou resistência).",
            isSweet: false,
            isSimpleBasic: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B3000001-0000-4000-8000-000000000001")!,
            name: "Simples — arroz, feijão e frango",
            mealType: .lunch,
            calories: 560, protein: 46, carbs: 58, fat: 12,
            ingredients: ["150g arroz", "1 concha feijão", "150g peito de frango", "Salada", "Azeite"],
            instructions: "Prato básico: arroz, feijão, frango e salada. Mais arroz na resistência/ganho; menos arroz e mais salada na perda de gordura.",
            isSweet: false,
            isSimpleBasic: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B4000001-0000-4000-8000-000000000001")!,
            name: "Simples — pão com ovo",
            mealType: .afternoonSnack,
            calories: 230, protein: 16, carbs: 26, fat: 8,
            ingredients: ["2 fatias pão", "2 ovos", "Tomate"],
            instructions: "Pão com ovos e tomate. Dobre o pão na resistência; priorize o ovo na perda de gordura.",
            isSweet: false,
            isSimpleBasic: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B5000001-0000-4000-8000-000000000001")!,
            name: "Simples — arroz, frango e legumes",
            mealType: .dinner,
            calories: 480, protein: 42, carbs: 44, fat: 12,
            ingredients: ["120g arroz", "150g peito de frango", "Legumes (cenoura, abobrinha ou brócolis)", "Azeite"],
            instructions: "Jantar simples com arroz, frango e legumes. Aumente o arroz na resistência; reduza no déficit.",
            isSweet: false,
            isSimpleBasic: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B6000001-0000-4000-8000-000000000001")!,
            name: "Simples — ovos e fruta",
            mealType: .supper,
            calories: 180, protein: 14, carbs: 16, fat: 8,
            ingredients: ["2 ovos", "1 maçã ou banana"],
            instructions: "Ceia leve com ovos e fruta. Serve manutenção, perda de gordura e recuperação.",
            isSweet: false,
            isSimpleBasic: true
        ),
    ]

  // MARK: - Café da Manhã

    private static let breakfastOptions: [MealTemplate] = [
        MealTemplate(
            id: UUID(uuidString: "A1000001-0000-4000-8000-000000000001")!,
            name: "Omelete Proteico",
            mealType: .breakfast,
            calories: 380, protein: 30, carbs: 22, fat: 16,
            ingredients: ["3 ovos", "50g cottage", "1 fatia pão integral", "Tomate cereja"],
            instructions: "Bata os ovos, adicione o queijo e cozinhe em frigideira antiaderente.",
            isSweet: false,
            containsLactose: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A1000001-0000-4000-8000-000000000002")!,
            name: "Aveia com Frutas",
            mealType: .breakfast,
            calories: 360, protein: 14, carbs: 58, fat: 8,
            ingredients: ["80g aveia", "1 banana", "Morangos", "1 colher mel"],
            instructions: "Cozinhe a aveia com leite e finalize com frutas.",
            isSweet: true,
            containsLactose: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A1000001-0000-4000-8000-000000000003")!,
            name: "Panqueca de Banana",
            mealType: .breakfast,
            calories: 340, protein: 18, carbs: 42, fat: 10,
            ingredients: ["2 ovos", "1 banana", "Aveia", "Canela"],
            instructions: "Misture os ingredientes e grelhe em frigideira.",
            isSweet: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A1000001-0000-4000-8000-000000000004")!,
            name: "Pão com Ovo e Abacate",
            mealType: .breakfast,
            calories: 400, protein: 22, carbs: 35, fat: 18,
            ingredients: ["2 ovos", "2 fatias pão integral", "1/2 abacate", "Sal e pimenta"],
            instructions: "Grelhe os ovos e monte com abacate amassado no pão.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A1000001-0000-4000-8000-000000000005")!,
            name: "Quinoa com Mamão",
            mealType: .breakfast,
            calories: 350, protein: 12, carbs: 52, fat: 10,
            ingredients: ["80g quinoa", "1 fatia mamão", "Mel", "Canela"],
            instructions: "Cozinhe a quinoa e sirva com mamão picado.",
            isSweet: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A1000001-0000-4000-8000-000000000006")!,
            name: "Crepioca de Frango",
            mealType: .breakfast,
            calories: 390, protein: 34, carbs: 28, fat: 12,
            ingredients: ["100g peito de frango", "2 ovos", "Goma de tapioca", "Orégano"],
            instructions: "Desfie o frango, misture com ovos e tapioca e grelhe.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A1000001-0000-4000-8000-000000000007")!,
            name: "Bowl de Açaí",
            mealType: .breakfast,
            calories: 370, protein: 10, carbs: 55, fat: 12,
            ingredients: ["200g polpa de açaí", "1 banana", "Granola", "Morangos"],
            instructions: "Monte o bowl com frutas e granola por cima.",
            isSweet: true
        ),
    ]

    // MARK: - Lanche (manhã)

    private static let morningSnackOptions: [MealTemplate] = [
        MealTemplate(
            id: UUID(uuidString: "A2000001-0000-4000-8000-000000000001")!,
            name: "Shake de Whey",
            mealType: .morningSnack,
            calories: 220, protein: 28, carbs: 18, fat: 4,
            ingredients: ["30g whey", "1 banana", "200ml leite desnatado"],
            instructions: "Bata tudo no liquidificador.",
            isSweet: true,
            containsLactose: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A2000001-0000-4000-8000-000000000002")!,
            name: "Iogurte com Castanhas",
            mealType: .morningSnack,
            calories: 200, protein: 15, carbs: 14, fat: 10,
            ingredients: ["170g iogurte grego", "20g castanhas", "Canela"],
            instructions: "Misture e consuma gelado.",
            isSweet: false,
            containsLactose: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A2000001-0000-4000-8000-000000000003")!,
            name: "Barra de Cereal Integral",
            mealType: .morningSnack,
            calories: 180, protein: 6, carbs: 30, fat: 5,
            ingredients: ["1 barra integral", "1 maçã"],
            instructions: "Lanche prático entre as refeições.",
            isSweet: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A2000001-0000-4000-8000-000000000004")!,
            name: "Kiwi com Castanhas",
            mealType: .morningSnack,
            calories: 170, protein: 4, carbs: 22, fat: 8,
            ingredients: ["2 kiwis", "15g castanhas do pará"],
            instructions: "Corte o kiwi e consuma com as castanhas.",
            isSweet: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A2000001-0000-4000-8000-000000000005")!,
            name: "Iogurte com Granola e Uva",
            mealType: .morningSnack,
            calories: 210, protein: 14, carbs: 28, fat: 6,
            ingredients: ["170g iogurte grego", "30g granola", "1 cacho uva"],
            instructions: "Misture o iogurte com granola e uvas.",
            isSweet: true,
            containsLactose: true
        ),
    ]

    // MARK: - Almoço

    private static let lunchOptions: [MealTemplate] = [
        MealTemplate(
            id: UUID(uuidString: "A3000001-0000-4000-8000-000000000001")!,
            name: "Frango com Arroz e Brócolis",
            mealType: .lunch,
            calories: 560, protein: 48, carbs: 58, fat: 12,
            ingredients: ["200g peito de frango", "150g arroz integral", "Brócolis", "Azeite"],
            instructions: "Grelhe o frango e sirva com arroz e brócolis no vapor.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A3000001-0000-4000-8000-000000000002")!,
            name: "Carne com Legumes",
            mealType: .lunch,
            calories: 580, protein: 52, carbs: 42, fat: 18,
            ingredients: ["200g patinho", "Abobrinha", "Cenoura", "Arroz"],
            instructions: "Refogue a carne com os legumes.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A3000001-0000-4000-8000-000000000003")!,
            name: "Peixe com Quinoa",
            mealType: .lunch,
            calories: 520, protein: 44, carbs: 48, fat: 14,
            ingredients: ["200g tilápia", "120g quinoa", "Espinafre", "Alho"],
            instructions: "Grelhe o peixe e sirva com quinoa.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A3000001-0000-4000-8000-000000000004")!,
            name: "Bowl de Carne e Feijão",
            mealType: .lunch,
            calories: 600, protein: 46, carbs: 62, fat: 16,
            ingredients: ["150g carne", "1 concha feijão", "Salada", "Farofa light"],
            instructions: "Monte o bowl com proteína, feijão e salada.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A3000001-0000-4000-8000-000000000005")!,
            name: "Frango com Lentilha",
            mealType: .lunch,
            calories: 540, protein: 50, carbs: 48, fat: 12,
            ingredients: ["200g peito de frango", "120g lentilha", "Cenoura", "Cebola"],
            instructions: "Cozinhe a lentilha e sirva com frango grelhado.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A3000001-0000-4000-8000-000000000006")!,
            name: "Salmão com Mandioca",
            mealType: .lunch,
            calories: 560, protein: 42, carbs: 50, fat: 18,
            ingredients: ["180g salmão", "200g mandioca", "Couve", "Alho"],
            instructions: "Cozinhe a mandioca e grelhe o salmão.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A3000001-0000-4000-8000-000000000007")!,
            name: "Estrogonofe de Frango",
            mealType: .lunch,
            calories: 580, protein: 46, carbs: 54, fat: 16,
            ingredients: ["200g peito de frango", "150g arroz integral", "Champignon", "Molho tomate"],
            instructions: "Refogue o frango com cogumelos e sirva com arroz.",
            isSweet: false
        ),
    ]

    // MARK: - Lanche da Tarde

    private static let afternoonSnackOptions: [MealTemplate] = [
        MealTemplate(
            id: UUID(uuidString: "A4000001-0000-4000-8000-000000000001")!,
            name: "Sanduíche de Atum",
            mealType: .afternoonSnack,
            calories: 240, protein: 22, carbs: 26, fat: 6,
            ingredients: ["2 fatias pão integral", "1 lata atum", "Folhas verdes"],
            instructions: "Monte o sanduíche com atum escorrido.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A4000001-0000-4000-8000-000000000002")!,
            name: "Vitamina de Frutas",
            mealType: .afternoonSnack,
            calories: 210, protein: 8, carbs: 38, fat: 4,
            ingredients: ["1 banana", "Morangos", "200ml leite", "Gelo"],
            instructions: "Bata no liquidificador.",
            isSweet: true,
            containsLactose: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A4000001-0000-4000-8000-000000000003")!,
            name: "Tapioca com Queijo",
            mealType: .afternoonSnack,
            calories: 230, protein: 12, carbs: 28, fat: 8,
            ingredients: ["2 colheres goma de tapioca", "Queijo branco", "Orégano"],
            instructions: "Hidrate a tapioca, grelhe e recheie.",
            isSweet: false,
            containsLactose: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A4000001-0000-4000-8000-000000000004")!,
            name: "Bolo de Cenoura Fit (fatia)",
            mealType: .afternoonSnack,
            calories: 200, protein: 6, carbs: 32, fat: 6,
            ingredients: ["1 fatia bolo fit", "Café ou chá"],
            instructions: "Opção doce com moderação.",
            isSweet: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A4000001-0000-4000-8000-000000000005")!,
            name: "Wrap de Peito de Peru",
            mealType: .afternoonSnack,
            calories: 250, protein: 24, carbs: 28, fat: 6,
            ingredients: ["1 tortilla integral", "80g peito de peru", "Alface", "Tomate"],
            instructions: "Monte o wrap com proteína e vegetais.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A4000001-0000-4000-8000-000000000006")!,
            name: "Vitamina de Manga",
            mealType: .afternoonSnack,
            calories: 200, protein: 6, carbs: 36, fat: 4,
            ingredients: ["1 manga", "200ml leite", "Gelo", "Hortelã"],
            instructions: "Bata a manga com leite no liquidificador.",
            isSweet: true,
            containsLactose: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A4000001-0000-4000-8000-000000000007")!,
            name: "Cuscuz com Ovo",
            mealType: .afternoonSnack,
            calories: 220, protein: 14, carbs: 32, fat: 6,
            ingredients: ["80g cuscuz", "2 ovos", "Queijo coalho", "Orégano"],
            instructions: "Prepare o cuscuz e sirva com ovos cozidos.",
            isSweet: false,
            containsLactose: true
        ),
    ]

    // MARK: - Jantar

    private static let dinnerOptions: [MealTemplate] = [
        MealTemplate(
            id: UUID(uuidString: "A5000001-0000-4000-8000-000000000001")!,
            name: "Salmão com Batata Doce",
            mealType: .dinner,
            calories: 480, protein: 40, carbs: 42, fat: 18,
            ingredients: ["180g salmão", "200g batata doce", "Aspargos", "Limão"],
            instructions: "Asse o salmão e a batata no forno.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A5000001-0000-4000-8000-000000000002")!,
            name: "Atum com Salada",
            mealType: .dinner,
            calories: 420, protein: 36, carbs: 28, fat: 14,
            ingredients: ["2 latas atum", "Mix de folhas", "Tomate", "Azeite"],
            instructions: "Monte a salada e finalize com atum.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A5000001-0000-4000-8000-000000000003")!,
            name: "Frango Desfiado com Legumes",
            mealType: .dinner,
            calories: 450, protein: 42, carbs: 32, fat: 12,
            ingredients: ["180g frango", "Abobrinha", "Cenoura", "Batata inglesa"],
            instructions: "Cozinhe o frango e refogue com legumes.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A5000001-0000-4000-8000-000000000004")!,
            name: "Omelete de Forno",
            mealType: .dinner,
            calories: 400, protein: 32, carbs: 18, fat: 20,
            ingredients: ["3 ovos", "Espinafre", "Queijo", "Tomate"],
            instructions: "Monte na forma e asse por 20 min.",
            isSweet: false,
            containsLactose: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A5000001-0000-4000-8000-000000000005")!,
            name: "Camarão com Arroz",
            mealType: .dinner,
            calories: 460, protein: 38, carbs: 48, fat: 10,
            ingredients: ["200g camarão", "120g arroz integral", "Alho", "Limão"],
            instructions: "Refogue o camarão e sirva com arroz.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A5000001-0000-4000-8000-000000000006")!,
            name: "Moqueca de Peixe",
            mealType: .dinner,
            calories: 440, protein: 36, carbs: 38, fat: 14,
            ingredients: ["200g peixe branco", "150g arroz", "Pimentão", "Leite de coco"],
            instructions: "Cozinhe o peixe no molho de pimentão e coco.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A5000001-0000-4000-8000-000000000007")!,
            name: "Carne com Purê de Batata",
            mealType: .dinner,
            calories: 500, protein: 44, carbs: 42, fat: 16,
            ingredients: ["180g patinho", "250g batata inglesa", "Brócolis", "Azeite"],
            instructions: "Grelhe a carne e sirva com purê e brócolis.",
            isSweet: false
        ),
    ]

    // MARK: - Ceia

    private static let supperOptions: [MealTemplate] = [
        MealTemplate(
            id: UUID(uuidString: "A6000001-0000-4000-8000-000000000001")!,
            name: "Chá com Castanhas",
            mealType: .supper,
            calories: 140, protein: 4, carbs: 8, fat: 11,
            ingredients: ["Chá de camomila", "15g castanhas"],
            instructions: "Lanche leve antes de dormir.",
            isSweet: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A6000001-0000-4000-8000-000000000002")!,
            name: "Iogurte Proteico",
            mealType: .supper,
            calories: 160, protein: 18, carbs: 12, fat: 4,
            ingredients: ["170g iogurte grego", "Canela"],
            instructions: "Consuma gelado.",
            isSweet: false,
            containsLactose: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A6000001-0000-4000-8000-000000000003")!,
            name: "Leite com Cacau 70%",
            mealType: .supper,
            calories: 170, protein: 10, carbs: 16, fat: 6,
            ingredients: ["200ml leite", "1 colher cacau", "Adoçante opcional"],
            instructions: "Aqueça o leite e misture o cacau.",
            isSweet: true,
            containsLactose: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A6000001-0000-4000-8000-000000000004")!,
            name: "Pudim de Chia com Frutas",
            mealType: .supper,
            calories: 190, protein: 8, carbs: 22, fat: 8,
            ingredients: ["Chia", "Leite vegetal", "Mirtilos", "Mel"],
            instructions: "Deixe na geladeira por 4h.",
            isSweet: true,
            containsLactose: false
        ),
        MealTemplate(
            id: UUID(uuidString: "A6000001-0000-4000-8000-000000000005")!,
            name: "Frutas Vermelhas com Iogurte",
            mealType: .supper,
            calories: 150, protein: 10, carbs: 20, fat: 3,
            ingredients: ["Morangos", "Framboesas", "170g iogurte natural"],
            instructions: "Misture as frutas com o iogurte.",
            isSweet: true,
            containsLactose: true
        ),
        MealTemplate(
            id: UUID(uuidString: "A6000001-0000-4000-8000-000000000006")!,
            name: "Mingau de Aveia com Pera",
            mealType: .supper,
            calories: 180, protein: 8, carbs: 30, fat: 4,
            ingredients: ["40g aveia", "1 pera", "Canela", "200ml leite"],
            instructions: "Cozinhe a aveia e finalize com pera picada.",
            isSweet: true,
            containsLactose: true
        ),
    ]

    // MARK: - Perda de Gordura (restritivas)

    private static let fatLossOptions: [MealTemplate] = [
        MealTemplate(
            id: UUID(uuidString: "B1000001-0000-4000-8000-000000000001")!,
            name: "Claras com Vegetais",
            mealType: .breakfast,
            calories: 280, protein: 32, carbs: 12, fat: 8,
            ingredients: ["4 claras", "2 ovos", "Espinafre", "Tomate", "Azeite spray"],
            instructions: "Refogue os vegetais e finalize com ovos. Sem fritura.",
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B1000001-0000-4000-8000-000000000002")!,
            name: "Aveia com Leite Vegetal",
            mealType: .breakfast,
            calories: 300, protein: 12, carbs: 42, fat: 8,
            ingredients: ["60g aveia", "200ml leite de amêndoas", "Canela", "Morangos"],
            instructions: "Cozinhe a aveia com leite vegetal. Sem açúcar adicionado.",
            isSweet: false,
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B1000001-0000-4000-8000-000000000003")!,
            name: "Omelete Fit sem Lactose",
            mealType: .breakfast,
            calories: 260, protein: 28, carbs: 8, fat: 12,
            ingredients: ["3 ovos", "Cogumelos", "Pimentão", "Azeite (1 colher chá)"],
            instructions: "Omelete grelhada com legumes. Restrição de gordura e lactose.",
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B2000001-0000-4000-8000-000000000001")!,
            name: "Whey com Água",
            mealType: .morningSnack,
            calories: 150, protein: 30, carbs: 6, fat: 2,
            ingredients: ["35g whey isolado", "300ml água", "Gelo"],
            instructions: "Shake proteico sem lactose e baixo carboidrato.",
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B2000001-0000-4000-8000-000000000002")!,
            name: "Maçã com Pasta de Amendoim",
            mealType: .morningSnack,
            calories: 180, protein: 6, carbs: 20, fat: 9,
            ingredients: ["1 maçã", "1 colher chá pasta de amendoim"],
            instructions: "Porção controlada — ideal para déficit calórico.",
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B3000001-0000-4000-8000-000000000001")!,
            name: "Frango Grelhado e Salada",
            mealType: .lunch,
            calories: 420, protein: 48, carbs: 18, fat: 14,
            ingredients: ["200g peito de frango", "Mix de folhas", "Tomate", "Limão"],
            instructions: "Sem arroz. Proteína alta e carboidrato reduzido.",
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B3000001-0000-4000-8000-000000000002")!,
            name: "Tilápia com Legumes no Vapor",
            mealType: .lunch,
            calories: 380, protein: 42, carbs: 22, fat: 10,
            ingredients: ["200g tilápia", "Brócolis", "Cenoura", "Abobrinha"],
            instructions: "Cozinhe no vapor. Evite molhos calóricos.",
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B3000001-0000-4000-8000-000000000003")!,
            name: "Carne Magra com Feijão Light",
            mealType: .lunch,
            calories: 450, protein: 46, carbs: 32, fat: 12,
            ingredients: ["150g patinho", "1/2 concha feijão", "Salada crua"],
            instructions: "Porção reduzida de carboidrato. Sem frituras.",
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B4000001-0000-4000-8000-000000000001")!,
            name: "Ovos Cozidos e Pepino",
            mealType: .afternoonSnack,
            calories: 160, protein: 14, carbs: 4, fat: 10,
            ingredients: ["2 ovos cozidos", "1 pepino", "Sal", "Limão"],
            instructions: "Lanche proteico sem lactose e sem açúcar.",
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B4000001-0000-4000-8000-000000000002")!,
            name: "Shake Verde Low Carb",
            mealType: .afternoonSnack,
            calories: 140, protein: 20, carbs: 10, fat: 3,
            ingredients: ["Whey isolado", "Espinafre", "Água de coco", "Gelo"],
            instructions: "Vitamina restritiva para perda de gordura.",
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B5000001-0000-4000-8000-000000000001")!,
            name: "Peixe Assado com Salada",
            mealType: .dinner,
            calories: 340, protein: 38, carbs: 14, fat: 14,
            ingredients: ["180g peixe branco", "Folhas", "Pepino", "Azeite (1 colher chá)"],
            instructions: "Jantar leve. Sem carboidrato refinado.",
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B5000001-0000-4000-8000-000000000002")!,
            name: "Frango com Abobrinha Refogada",
            mealType: .dinner,
            calories: 320, protein: 40, carbs: 12, fat: 10,
            ingredients: ["180g frango", "Abobrinha", "Alho", "Ervas"],
            instructions: "Refeição restritiva com alto teor proteico.",
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B5000001-0000-4000-8000-000000000003")!,
            name: "Sopa de Legumes com Frango",
            mealType: .dinner,
            calories: 280, protein: 32, carbs: 20, fat: 6,
            ingredients: ["120g frango desfiado", "Abóbora", "Cenoura", "Cebola"],
            instructions: "Sopa leve. Sem creme de leite.",
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B6000001-0000-4000-8000-000000000001")!,
            name: "Chá e Castanhas (porção mínima)",
            mealType: .supper,
            calories: 110, protein: 3, carbs: 5, fat: 9,
            ingredients: ["Chá verde", "10g castanhas"],
            instructions: "Ceia leve para não ultrapassar o déficit.",
            isFatLossFocused: true
        ),
        MealTemplate(
            id: UUID(uuidString: "B6000001-0000-4000-8000-000000000002")!,
            name: "Iogurte de Coco sem Açúcar",
            mealType: .supper,
            calories: 130, protein: 4, carbs: 8, fat: 9,
            ingredients: ["170g iogurte de coco", "Canela"],
            instructions: "Alternativa sem lactose para ceia.",
            isFatLossFocused: true
        ),
    ]
}
