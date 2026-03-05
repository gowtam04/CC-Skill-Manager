import Foundation

struct SyncManifest: Codable, Sendable {
    var lastSyncDate: Date
    var lastSyncDeviceID: String
    var skills: [String: SyncManifestSkillEntry]
    var knownDeviceIDs: Set<String>

    init(lastSyncDate: Date, lastSyncDeviceID: String, skills: [String: SyncManifestSkillEntry], knownDeviceIDs: Set<String> = []) {
        self.lastSyncDate = lastSyncDate
        self.lastSyncDeviceID = lastSyncDeviceID
        self.skills = skills
        self.knownDeviceIDs = knownDeviceIDs
    }
}

struct SyncManifestSkillEntry: Codable, Sendable {
    var isEnabled: Bool
    var files: [String: SyncManifestFileEntry]
}

struct SyncManifestFileEntry: Codable, Sendable {
    var contentHash: String
    var size: Int
    var modificationDate: Date
}

struct SyncLockFile: Codable, Sendable {
    let deviceID: String
    let deviceName: String
    let acquiredAt: Date
}

struct SyncConflict: Identifiable, Sendable {
    let id = UUID()
    let skillName: String
    let reason: SyncConflictReason
    let localModificationDate: Date?
    let remoteModificationDate: Date?

    init(skillName: String, reason: SyncConflictReason, localModificationDate: Date? = nil, remoteModificationDate: Date? = nil) {
        self.skillName = skillName
        self.reason = reason
        self.localModificationDate = localModificationDate
        self.remoteModificationDate = remoteModificationDate
    }
}

enum SyncConflictReason: Sendable {
    case deletedRemotelyButModifiedLocally
    case deletedLocallyButModifiedRemotely
    case bothModified
    case enabledStateConflict
}

enum ConflictResolution: Sendable {
    case keepLocal
    case keepRemote
}

struct SyncReport: Sendable {
    var copiedToRemote: [String] = []
    var copiedToLocal: [String] = []
    var deletedFromRemote: [String] = []
    var deletedFromLocal: [String] = []
    var conflicts: [SyncConflict] = []
    var errors: [SyncError] = []
    var debugSummary: String = ""
}

struct SyncError: Sendable {
    let skillName: String
    let message: String
}
