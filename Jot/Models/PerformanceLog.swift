//
//  PerformanceLog.swift
//  Jot
//
//  Shared signpost log for the app's hot paths (#142). The markers show up
//  by name in Instruments under "Points of Interest" — see docs/PERFORMANCE.md
//  for the profiling playbook.
//

import Foundation
import os.signpost

enum PerformanceLog {
    static let log = OSLog(subsystem: "com.brian.jot", category: .pointsOfInterest)
}
