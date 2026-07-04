import Foundation
import Parser

/// Errors from materializing an imported export to disk.
public enum EnvExportError: Error, Equatable {
    case fileExists(URL)
}

extension EnvExportError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .fileExists(let url): "“\(url.lastPathComponent)” already exists."
        }
    }
}

/// Builds `EnvExport` payloads from files on disk and materializes imported payloads
/// back to disk. The encryption itself lives in the `Crypto` target (`EnvCrypto`).
public enum EnvExporter {
    /// Payload for a single env file, capturing both key/value pairs and the raw text.
    public static func makeExport(fileURL: URL, kind: EnvKind?) throws -> EnvExport {
        let doc = try EnvParser.read(contentsOf: fileURL)
        let payload = EnvFilePayload(
            name: fileURL.lastPathComponent,
            kind: kind?.rawValue,
            variables: doc.variables.map { EnvVarPayload(key: $0.key, value: $0.value) },
            content: EnvParser.serialize(doc)
        )
        return EnvExport(type: .single, name: fileURL.lastPathComponent, files: [payload])
    }

    /// Payload for a whole project (all its env files).
    public static func makeExport(projectName: String, files: [EnvFile]) throws -> EnvExport {
        return EnvExport(
            type: .project,
            name: projectName,
            files: try payloads(for: files, project: nil)
        )
    }

    /// Payload for the whole library: every project's env files, each tagged with a
    /// uniquified project name (two projects named "web-app" become "web-app" and
    /// "web-app-2") so import can recreate one subfolder per project.
    public static func makeLibraryExport(name: String, projects: [Project]) throws -> EnvExport {
        var usedNames: [String: Int] = [:]
        var files: [EnvFilePayload] = []
        for project in projects {
            let count = (usedNames[project.name] ?? 0) + 1
            usedNames[project.name] = count
            let label = count == 1 ? project.name : "\(project.name)-\(count)"
            files.append(contentsOf: try payloads(for: project.files, project: label))
        }
        return EnvExport(type: .library, name: name, files: files)
    }

    private static func payloads(for files: [EnvFile], project: String?) throws -> [EnvFilePayload] {
        try files.map { file in
            let doc = try EnvParser.read(contentsOf: file.path)
            return EnvFilePayload(
                name: file.fileName,
                kind: file.kind.rawValue,
                variables: doc.variables.map { EnvVarPayload(key: $0.key, value: $0.value) },
                content: EnvParser.serialize(doc),
                project: project
            )
        }
    }

    /// Write an export's files into `folder`. Library files land in one subfolder per
    /// project; the raw captured text is preferred (faithful), falling back to
    /// rebuilding from key/value pairs. Refuses to overwrite unless asked.
    @discardableResult
    public static func materialize(_ export: EnvExport, into folder: URL, overwrite: Bool = false) throws -> [URL] {
        let fm = FileManager.default
        var written: [URL] = []
        for file in export.files {
            var destination = folder
            if let project = file.project, !project.isEmpty {
                destination = folder.appendingPathComponent(project, isDirectory: true)
                try fm.createDirectory(at: destination, withIntermediateDirectories: true)
            }
            let url = destination.appendingPathComponent(file.name)
            if fm.fileExists(atPath: url.path(percentEncoded: false)) && !overwrite {
                throw EnvExportError.fileExists(url)
            }
            let text: String
            if let content = file.content {
                text = content
            } else {
                let doc = EnvParser.applyEdits(
                    to: EnvDocument(lines: []),
                    variables: file.variables.map { EnvVar(key: $0.key, value: $0.value) }
                )
                text = EnvParser.serialize(doc)
            }
            try text.write(to: url, atomically: true, encoding: .utf8)
            written.append(url)
        }
        return written
    }
}
