import SwiftUI

struct OriginalLoungeTVView: View {
    @ObservedObject var play: OriginalPlaySession

    var body: some View {
        VStack(spacing: 18) {
            Text("Lounge television")
                .font(NovelStyle.body)
            Text("Choose a channel.")
                .font(NovelStyle.body)
            Button("Watch the cartoon") {
                play.loungeTVAction(.cartoon)
            }
            .buttonStyle(BookTextButtonStyle())
            .disabled(play.loungeTV?.isWaitingForResponse == true)
            Button("Watch the news") {
                play.loungeTVAction(.news)
            }
            .buttonStyle(BookTextButtonStyle())
            .disabled(play.loungeTV?.isWaitingForResponse == true)
            Spacer(minLength: 8)
            Button("Leave the television") {
                play.loungeTVAction(.leave)
            }
            .buttonStyle(BookTextButtonStyle())
            .disabled(play.loungeTV?.isWaitingForResponse == true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
