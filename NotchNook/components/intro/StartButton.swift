//
//  StartButton.swift
//  NotchNook
//
//  Created by Igor Marcossi on 01/06/24.
//

import SwiftUI
import Defaults

struct StartButton: View {
    @Default(.intro) private var intro
    var body: some View {
        Button("Start") { intro = false }
    }
}
