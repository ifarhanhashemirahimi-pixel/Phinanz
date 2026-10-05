//
//  Tips.swift
//  Phinanz
//
//  TipKit hints shown once to new users.
//

import SwiftUI
import TipKit

struct SwipeDaysTip: Tip {
    var title: Text { Text("Move Between Days") }
    var message: Text? { Text("Swipe left or right, or tap a day in the week above.") }
    var image: Image? { Image(systemName: "hand.draw") }
}

struct AIImportTip: Tip {
    var title: Text { Text("Let AI Do the Typing") }
    var message: Text? { Text("Turn a receipt, a bank statement or a voice note into entries.") }
    var image: Image? { Image(systemName: "sparkles") }
}
