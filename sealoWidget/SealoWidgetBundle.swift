import SwiftUI
import WidgetKit

/// Entry point for the widget extension binary. Registers every
/// Widget-kind in the bundle — the Live Activity and the home-screen
/// timeline widget live in the same extension, so both are listed here.
@main
struct SealoWidgetBundle: WidgetBundle {
    var body: some Widget {
        SealoLiveActivity()
        SealoHomeWidget()
    }
}
