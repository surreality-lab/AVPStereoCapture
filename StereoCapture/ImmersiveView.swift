//
//  ImmersiveView.swift
//  StereoCapture
//
//  Created by Griffin Hurt on 6/30/25.
//

import SwiftUI
import RealityKit

struct ImmersiveView: View {

    var body: some View {
        VStack {
            // Empty immersive view, use content view
        }
    }
}

#Preview(immersionStyle: .mixed) {
    ImmersiveView()
        .environment(AppModel())
}
