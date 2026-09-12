import Foundation
import Combine

@MainActor
final class PulseMusicSearchService: ObservableObject {
    static let shared = PulseMusicSearchService()

    @Published private(set) var results: [PulseMusicAttachment] = []
    @Published private(set) var isSearching = false
    @Published var statusMessage: String?

    private var spotifyToken: String?
    private var spotifyTokenExpiresAt: Date?

    func search(query: String, provider: PulseMusicProvider) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            statusMessage = "Digite ao menos 2 caracteres."
            return
        }

        isSearching = true
        statusMessage = nil
        defer { isSearching = false }

        do {
            switch provider {
            case .deezer:
                results = try await searchDeezer(trimmed)
            case .appleMusic:
                results = try await searchAppleMusic(trimmed)
            case .spotify:
                results = try await searchSpotify(trimmed)
            }
            if results.isEmpty {
                statusMessage = "Nenhuma faixa encontrada em \(provider.title)."
            }
        } catch {
            results = []
            statusMessage = error.localizedDescription
        }
    }

    func clear() {
        results = []
        statusMessage = nil
    }

    // MARK: - Deezer

    private func searchDeezer(_ query: String) async throws -> [PulseMusicAttachment] {
        var components = URLComponents(string: "https://api.deezer.com/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "20")
        ]
        guard let url = components.url else { throw PulseMusicSearchError.invalidURL }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(DeezerSearchResponse.self, from: data)
        return decoded.data.map { track in
            PulseMusicAttachment(
                provider: .deezer,
                trackId: String(track.id),
                title: track.title,
                artistName: track.artist.name,
                artworkURL: track.album?.cover_medium ?? track.album?.cover,
                previewURL: track.preview.flatMap { $0.isEmpty ? nil : $0 },
                externalURL: track.link
            )
        }
    }

    // MARK: - Apple Music

    private func searchAppleMusic(_ query: String) async throws -> [PulseMusicAttachment] {
        // MusicKit removido (sem entitlement) — evita TCC/travamentos no iPhone.
        _ = query
        throw PulseMusicSearchError.appleMusicUnavailable
    }

    // MARK: - Spotify

    private func searchSpotify(_ query: String) async throws -> [PulseMusicAttachment] {
        guard PulseExperimental.hasSpotifyCredentials else {
            throw PulseMusicSearchError.spotifyCredentialsMissing
        }
        let token = try await spotifyAccessToken()
        var components = URLComponents(string: "https://api.spotify.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "type", value: "track"),
            URLQueryItem(name: "limit", value: "20")
        ]
        guard let url = components.url else { throw PulseMusicSearchError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw PulseMusicSearchError.spotifyRequestFailed(http.statusCode)
        }
        let decoded = try JSONDecoder().decode(SpotifySearchResponse.self, from: data)
        return (decoded.tracks?.items ?? []).map { track in
            PulseMusicAttachment(
                provider: .spotify,
                trackId: track.id,
                title: track.name,
                artistName: track.artists.map(\.name).joined(separator: ", "),
                artworkURL: track.album?.images.first?.url,
                previewURL: track.preview_url,
                externalURL: track.external_urls?.spotify ?? "https://open.spotify.com/track/\(track.id)"
            )
        }
    }

    private func spotifyAccessToken() async throws -> String {
        if let spotifyToken,
           let spotifyTokenExpiresAt,
           spotifyTokenExpiresAt > Date().addingTimeInterval(60) {
            return spotifyToken
        }

        let id = PulseExperimental.spotifyClientId.trimmingCharacters(in: .whitespacesAndNewlines)
        let secret = PulseExperimental.spotifyClientSecret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "https://accounts.spotify.com/api/token") else {
            throw PulseMusicSearchError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        let basic = Data("\(id):\(secret)".utf8).base64EncodedString()
        request.setValue("Basic \(basic)", forHTTPHeaderField: "Authorization")
        request.httpBody = Data("grant_type=client_credentials".utf8)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw PulseMusicSearchError.spotifyAuthFailed
        }
        let decoded = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        spotifyToken = decoded.access_token
        spotifyTokenExpiresAt = Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        return decoded.access_token
    }
}

enum PulseMusicSearchError: LocalizedError {
    case invalidURL
    case appleMusicDenied
    case appleMusicUnavailable
    case spotifyCredentialsMissing
    case spotifyAuthFailed
    case spotifyRequestFailed(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "URL de busca inválida."
        case .appleMusicDenied:
            return "Permita o acesso ao Apple Music em Ajustes para buscar faixas."
        case .appleMusicUnavailable:
            return "Apple Music indisponível neste build (MusicKit). Use Deezer ou Spotify."
        case .spotifyCredentialsMissing:
            return "Configure Client ID e Secret do Spotify em Perfil → Labs."
        case .spotifyAuthFailed:
            return "Falha ao autenticar no Spotify. Verifique as credenciais em Labs."
        case .spotifyRequestFailed(let code):
            return "Spotify retornou erro \(code)."
        }
    }
}

// MARK: - Deezer DTOs

private struct DeezerSearchResponse: Decodable {
    let data: [DeezerTrack]
}

private struct DeezerTrack: Decodable {
    let id: Int
    let title: String
    let link: String?
    let preview: String?
    let artist: DeezerArtist
    let album: DeezerAlbum?
}

private struct DeezerArtist: Decodable {
    let name: String
}

private struct DeezerAlbum: Decodable {
    let cover: String?
    let cover_medium: String?
}

// MARK: - Spotify DTOs

private struct SpotifyTokenResponse: Decodable {
    let access_token: String
    let expires_in: Int
}

private struct SpotifySearchResponse: Decodable {
    let tracks: SpotifyTracksPage?
}

private struct SpotifyTracksPage: Decodable {
    let items: [SpotifyTrack]
}

private struct SpotifyTrack: Decodable {
    let id: String
    let name: String
    let preview_url: String?
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum?
    let external_urls: SpotifyExternalURLs?
}

private struct SpotifyArtist: Decodable {
    let name: String
}

private struct SpotifyAlbum: Decodable {
    let images: [SpotifyImage]
}

private struct SpotifyImage: Decodable {
    let url: String
}

private struct SpotifyExternalURLs: Decodable {
    let spotify: String?
}
