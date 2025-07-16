//
//  Extensions.swift
//  StereoCapture
//
//  Created by Griffin Hurt on 6/30/25.
//


import SwiftUI

extension CVReadOnlyPixelBuffer {
    var image: Image? {
        return self.withUnsafeBuffer { buffer in
            let ciImage = CIImage(cvPixelBuffer: buffer)
            let context = CIContext(options: nil)
            
            guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
                return nil
            }

            let uiImage = UIImage(cgImage: cgImage)

            return Image(uiImage: uiImage)
        }
    }
}
