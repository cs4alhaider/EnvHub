import Foundation
import Parser

/// Errors from materializing an imported export to disk.
public enum EnvExportError: Error, Equatable {
    case fileExists(URL)
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
        let payloads = try files.map { file -> EnvFilePayload in
            let doc = try EnvParser.read(contentsOf: file.path)
            return EnvFilePayload(
                name: file.fileName,
                kind: file.kind.rawValue,
                variables: doc.variables.map { EnvVarPayload(key: $0.key, value: $0.value) },
                content: EnvParser.serialize(doc)
            )
        }
        return EnvExport(type: .project, name: projectName, files: payloads)
    }

    /// Write an export's files into `folder`. Prefers the captured raw text (faithful),
    /// falling back to rebuilding from key/value pairs. Refuses to overwrite unless asked.
    @discardableResult
    public static func materialize(_ export: EnvExport, into folder: URL, overwrite: Bool = false) throws -> [URL] {
        let fm = FileManager.default
        var written: [URL] = []
        for file in export.files {
            let url = folder.appendingPathComponent(file.name)
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
