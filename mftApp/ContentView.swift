import SwiftUI
import mft

struct ContentView: View {
    @StateObject private var viewModel = SFTPFrontendViewModel()
    @State private var selectedID: String?

    private var selectedItem: MFTSftpItem? {
        viewModel.items.first { $0.filename == selectedID }
    }

    var body: some View {
        VStack(spacing: 12) {
            GroupBox("Connection") {
                VStack(spacing: 8) {
                    HStack {
                        TextField("Host", text: $viewModel.host)
                        TextField("Port", text: $viewModel.port)
                            .frame(width: 80)
                        TextField("Username", text: $viewModel.username)
                    }
                    SecureField("Password", text: $viewModel.password)

                    HStack {
                        TextField("Remote Path", text: $viewModel.remotePath)
                        Button("Connect") { viewModel.connect() }
                            .disabled(viewModel.isConnected || viewModel.isBusy)
                        Button("Disconnect") { viewModel.disconnect() }
                            .disabled(!viewModel.isConnected || viewModel.isBusy)
                        Button("Refresh") { viewModel.refreshDirectoryAction() }
                            .disabled(!viewModel.isConnected || viewModel.isBusy)
                    }
                }
            }

            GroupBox("Remote Items") {
                List(selection: $selectedID) {
                    ForEach(viewModel.items, id: \.filename) { item in
                        HStack {
                            Image(systemName: item.isDirectory ? "folder" : "doc")
                            Text(item.filename)
                            Spacer()
                            Text(item.isDirectory ? "Directory" : "File")
                                .foregroundStyle(.secondary)
                        }
                        .tag(item.filename)
                    }
                }
                .frame(minHeight: 280)
            }

            HStack {
                Button("Upload File") { viewModel.uploadFile() }
                    .disabled(!viewModel.isConnected || viewModel.isBusy)
                Button("Download Selected") { viewModel.downloadSelectedItem(selectedItem) }
                    .disabled(!viewModel.isConnected || viewModel.isBusy)
                Spacer()
                Text(viewModel.statusMessage)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(minWidth: 800, minHeight: 560)
    }
}
