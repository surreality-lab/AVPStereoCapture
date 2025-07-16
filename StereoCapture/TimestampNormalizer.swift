//
//  TimestampNormalizer.swift
//  StereoCapture
//
//  Created by Griffin Hurt on 6/30/25.
//

import CoreMedia

class TimestampNormalizer {
    private var startTime: TimeInterval?
    private let timescale: CMTimeScale

    init(timescale: CMTimeScale = 600) {
        self.timescale = timescale
    }

    /// Normalize an absolute `TimeInterval` (e.g., from a sensor or system clock) to a CMTime relative to the first call.
    func normalize(_ timestamp: TimeInterval) -> CMTime {
        if startTime == nil {
            startTime = timestamp
        }
        let delta = timestamp - (startTime ?? 0)
        return CMTime(seconds: delta, preferredTimescale: timescale)
    }
}

