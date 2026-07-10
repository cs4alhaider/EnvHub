import Foundation

/// On-disk facts about one env file — what the editor's file-details popover shows.
/// Fields are optional because the file can vanish (or deny access) between listing
/// and inspection.
public struct EnvFileInfo: Sendable, Equatable {
    public var createdAt: Date?
    public var modifiedAt: Date?
    public var sizeBytes: Int?
    public var isWritable: Bool

    /// The `.bak` sibling written by backup-on-save, if one exists.
    public var backupFileName: String?
    public var backupModifiedAt: Date?

    public init(
        createdAt: Date? = nil,
        modifiedAt: Date? = nil,
        sizeBytes: Int? = nil,
        isWritable: Bool = true,
        backupFileName: String? = nil,
        backupModifiedAt: Date? = nil
    ) {
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.sizeBytes = sizeBytes
        self.isWritable = isWritable
        self.backupFileName = backupFileName
        self.backupModifiedAt = backupModifiedAt
    }

    /// Reads the file's attributes, plus its backup's if one exists.
    ///
    /// `@concurrent` — touches the filesystem, so it always runs off the caller's actor.
    @concurrent
    public static func load(for url: URL) async -> EnvFileInfo {
        let keys: Set<URLResourceKey> = [.creationDateKey, .contentModificationDateKey, .fileSizeKey]
        let values = try? url.resourceValues(forKeys: keys)
        var info = EnvFileInfo(
            createdAt: values?.creationDate,
            modifiedAt: values?.contentModificationDate,
            sizeBytes: values?.fileSize,
            isWritable: FileManager.default.isWritableFile(atPath: url.path(percentEncoded: false))
        )
        let backup = EnvFileService.backupURL(for: url)
        if let backupValues = try? backup.resourceValues(forKeys: [.contentModificationDateKey]) {
            info.backupFileName = backup.lastPathComponent
            info.backupModifiedAt = backupValues.contentModificationDate
        }
        return info
    }
}
