import Foundation

enum UnixSocketServerError: Error {
    case cannotCreateSocket
    case cannotBind(reason: String)
    case cannotListen
}

final class UnixSocketServer {
    private let socketPath: String
    private let onCommand: @Sendable (IslandCommand) -> Void
    private let acceptQueue = DispatchQueue(label: "agentch.socket.accept", qos: .utility)

    private var serverSocket: Int32 = -1
    private var isRunning = false

    init(socketPath: String, onCommand: @escaping @Sendable (IslandCommand) -> Void) {
        self.socketPath = socketPath
        self.onCommand = onCommand
    }

    func start() throws {
        guard !isRunning else { return }

        unlink(socketPath)

        let socketDescriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            throw UnixSocketServerError.cannotCreateSocket
        }
        serverSocket = socketDescriptor

        var address = makeAddress(path: socketPath)
        let bindStatus = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(serverSocket, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }

        guard bindStatus == 0 else {
            let reason = String(cString: strerror(errno))
            close(serverSocket)
            serverSocket = -1
            throw UnixSocketServerError.cannotBind(reason: reason)
        }

        guard listen(serverSocket, 5) == 0 else {
            close(serverSocket)
            serverSocket = -1
            throw UnixSocketServerError.cannotListen
        }

        isRunning = true
        acceptQueue.async { [weak self] in
            self?.acceptLoop()
        }
    }

    func stop() {
        guard isRunning else {
            unlink(socketPath)
            return
        }

        isRunning = false
        if serverSocket >= 0 {
            shutdown(serverSocket, SHUT_RDWR)
            close(serverSocket)
            serverSocket = -1
        }
        unlink(socketPath)
    }

    private func acceptLoop() {
        while isRunning {
            let clientSocket = accept(serverSocket, nil, nil)
            if clientSocket < 0 {
                if errno == EINTR { continue }
                if !isRunning { break }
                continue
            }
            handleClient(clientSocket)
        }
    }

    private func handleClient(_ clientSocket: Int32) {
        defer { close(clientSocket) }

        guard let line = readLine(from: clientSocket) else {
            return
        }

        guard let command = IslandCommand(jsonLine: line) else {
            return
        }

        onCommand(command)

        _ = "OK\n".withCString { pointer in
            write(clientSocket, pointer, 3)
        }
    }

    private func readLine(from clientSocket: Int32) -> Data? {
        var data = Data()
        var byte: UInt8 = 0

        while true {
            let bytesRead = read(clientSocket, &byte, 1)
            if bytesRead <= 0 { break }
            if byte == 0x0A { break }
            data.append(byte)

            if data.count > 32_768 {
                break
            }
        }

        return data.isEmpty ? nil : data
    }

    private func makeAddress(path: String) -> sockaddr_un {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)

        let pathBytes = path.utf8CString
        let maxLength = MemoryLayout.size(ofValue: address.sun_path)

        withUnsafeMutablePointer(to: &address.sun_path) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: maxLength) { chars in
                chars.initialize(repeating: 0, count: maxLength)
                for (index, byte) in pathBytes.enumerated() where index < maxLength {
                    chars[index] = byte
                }
            }
        }

        return address
    }
}
