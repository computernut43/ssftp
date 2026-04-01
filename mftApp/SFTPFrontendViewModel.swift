import Foundation
import AppKit
import Combine
import UniformTypeIdentifiers
import mft

@MainActor
final class SFTPFrontendViewModel: ObservableObject {
    @Published var host = ""
    @Published var port = "22"
    @Published var username = ""
    @Published var password = ""
    @Published var remotePath = "."

    @Published private(set) var isConnected = false
    @Published private(set) var isBusy = false
    @Published private(set) var statusMessage = "Not connected"
    @Published private(set) var items: [MFTSftpItem] = []

    private var connection: MFTSftpConnection?

    func connect() {
        guard !isBusy else { return }
        guard let portNumber = Int(port), !host.isEmpty, !username.isEmpty else {
            statusMessage = "Provide host, port and username."
            return
        }

        isBusy = true
        statusMessage = "Connecting..."

        Task {
            do {
                let conn = MFTSftpConnection(
                    hostname: host,
                    port: portNumber,
                    username: username,
                    password: password
                )
                try conn.connect()
                try conn.authenticate()

                connection = conn
                isConnected = true
                statusMessage = "Connected"

                try refreshDirectory()
            } catch {
                connection?.disconnect()
                connection = nil
                isConnected = false
                statusMessage = "Connection failed: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    func disconnect() {
        connection?.disconnect()
        connection = nil
        items = []
        isConnected = false
        statusMessage = "Disconnected"
    }

    func refreshDirectory() throws {
        guard let connection else {
            statusMessage = "Not connected"
            return
        }

        isBusy = true
        defer { isBusy = false }

        let directoryItems = try connection.contentsOfDirectory(atPath: remotePath, maxItems: 0)
        items = directoryItems
        statusMessage = "Loaded \(directoryItems.count) item(s) from \(remotePath)"
    }

    func refreshDirectoryAction() {
        Task {
            do {
                try refreshDirectory()
            } catch {
                statusMessage = "Refresh failed: \(error.localizedDescription)"
            }
        }
    }

    func uploadFile() {
        guard let connection else {
            statusMessage = "Not connected"
            return
        }

        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let sourceURL = panel.url else {
            return
        }

        isBusy = true
        statusMessage = "Uploading \(sourceURL.lastPathComponent)..."

        Task {
            do {
                let destination = normalizedRemoteFilePath(fileName: sourceURL.lastPathComponent)
                try connection.uploadFile(atPath: sourceURL.path, toFileAtPath: destination, progress: nil)
                try refreshDirectory()
                statusMessage = "Uploaded to \(destination)"
            } catch {
                statusMessage = "Upload failed: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    func downloadSelectedItem(_ item: MFTSftpItem?) {
        guard let connection else {
            statusMessage = "Not connected"
            return
        }
        guard let item, !item.isDirectory else {
            statusMessage = "Select a file to download."
            return
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = item.filename
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [.data]
        }

        guard panel.runModal() == .OK, let targetURL = panel.url else {
            return
        }

        FileManager.default.createFile(atPath: targetURL.path, contents: nil)

        isBusy = true
        statusMessage = "Downloading \(item.filename)..."

        Task {
            do {
                let remoteFile = normalizedRemoteFilePath(fileName: item.filename)
                try connection.downloadFile(atPath: remoteFile, toFileAtPath: targetURL.path, progress: nil)
                statusMessage = "Downloaded to \(targetURL.path)"
            } catch {
                statusMessage = "Download failed: \(error.localizedDescription)"
            }
            isBusy = false
        }
    }

    private func normalizedRemoteFilePath(fileName: String) -> String {
        remotePath == "/" ? "/\(fileName)" : "\(remotePath)/\(fileName)"
    }
}
