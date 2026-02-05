import Cocoa
import SwiftUI

// Enable high DPI
UserDefaults.standard.register(defaults: ["AppleFontSmoothing": 2])

// Create app instance
let app = NSApplication.shared

// Set as accessory app (no dock icon)
app.setActivationPolicy(.accessory)

// Activate app
app.activate(ignoringOtherApps: true)

// Create delegate AFTER activation policy
let delegate = AppDelegate()
app.delegate = delegate

// Start the app
NSApp.run()
