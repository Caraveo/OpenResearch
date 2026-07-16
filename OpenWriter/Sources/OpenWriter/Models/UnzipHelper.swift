import Foundation

public struct UnzipHelper {
    public static func unzip(zipPath: String, to destinationPath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", "-q", "-d", destinationPath, zipPath]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("Error unzipping: \(error)")
            return false
        }
    }
}