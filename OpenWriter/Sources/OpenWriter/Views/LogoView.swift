import SwiftUI

public struct LogoView: View {
    public var size: CGFloat = 24
    
    public init(size: CGFloat = 24) {
        self.size = size
    }
    
    public var body: some View {
        ZStack {
            // Three rounded rectangles rotated to form a 6-pointed academic asterisk logo
            ForEach(0..<3) { i in
                RoundedRectangle(cornerRadius: size * 0.15, style: .continuous)
                    .fill(Color.orange)
                    .frame(width: size * 0.28, height: size)
                    .rotationEffect(.degrees(Double(i) * 60.0))
            }
        }
        .frame(width: size, height: size)
    }
}

struct LogoView_Previews: PreviewProvider {
    static var previews: some View {
        LogoView(size: 100)
            .padding()
    }
}
