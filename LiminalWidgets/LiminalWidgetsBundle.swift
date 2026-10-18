import SwiftUI
import WidgetKit

/// Liminal's extension: today it draws the Live Activity (Dynamic Island and Lock Screen).
/// Home Screen widgets can be added here later.
@main
struct LiminalWidgetsBundle: WidgetBundle {
    var body: some Widget {
        LiminalLiveActivity()
    }
}
