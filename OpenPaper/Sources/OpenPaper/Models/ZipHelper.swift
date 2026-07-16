import Foundation

public struct ZipHelper {
    /// Zips the contents of `directoryPath` into a zip at `zipPath`.
    /// Mirrors `zip -r -j` behaviour used by OpenWriter.
    public static func zip(directoryPath: String, to zipPath: String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
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

    /// Builds an EPUB-shaped archive: `mimetype` stored uncompressed as the first entry,
    /// followed by the rest of `directoryPath`'s tree (relative paths preserved).
    public static func zipEpub(directoryPath: String, to zipPath: String) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directoryPath) else { return false }

        // 1. Add mimetype first, with no compression (-0), no extra fields (-X).
        let addMime = Process()
        addMime.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        addMime.currentDirectoryPath = directoryPath
        addMime.arguments = ["-X", "-0", zipPath, "mimetype"]
        do {
            try addMime.run()
            addMime.waitUntilExit()
            if addMime.terminationStatus != 0 { return false }
        } catch {
            print("Error adding mimetype to epub: \(error)")
            return false
        }

        // 2. Append everything except mimetype, relative paths, default compression.
        let addRest = Process()
        addRest.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        addRest.currentDirectoryPath = directoryPath
        addRest.arguments = ["-r", "-X", "-q", zipPath, "META-INF", "OEBPS"]
        do {
            try addRest.run()
            addRest.waitUntilExit()
            return addRest.terminationStatus == 0
        } catch {
            print("Error adding OEBPS contents to epub: \(error)")
            return false
        }
    }
}