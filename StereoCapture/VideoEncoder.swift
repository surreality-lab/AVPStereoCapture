//
//  VideoEncoder.swift
//  StereoCapture
//
//  Created by Griffin Hurt on 6/30/25.
//

import AVFoundation
import CoreVideo

class VideoEncoder {
    private var writer: AVAssetWriter
    private var input: AVAssetWriterInput
    private var adaptor: AVAssetWriterInput.PixelBufferReceiver
    private var startTime: CMTime?
    
    public let width: Int
    public let height: Int
    public let fps: Int
    public let saveURL: URL
    
    init(outputURL: URL, width: Int, height: Int, fps: Int = 30) throws {
        self.width = width
        self.height = height
        self.fps = fps
        self.saveURL = outputURL
        
        writer = try AVAssetWriter(url: outputURL, fileType: .mp4)
        
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ]
        
        input = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        input.expectsMediaDataInRealTime = true
        
        let sourcePixelBufferAttributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
            size: .init(width: width, height: height)
        )
        
        
        guard writer.canAdd(input) else {
            throw NSError(domain: "VideoEncoder", code: 1)
        }
        writer.add(input)
        
        adaptor = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: sourcePixelBufferAttributes)
    }
    
    func start() throws {
        // Try to start writing
        do {
            try writer.start()
            writer.startSession(atSourceTime: .zero)
            startTime = .zero
        } catch {
            throw writer.error ?? error
        }
        
        // Start the session and set the start time to zero
        writer.startSession(atSourceTime: .zero)
        startTime = .zero
    }
    
    func append(pixelBuffer: CVReadOnlyPixelBuffer, at time: CMTime) async throws {
        try await adaptor.append(pixelBuffer, with: time);
    }
    
    func finish(completion: @escaping () -> Void) {
        input.markAsFinished()
        writer.finishWriting {
            completion()
        }
    }
}
