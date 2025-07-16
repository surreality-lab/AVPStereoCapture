//
//  ContentView.swift
//  StereoCapture
//
//  Created by Griffin Hurt on 6/30/25.
//

import SwiftUI
import RealityKit
import AVFoundation


struct ContentView: View {
    @Environment(AppModel.self) var appModel
    
    @State var isRecording = false
    @State var recordingStartTime: Date?
    @State var timer: Timer?
    @State var elapsedTime: TimeInterval = 0

    var body: some View {
        VStack {
            if appModel.immersiveSpaceState == .open {
                MainCameraView(isRecording: $isRecording)
            } else {
                Image(systemName: "camera")
                    .resizable()
                    .scaledToFit()
            }
            if appModel.immersiveSpaceState == .closed {
                ToggleImmersiveSpaceButton()
            }
            if appModel.immersiveSpaceState == .open {
                Button(action: {
                    isRecording.toggle()
                    if isRecording {
                        // Start timing
                        recordingStartTime = Date()
                        elapsedTime = 0
                        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                            if let start = recordingStartTime {
                                elapsedTime = Date().timeIntervalSince(start)
                            }
                        }
                    } else {
                        // Stop timing
                        timer?.invalidate()
                        timer = nil
                    }
                }) {
                    ZStack {
                        if isRecording {
                            // Stop button
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                                .padding(20)
                                .background(Circle().fill(Color.red))
                        } else {
                            // Red recording circle
                            Circle()
                                .fill(Color.red)
                                .frame(width: 64, height: 64)
                        }
                    }
                }
                .buttonStyle(.plain)
                
                if isRecording {
                    Text(" \(formatElapsedTime(elapsedTime))")
                        .monospacedDigit()
                        .font(.title)
                        .foregroundColor(.white)
                }
            }
        }
        .padding()
    }
    
    func formatElapsedTime(_ interval: TimeInterval) -> String {
        let seconds = Int(interval) % 60
        let minutes = Int(interval) / 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview(windowStyle: .automatic) {
    ContentView()
        .environment(AppModel())
}
