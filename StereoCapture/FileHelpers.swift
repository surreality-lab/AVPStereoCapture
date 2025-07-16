//
//  FileHelpers.swift
//  StereoCapture
//
//  Created by Griffin Hurt on 6/30/25.
//

import Foundation
import simd

class FileHelpers {
    static func getNextURLs() -> (video: URL, data: URL) {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let videosURL = documentsURL.appendingPathComponent("Video Captures")
        let videoDataFolder = documentsURL.appendingPathComponent("Video Data")
        try? FileManager.default.createDirectory(at: videosURL, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: videoDataFolder, withIntermediateDirectories: true)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
        formatter.timeZone = .current
        
        let timestamp = formatter.string(from: Date())
        
        let videoURL = videosURL.appendingPathComponent("video-\(timestamp).mp4")
        let dataURL = videoDataFolder.appendingPathComponent("data-\(timestamp).json")
        
        return (videoURL, dataURL)
    }
    
    struct Matrix3x3 : Codable {
        let m00 : Float
        let m10 : Float
        let m20 : Float
        let m01 : Float
        let m11 : Float
        let m21 : Float
        let m02 : Float
        let m12 : Float
        let m22 : Float
        
        init(mat: simd_float3x3) {
            m00 = mat.columns.0.x
            m10 = mat.columns.0.y
            m20 = mat.columns.0.z
            m01 = mat.columns.1.x
            m11 = mat.columns.1.y
            m21 = mat.columns.1.z
            m02 = mat.columns.2.x
            m12 = mat.columns.2.y
            m22 = mat.columns.2.z
        }
    }
    
    struct Matrix4x4 : Codable {
        let m00 : Float
        let m10 : Float
        let m20 : Float
        let m30 : Float
        let m01 : Float
        let m11 : Float
        let m21 : Float
        let m31 : Float
        let m02 : Float
        let m12 : Float
        let m22 : Float
        let m32 : Float
        let m03 : Float
        let m13 : Float
        let m23 : Float
        let m33 : Float
        
        init(mat: simd_float4x4) {
            m00 = mat.columns.0.x
            m10 = mat.columns.0.y
            m20 = mat.columns.0.z
            m30 = mat.columns.0.w
            m01 = mat.columns.1.x
            m11 = mat.columns.1.y
            m21 = mat.columns.1.z
            m31 = mat.columns.1.w
            m02 = mat.columns.2.x
            m12 = mat.columns.2.y
            m22 = mat.columns.2.z
            m32 = mat.columns.2.w
            m03 = mat.columns.3.x
            m13 = mat.columns.3.y
            m23 = mat.columns.3.z
            m33 = mat.columns.3.w
        }
    }
    
    struct VideoData : Codable {
        let left_intrinsics : Matrix3x3
        let left_extrinsics : Matrix4x4
        let right_intrinsics : Matrix3x3
        let right_extrinsics : Matrix4x4
        
        init(left_intrinsics: Matrix3x3, left_extrinsics: Matrix4x4, right_intrinsics: Matrix3x3, right_extrinsics: Matrix4x4) {
            self.left_intrinsics = left_intrinsics
            self.left_extrinsics = left_extrinsics
            self.right_intrinsics = right_intrinsics
            self.right_extrinsics = right_extrinsics
        }
    }
    
    static func saveVideoData(data: VideoData, url: URL) throws {
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(data)
        try jsonData.write(to: url)
    }
}
