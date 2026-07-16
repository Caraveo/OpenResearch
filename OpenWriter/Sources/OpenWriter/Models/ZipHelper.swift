import Foundation

public struct ZipHelper {
    public static func zip(directoryPath: String, to zipPath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        // zip -r -j -q zipPath directoryPath
        process.arguments = ["-r", "-j", "-q", zipPath, directoryPath]
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            print("Error zipping: \(error)")
            return false
        }
    }
}
