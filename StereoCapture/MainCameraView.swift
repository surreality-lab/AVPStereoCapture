//
//  MainCameraView.swift
//  StereoCapture
//
//  Created by Griffin Hurt on 6/30/25.
//

import SwiftUI
import ARKit
import CoreVideo
import CoreMedia

struct MainCameraView : View {
    @State private var arKitSession = ARKitSession()
    @State private var buffer: CVReadOnlyPixelBuffer?
    
    @State private var didError = false
    @State private var errorInfo: String = ""
    
    @State private var didSave = false
    @State private var saveLocation: String = ""
    
    @State private var leftIntrinsics: simd_float3x3?
    @State private var leftExtrinsics: simd_float4x4?
    @State private var rightIntrinsics: simd_float3x3?
    @State private var rightExtrinsics: simd_float4x4?
    
    @State private var bufferPool: CVMutablePixelBuffer.Pool?
    
    @State private var videoEncoder: VideoEncoder?
    @State private var timestampNormalizer: TimestampNormalizer?
    @Binding public var isRecording: Bool
    @State private var wasRecording = false
    
    let emptyImage = Image(systemName: "camera")
    
    private func stackBuffers(left: CVReadOnlyPixelBuffer, right: CVReadOnlyPixelBuffer) -> CVReadOnlyPixelBuffer? {
        let width = left.size.width + right.size.width
        let height = left.size.height

        // Allocate the pixel buffer pool if necessary
        if bufferPool == nil {
            bufferPool = try? CVMutablePixelBuffer.Pool(pixelBufferAttributes: .init(pixelFormatType: .init(rawValue: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange), size: .init(width: width, height: height)))
        }

        guard let pool = bufferPool else {
            didError = true
            errorInfo = "Failed to create CVMutablePixelBuffer.Pool"
            return nil
        }

        var outputBuffer : CVMutablePixelBuffer
        do {
            outputBuffer = try pool.makeMutablePixelBuffer()
        } catch {
            didError = true
            errorInfo = "Failed to allocate a CVMutablePixelBuffer from the pool"
            return nil
        }

        // I find this nested "accessUnsafeRawPlaneBytes" to be incredibly annoying (although very memory safe!)...
        left.accessUnsafeRawPlaneBytes{ leftPlanes in
            right.accessUnsafeRawPlaneBytes { rightPlanes in
                outputBuffer.accessUnsafeMutableRawPlaneBytes { outputPlanes in
                    guard leftPlanes.count == rightPlanes.count && rightPlanes.count == outputPlanes.count else {
                        didError = true
                        errorInfo = "Left and right buffers had different numbers of planes. Left had \(leftPlanes.count), right had \(rightPlanes.count)."
                        return
                    }
                    
                    for i in 0..<leftPlanes.count {
                        let leftBytes = leftPlanes[i].bytes
                        let rightBytes = rightPlanes[i].bytes
                        let outputBytes = outputPlanes[i].bytes
                        
                        let leftBytesPerRow = left.planeProperties[i].bytesPerRow
                        let rightBytesPerRow = right.planeProperties[i].bytesPerRow
                        let outputBytesPerRow = outputPlanes[i].properties.bytesPerRow
                        
                        let outputLeftWidth = leftPlanes[i].properties.size.width
                        let outputRightWidth = rightPlanes[i].properties.size.width
                        let outputRowWidth = outputLeftWidth + outputRightWidth
                        let pixelStride = outputPlanes[i].properties.bytesPerRow / outputPlanes[i].properties.size.width
                        
                        guard let leftBaseAddr = leftBytes.baseAddress,
                                let rightBaseAddr = rightBytes.baseAddress,
                              let outputBaseAddr = outputBytes.baseAddress else {
                            continue
                        }
                        
                        let planeHeight = outputPlanes[i].properties.size.height
                        
                        for row in 0..<planeHeight {
                            let leftRow = leftBaseAddr.advanced(by: row * leftBytesPerRow)
                            let rightRow = rightBaseAddr.advanced(by: row * rightBytesPerRow)
                            let outRow = outputBaseAddr.advanced(by: row * outputBytesPerRow)
                            
                            let leftCopyBytes = outputLeftWidth * pixelStride
                            let rightCopyBytes = outputRightWidth * pixelStride

                            memcpy(outRow, leftRow, leftCopyBytes)
                            memcpy(outRow.advanced(by: leftCopyBytes), rightRow, rightCopyBytes)
                        }
                    }
                }
            }
        }
        
        return CVReadOnlyPixelBuffer(outputBuffer)
    }
    
