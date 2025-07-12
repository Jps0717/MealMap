import Foundation
import SwiftUI

// MARK: - Simple Crash Reporting Service
class CrashReportingService {
    static let shared = CrashReportingService()
    
    private init() {
        setupCrashReporting()
    }
    
    private func setupCrashReporting() {
        NSSetUncaughtExceptionHandler { exception in
            debugError("Uncaught exception: \(exception)")
            CrashReportingService.shared.logCrash("Uncaught Exception: \(exception)")
        }
        
        signal(SIGABRT) { signal in
            debugError("SIGABRT received")
            CrashReportingService.shared.logCrash("Signal SIGABRT received")
        }
        
        signal(SIGILL) { signal in
            debugError("SIGILL received")
            CrashReportingService.shared.logCrash("Signal SIGILL received")
        }
        
        signal(SIGSEGV) { signal in
            debugError("SIGSEGV received")
            CrashReportingService.shared.logCrash("Signal SIGSEGV received")
        }
        
        signal(SIGFPE) { signal in
            debugError("SIGFPE received")
            CrashReportingService.shared.logCrash("Signal SIGFPE received")
        }
        
        signal(SIGBUS) { signal in
            debugError("SIGBUS received")
            CrashReportingService.shared.logCrash("Signal SIGBUS received")
        }
    }
    
    func logCrash(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        
        // Get auth status safely
        Task { @MainActor in
            let authStatus = AuthenticationManager.shared.isAuthenticated ? "Authenticated" : "Not Authenticated"
            
            let crashReport = """
            CRASH REPORT - \(timestamp)
            \(message)
            
            App State:
            - Network: \(NetworkMonitor.shared.isConnected ? "Connected" : "Disconnected")
            - Auth: \(authStatus)
            - Location: \(LocationManager.shared.authorizationStatus)
            
            ---
            """
            
            debugError("CRASH: \(crashReport)")
            
            // Store crash report locally
            self.storeCrashReport(crashReport)
        }
    }
    
    private func storeCrashReport(_ report: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let crashLogURL = documentsPath.appendingPathComponent("crash_logs.txt")
        
        do {
            let existingContent = (try? String(contentsOf: crashLogURL)) ?? ""
            let newContent = existingContent + "\n" + report
            try newContent.write(to: crashLogURL, atomically: true, encoding: .utf8)
        } catch {
            print("Failed to write crash report: \(error)")
        }
    }
    
    func getCrashReports() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let crashLogURL = documentsPath.appendingPathComponent("crash_logs.txt")
        
        return (try? String(contentsOf: crashLogURL)) ?? "No crash reports found"
    }
    
    func clearCrashReports() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let crashLogURL = documentsPath.appendingPathComponent("crash_logs.txt")
        
        try? FileManager.default.removeItem(at: crashLogURL)
    }
}