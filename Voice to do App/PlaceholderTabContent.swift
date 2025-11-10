import SwiftUI

struct PlaceholderTabContent: View {
    let selectedIndex: Int

    var body: some View {
        Group {
            switch selectedIndex {
            case 0:
                SettingsPlaceholderView()
            case 1:
                HistoryPlaceholderView()
            case 3:
                PlannedPlaceholderView()
            case 4:
                VoicemailPlaceholderView()
            default:
                ZStack { Color.clear }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

