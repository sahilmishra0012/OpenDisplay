import Foundation
import CoreGraphics

/// Smooth brightness transitions — animates DDC changes in steps
class SmoothTransition {
    /// Smoothly transition a DDC value over duration
    static func animate(command: DDCCommand, to target: UInt16, for displayID: CGDirectDisplayID,
                        steps: Int = 10, duration: TimeInterval = 0.3) {
        guard let current = DDCControl.read(command: command, for: displayID) else {
            DDCControl.write(command: command, value: target, for: displayID)
            return
        }

        let start = Double(current.current)
        let end = Double(target)
        let delta = (end - start) / Double(steps)
        let interval = duration / Double(steps)

        for step in 1...steps {
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + interval * Double(step)) {
                let value = UInt16(max(0, min(Double(current.max), start + delta * Double(step))))
                DDCControl.write(command: command, value: value, for: displayID)
            }
        }
    }

    /// Smoothly set brightness with OSD notification
    static func setBrightness(_ value: UInt16, for displayID: CGDirectDisplayID) {
        animate(command: .brightness, to: value, for: displayID)
    }

    static func setContrast(_ value: UInt16, for displayID: CGDirectDisplayID) {
        animate(command: .contrast, to: value, for: displayID)
    }

    static func setVolume(_ value: UInt16, for displayID: CGDirectDisplayID) {
        animate(command: .volume, to: value, for: displayID)
    }
}
