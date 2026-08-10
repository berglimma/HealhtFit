import SwiftUI

struct DuoMemberAvatarView: View {
    let name: String
    var photoURL: String?
    var countryCode: String?
    var localImage: UIImage? = nil
    var size: CGFloat = 44

    private var flag: String {
        CountryOption.flagEmoji(for: countryCode ?? "")
    }

    private var initial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(1)).uppercased()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Group {
                if let localImage {
                    Image(uiImage: localImage)
                        .resizable()
                        .scaledToFill()
                } else if let photoURL, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholder
                        case .empty:
                            ProgressView()
                        @unknown default:
                            placeholder
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.accent.opacity(0.25), lineWidth: 1))

            Text(flag)
                .font(.system(size: max(12, size * 0.36)))
                .offset(x: -2, y: -3)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(name), \(flag)")
    }

    private var placeholder: some View {
        ZStack {
            Circle().fill(AppTheme.accent.opacity(0.2))
            Text(initial)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(AppTheme.accent)
        }
    }
}

/// Card compacto: foto em cima, nome embaixo.
struct DuoMemberCardView: View {
    let member: DuoTeamMember
    var localImage: UIImage? = nil

    private var shortName: String {
        let trimmed = member.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.components(separatedBy: " ").first ?? trimmed
    }

    var body: some View {
        VStack(spacing: 6) {
            DuoMemberAvatarView(
                name: member.name,
                photoURL: member.photoURL,
                countryCode: member.countryCode,
                localImage: localImage,
                size: 52
            )
            Text(shortName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .frame(maxWidth: 64)
        }
        .frame(width: 72)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(AppTheme.accent.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(member.name)
    }
}
