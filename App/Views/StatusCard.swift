import SwiftUI

/// The one card style for errors, progress, completion and notices.
struct StatusCard<Content: View>: View {
    enum Kind {
        case info, success, warning, critical

        var color: Color {
            switch self {
            case .info: .accentColor
            case .success: .green
            case .warning: .orange
            case .critical: .red
            }
        }
    }

    let kind: Kind
    let systemImage: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(kind.color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 6) {
                content
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(kind.color.opacity(0.18)))
    }
}
