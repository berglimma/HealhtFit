import Combine
import CoreLocation
import Foundation
import MapKit

/// Áreas de escalada exibidas no mapa: um catálogo curado somado ao que o
/// MapKit encontra em volta do usuário.
@MainActor
final class ClimbingAreaCatalog: ObservableObject {
    static let shared = ClimbingAreaCatalog()

    @Published private(set) var nearbyResults: [ClimbingArea] = []
    @Published private(set) var isSearching = false

    private var lastSearchCenter: CLLocationCoordinate2D?

    private init() {}

    /// Setores conhecidos, disponíveis mesmo sem rede.
    static let curated: [ClimbingArea] = [
        ClimbingArea(
            name: "Pedra da Gávea",
            region: "Rio de Janeiro · RJ",
            latitude: -22.9975, longitude: -43.2853,
            disciplines: [.trad, .multipitch],
            routeCount: 40,
            gradeRange: "IV a 8a",
            notes: "Carrasqueira e Face Oeste. Aproximação longa e exposta ao sol — saia cedo."
        ),
        ClimbingArea(
            name: "Pão de Açúcar",
            region: "Rio de Janeiro · RJ",
            latitude: -22.9486, longitude: -43.1566,
            disciplines: [.trad, .sport, .multipitch],
            routeCount: 270,
            gradeRange: "III a 8b",
            notes: "Berço da escalada brasileira. Face Sul e Costão com vias clássicas de vários enfiamentes."
        ),
        ClimbingArea(
            name: "Pedra Bonita",
            region: "Rio de Janeiro · RJ",
            latitude: -22.9878, longitude: -43.2865,
            disciplines: [.sport, .trad],
            routeCount: 60,
            gradeRange: "IV a 7c",
            notes: "Acesso fácil pela Estrada das Canoas. Boa área para primeiras vias em rocha."
        ),
        ClimbingArea(
            name: "Pedra do Baú",
            region: "São Bento do Sapucaí · SP",
            latitude: -22.6897, longitude: -45.7269,
            disciplines: [.trad, .sport, .multipitch],
            routeCount: 120,
            gradeRange: "IV a 8a",
            notes: "Complexo do Baú, Bauzinho e Ana Chata. Rocha granítica e vias longas."
        ),
        ClimbingArea(
            name: "Pedra Grande de Atibaia",
            region: "Atibaia · SP",
            latitude: -23.1058, longitude: -46.5533,
            disciplines: [.sport, .trad, .boulder],
            routeCount: 150,
            gradeRange: "IV a 8b",
            notes: "Um dos setores mais movimentados de São Paulo, com esportivas curtas e blocos."
        ),
        ClimbingArea(
            name: "Morro Anhangava",
            region: "Quatro Barras · PR",
            latitude: -25.3861, longitude: -49.0269,
            disciplines: [.trad, .sport, .boulder],
            routeCount: 130,
            gradeRange: "IV a 8a",
            notes: "Principal área do Paraná. Fissuras clássicas e boulders na base."
        ),
        ClimbingArea(
            name: "Serra do Cipó",
            region: "Santana do Riacho · MG",
            latitude: -19.3333, longitude: -43.6167,
            disciplines: [.sport, .boulder],
            routeCount: 90,
            gradeRange: "V a 8b",
            notes: "Quartzito com boa aderência. Evite os meses mais quentes e úmidos."
        ),
        ClimbingArea(
            name: "Pedra Riscada",
            region: "São José do Divino · MG",
            latitude: -19.9800, longitude: -41.3500,
            disciplines: [.multipitch, .trad],
            routeCount: 25,
            gradeRange: "V a 7c",
            notes: "Big wall brasileira com vias de mais de 500 m. Exige logística e experiência."
        ),
        ClimbingArea(
            name: "Cocalzinho de Goiás",
            region: "Cocalzinho · GO",
            latitude: -15.7869, longitude: -48.7761,
            disciplines: [.sport, .boulder],
            routeCount: 200,
            gradeRange: "IV a 8c",
            notes: "Grande concentração de esportivas no Centro-Oeste, com setores na sombra."
        ),
        ClimbingArea(
            name: "Chapada Diamantina",
            region: "Lençóis · BA",
            latitude: -12.5600, longitude: -41.3900,
            disciplines: [.sport, .trad, .boulder],
            routeCount: 110,
            gradeRange: "IV a 8a",
            notes: "Arenito e quartzito. Rocha frágil quando molhada — não escale após chuva."
        ),
        ClimbingArea(
            name: "Pedra do Segredo",
            region: "Caçapava do Sul · RS",
            latitude: -30.5119, longitude: -53.4917,
            disciplines: [.boulder, .sport],
            routeCount: 80,
            gradeRange: "V0 a V12",
            notes: "Área de boulder consolidada no Sul, com blocos de arenito."
        ),
        ClimbingArea(
            name: "Morro do Campestre",
            region: "Urubici · SC",
            latitude: -28.0153, longitude: -49.5922,
            disciplines: [.sport, .trad],
            routeCount: 70,
            gradeRange: "IV a 8a",
            notes: "Basalto na serra catarinense. Frio no inverno favorece o atrito."
        ),
        ClimbingArea(
            name: "Parque Nacional dos Três Picos",
            region: "Nova Friburgo · RJ",
            latitude: -22.4167, longitude: -42.6167,
            disciplines: [.trad, .multipitch],
            routeCount: 45,
            gradeRange: "V a 7b",
            notes: "Vias longas em granito com aproximação de trilha pesada."
        ),
        ClimbingArea(
            name: "Serra de São José",
            region: "Tiradentes · MG",
            latitude: -21.1200, longitude: -44.1700,
            disciplines: [.sport, .boulder],
            routeCount: 60,
            gradeRange: "V a 8a",
            notes: "Quartzito com setores curtos, bom para volume de tentativas."
        )
    ]

    /// Catálogo curado ordenado por proximidade.
    func curatedAreas(near coordinate: CLLocationCoordinate2D?) -> [ClimbingArea] {
        guard let coordinate else { return Self.curated }
        return Self.curated.sorted {
            $0.distanceKm(from: coordinate) < $1.distanceKm(from: coordinate)
        }
    }

    /// Busca setores reais em volta pelo MapKit, complementando o catálogo.
    func searchNearby(coordinate: CLLocationCoordinate2D, force: Bool = false) async {
        if !force, let lastSearchCenter {
            let previous = CLLocation(latitude: lastSearchCenter.latitude, longitude: lastSearchCenter.longitude)
            let current = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            if previous.distance(from: current) < 5_000 { return }
        }

        isSearching = true
        defer { isSearching = false }
        lastSearchCenter = coordinate

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "escalada"
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 120_000,
            longitudinalMeters: 120_000
        )

        guard let response = try? await MKLocalSearch(request: request).start() else {
            nearbyResults = []
            return
        }

        nearbyResults = response.mapItems.compactMap { item in
            guard let name = item.name, let location = item.placemark.location else { return nil }
            let region = [item.placemark.locality, item.placemark.administrativeArea]
                .compactMap { $0 }
                .joined(separator: " · ")

            return ClimbingArea(
                name: name,
                region: region.isEmpty ? "Encontrado no mapa" : region,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                disciplines: [.sport],
                routeCount: 0,
                gradeRange: "Não catalogado",
                notes: "Resultado da busca do mapa — confirme o acesso e as condições no local."
            )
        }
    }
}
