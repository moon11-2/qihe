import SwiftUI

struct SealMark: View {
    let size: CGFloat

    var body: some View {
        Text("契")
            .font(QiheFont.seal(size: size * 0.54))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(QiheColor.seal)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
    }
}

struct QihePrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(QiheColor.navy)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }
}

struct PaperCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(QiheColor.card)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(QiheColor.line)
            )
    }
}

