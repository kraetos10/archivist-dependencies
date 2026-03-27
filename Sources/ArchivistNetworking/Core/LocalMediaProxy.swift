import Foundation

public final class LocalMediaProxy: @unchecked Sendable {
    private let remoteURL: URL
    private var serverSocket: Int32 = -1
    private var port: UInt16 = 0
    private let queue = DispatchQueue(label: "com.archivist.mediaProxy")
    private let clientQueue = DispatchQueue(label: "com.archivist.mediaProxy.client", attributes: .concurrent)
    private var isRunning = false

    public init(remoteURL: URL) {
        self.remoteURL = remoteURL
    }

    public func start(completion: @escaping (URL?) -> Void) {
        queue.async { [self] in
            signal(SIGPIPE, SIG_IGN)

            serverSocket = socket(AF_INET, SOCK_STREAM, 0)
            guard serverSocket >= 0 else {
                completion(nil)
                return
            }

            var reuse: Int32 = 1
            setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

            var addr = sockaddr_in()
            addr.sin_family = sa_family_t(AF_INET)
            addr.sin_port = 0
            addr.sin_addr.s_addr = inet_addr("127.0.0.1")

            let bindResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    bind(serverSocket, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
            guard bindResult == 0 else {
                close(serverSocket)
                completion(nil)
                return
            }

            var boundAddr = sockaddr_in()
            var addrLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            _ = withUnsafeMutablePointer(to: &boundAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    getsockname(serverSocket, $0, &addrLen)
                }
            }
            port = UInt16(bigEndian: boundAddr.sin_port)

            listen(serverSocket, 5)
            isRunning = true

            let localURL = URL(string: "http://127.0.0.1:\(port)/media.mp4")
            completion(localURL)

            acceptLoop()
        }
    }

    public func stop() {
        isRunning = false
        if serverSocket >= 0 {
            close(serverSocket)
            serverSocket = -1
        }
    }

    private func acceptLoop() {
        while isRunning {
            var clientAddr = sockaddr_in()
            var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
            let clientSocket = withUnsafeMutablePointer(to: &clientAddr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    accept(serverSocket, $0, &clientLen)
                }
            }
            guard clientSocket >= 0, isRunning else { break }
            var noSigPipe: Int32 = 1
            setsockopt(clientSocket, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
            clientQueue.async { [self] in
                handleClient(clientSocket)
            }
        }
    }

    private func handleClient(_ clientSocket: Int32) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        _ = read(clientSocket, &buffer, buffer.count)

        let requestStr = String(bytes: buffer, encoding: .ascii) ?? ""
        var rangeHeader: String?
        for line in requestStr.split(separator: "\r\n") {
            if line.lowercased().hasPrefix("range:") {
                rangeHeader = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            }
        }

        var request = URLRequest(url: remoteURL)
        if let range = rangeHeader {
            request.setValue(range, forHTTPHeaderField: "Range")
        }

        let delegate = StreamingSessionDelegate(clientSocket: clientSocket)
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        let task = session.dataTask(with: request)
        task.resume()
        delegate.semaphore.wait()
        session.finishTasksAndInvalidate()
    }
}

// MARK: - Streaming Delegate

private final class StreamingSessionDelegate: NSObject, URLSessionDataDelegate {
    private let clientSocket: Int32
    private var headersSent = false
    let semaphore = DispatchSemaphore(value: 0)

    init(clientSocket: Int32) {
        self.clientSocket = clientSocket
    }

    func urlSession(
        _ session: URLSession,
        dataTask: URLSessionDataTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            return
        }

        var header = "HTTP/1.1 \(httpResponse.statusCode) OK\r\n"
        header += "Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "video/mp4")\r\n"
        if let contentLength = httpResponse.value(forHTTPHeaderField: "Content-Length") {
            header += "Content-Length: \(contentLength)\r\n"
        }
        if let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range") {
            header += "Content-Range: \(contentRange)\r\n"
        }
        header += "Accept-Ranges: bytes\r\n"
        header += "Connection: close\r\n"
        header += "\r\n"

        header.utf8.withContiguousStorageIfAvailable { buf in
            _ = Darwin.write(clientSocket, buf.baseAddress!, buf.count)
        }
        headersSent = true
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        data.withUnsafeBytes { buf in
            var totalWritten = 0
            while totalWritten < buf.count {
                let written = Darwin.write(
                    clientSocket,
                    buf.baseAddress!.advanced(by: totalWritten),
                    buf.count - totalWritten
                )
                if written <= 0 { break }
                totalWritten += written
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        close(clientSocket)
        semaphore.signal()
    }
}
