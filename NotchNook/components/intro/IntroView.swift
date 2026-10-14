//
//  IntroView.swift
//  NotchNook
//
//  Created by Igor Marcossi on 01/06/24.
//

import SwiftUI
import Lottie
import Defaults

struct IntroView: View {
    @State private var tutorial = false
    @Environment(\.notchSize) private var notchSize
    @Default(.intro) private var intro
    var body: some View {
        ZStack {
            Group {
                if tutorial {
                    TutorialView()
                } else {
                    HelloView(tutorial: $tutorial)
                }
            }
        }
        .padding(.top, notchSize.height)
        .foregroundStyle(.nonShockingWhite)
    }
}