    var body: some View {
        let image = buffer?.image ?? emptyImage
        
        image
            .resizable()
            .scaledToFit()
            .task {
                // Check support for camera frame provider
                guard CameraFrameProvider.isSupported else {
                    didError = true
                    errorInfo = "CameraFrameProvider is not supported."
                    return
                }
                
                let cameraFrameProvider = CameraFrameProvider()
                do {
                    try await arKitSession.run([cameraFrameProvider])
                } catch {
                    didError = true
                    errorInfo = "Could not start AR session: \(error)"
                    return
                }
                
                // Pick the largest stereo rectified format
                let formats = CameraVideoFormat.supportedVideoFormats(for: .main, cameraPositions: [.left, .right])
                let stereoFormats = formats.filter { $0.cameraRectification == .stereoCorrected }
                let formatCandidate = stereoFormats.max { $0.frameSize.height > $1.frameSize.height }
                guard let format = formatCandidate else {
                    didError = true
                    errorInfo = "No stereo rectified camera format available"
                    return
                }
                
                
                // Start the camera frame provider
                guard let cameraFrameUpdates = cameraFrameProvider.cameraFrameUpdates(for: format) else {
                    didError = true
                    errorInfo = "Could not get camera frame updates for the highest resolution stereo format."
                    return
                }
                
                
                for await cameraFrame in cameraFrameUpdates {
                    // Guard both samples
                    guard let lSample = cameraFrame.sample(for: .left), let rSample = cameraFrame.sample(for: .right) else {
                        continue
                    }
                    
                    // Set the intrinsics and extrinsics if not set yet
                    if leftIntrinsics == nil { leftIntrinsics = lSample.parameters.intrinsics }
                    if leftExtrinsics == nil { leftExtrinsics = lSample.parameters.extrinsics }
                    if rightIntrinsics == nil { rightIntrinsics = rSample.parameters.intrinsics }
                    if rightExtrinsics == nil { rightExtrinsics = rSample.parameters.extrinsics }
                    
                    // Create the output buffer
                    buffer = stackBuffers(left: lSample.buffer, right: rSample.buffer)
                    
                    // If we've just started recording
                    if isRecording && !wasRecording {
                        let urls = FileHelpers.getNextURLs()
                        do {
                            videoEncoder = try VideoEncoder(outputURL: urls.video, width: buffer!.size.width, height: buffer!.size.height)
                            try videoEncoder!.start()
                        } catch {
                            didError = true
                            errorInfo = "Could not start video encoding: \(error)"
                            return
                        }
                        // Save the data file
                        let vd = FileHelpers.VideoData(left_intrinsics: FileHelpers.Matrix3x3(mat: leftIntrinsics!), left_extrinsics: FileHelpers.Matrix4x4(mat: leftExtrinsics!), right_intrinsics: FileHelpers.Matrix3x3(mat: rightIntrinsics!), right_extrinsics: FileHelpers.Matrix4x4(mat: rightExtrinsics!))
                        
                        do {
                            try FileHelpers.saveVideoData(data: vd, url: urls.data)
                        } catch {
                            didError = true
                            errorInfo = "Could not save video data: \(error)"
                            return
                        }
                        
                        // Create the ts normalizer
                        timestampNormalizer = TimestampNormalizer()
                        // We are now recording
                        wasRecording = true;
                    // We do this case here to avoid a huge hang on the first frame
                    } else if isRecording {
                        guard let coder = videoEncoder, let tsNormalizer = timestampNormalizer else {
                            didError = true
                            errorInfo = "Could not get video encoder or timestamp normalizer."
                            return
                        }
                        if let buf = buffer {
                            // Encode the buffer
                            let timecode = tsNormalizer.normalize(lSample.parameters.captureTimestamp)
                            do {
                                try await coder.append(pixelBuffer: buf, at: timecode)
                            } catch {
                                didError = true
                                errorInfo = "Could not append to video file: \(error)"
                                return
                            }
                        }
                    }

                    // If we've just stopped recording
                    if wasRecording && !isRecording {
                        guard let coder = videoEncoder else {
                            didError = true
                            errorInfo = "Could not get video encoder."
                            return
                        }
                        // Finish the encoding and show the saved dialog
                        coder.finish {
                            didSave = true
                        }
                        wasRecording = false
                    }
                }
                
            }.alert("Error", isPresented: $didError) {
                Button("OK") {}
            } message: {
                Text(errorInfo)
            }.alert("Video Saved", isPresented: $didSave) {
                Button("OK") {
                    didSave = false
                }
            } message: {
                Text("Video saved as \(videoEncoder?.saveURL.lastPathComponent ?? "[Error: No encoder!]")")
            }
    }
}
