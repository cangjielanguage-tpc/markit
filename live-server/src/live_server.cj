package live_server

import commandline.macros.{Err, Info, Success}
import commandline.terminal.progressLogger
import fswatch.core.FileMonitor
import std.collection.{ArrayList, HashSet}
import std.core.{StringBuilder, Duration}
import std.fs.{Path, exists, File, FileInfo}
import std.net.{IPSocketAddress, SocketException, SocketTimeoutException, StreamingSocket, TcpServerSocket}
import std.sync.{AtomicBool, AtomicInt64, Mutex}

class HttpRequest {
    public let method: String
    public let path: String
    public let version: String

    public init(method: String, path: String, version: String) {
        this.method = method
        this.path = path
        this.version = version
    }
}

private class WatchRegistration {
    public let path: String
    public let recursive: Bool
    public let debounce: Duration
    public let handler: (Array<String>) -> Unit

    public init(path: String, recursive: Bool, debounce: Duration, handler: (Array<String>) -> Unit) {
        this.path = path
        this.recursive = recursive
        this.debounce = debounce
        this.handler = handler
    }
}

/**
 * Minimal live preview server.
 *
 * The server owns static-file routing and generic debounced file watching.
 * Callers keep application-specific rendering decisions outside this package.
 */
public class LiveServer {
    private let rootPath: String
    private let host: String
    private let port: Int32
    private let quit: AtomicBool = AtomicBool(false)
    private var listener: ?TcpServerSocket = None
    private let fileMonitorLock = Mutex()
    private let fileMonitors: ArrayList<FileMonitor> = ArrayList<FileMonitor>()
    private let watchRegistrations: ArrayList<WatchRegistration> = ArrayList<WatchRegistration>()

    public init(rootPath: String, host: String, port: Int32) {
        this.rootPath = Path(rootPath).toString()
        this.host = host
        this.port = port
    }

    public func watch(
        path: String,
        handler: (Array<String>) -> Unit
    ): Unit {
        this.watch(path, handler, recursive: true)
    }

    public func watch(
        path: String,
        handler: (Array<String>) -> Unit,
        recursive!: Bool
    ): Unit {
        this.watch(path, handler, recursive: recursive, debounce: Duration.millisecond * 250)
    }

    public func watch(
        path: String,
        handler: (Array<String>) -> Unit,
        recursive!: Bool,
        debounce!: Duration
    ): Unit {
        this.watchRegistrations.add(WatchRegistration(Path(path).toString(), recursive, debounce, handler))
    }

    public func start(): Unit {
        try {
            try (serverSocket = TcpServerSocket(bindAt: IPSocketAddress(this.host, UInt16(this.port)))) {
                this.listener = Some(serverSocket)
                serverSocket.bind()

                @Success("Server started at http://${this.host}:${this.port}")

                if (this.watchRegistrations.size > 0) {
                    @Info("File watching enabled")
                    for (registration in this.watchRegistrations) {
                        let current = registration
                        spawn {
                            this.startFileWatching(current)
                        }
                    }
                }

                while (!quit.load()) {
                    try {
                        let client = serverSocket.accept(timeout: Duration.millisecond * 100)
                        spawn {
                            try {
                                this.handleClient(client)
                            } finally {
                                client.close()
                            }
                        }
                    } catch (e: SocketTimeoutException) {
                        continue
                    } catch (e: SocketException) {
                        if (!quit.load()) {
                            throw e
                        }
                    }
                }
            }
        } catch (e: Exception) {
            @Err("Failed to start HTTP server: ${e.message}")
        }
    }

    public func stop(): Unit {
        @Info("Stopping HTTP server...")
        quit.store(true)
        synchronized(this.fileMonitorLock) {
            for (monitor in this.fileMonitors) {
                monitor.cleanup()
            }
            this.fileMonitors.clear()
        }
        match (this.listener) {
            case Some(serverSocket) => serverSocket.close()
            case None => ()
        }
    }

    public func getPort(): Int32 {
        return this.port
    }

    private func handleClient(client: StreamingSocket): Unit {
        match (this.readRequest(client)) {
            case Some(request) => this.handleRequest(client, request)
            case None => ()
        }
    }

    private func handleRequest(client: StreamingSocket, request: HttpRequest): Unit {
        if (request.method != "GET" && request.method != "HEAD") {
            this.sendText(client, 405, "Method Not Allowed", "Method not allowed")
            return
        }

        match (this.resolveFilePath(request.path)) {
            case Some(filePath) =>
                if (exists(filePath) && !FileInfo(filePath).isDirectory()) {
                    this.serveFile(client, request, filePath)
                } else if (!this.redirectToLanguageHome(client, request.path)) {
                    this.sendText(client, 404, "Not Found", "File not found: ${filePath}")
                }
            case None => this.sendText(client, 403, "Forbidden", "Forbidden")
        }
    }

    private func readRequest(client: StreamingSocket): ?HttpRequest {
        let buffer = Array<Byte>(4096, repeat: 0)
        var raw = ""

        while (raw.indexOf("\r\n\r\n").isNone() && raw.size < 65536) {
            let readLen = client.read(buffer)
            if (readLen <= 0) {
                return None
            }
            raw = raw + String.fromUtf8(buffer[..readLen])
        }

        let firstLine = raw.split("\r\n")[0]
        let parts = firstLine.split(" ", removeEmpty: true)
        if (parts.size < 3) {
            return None
        }

        return Some(HttpRequest(parts[0], parts[1], parts[2]))
    }

    private func resolveFilePath(requestPath: String): ?Path {
        let pathOnly = stripQuery(requestPath).replace("\\", "/")
        var cleanPath = if (pathOnly.startsWith("/")) {
            pathOnly[1..]
        } else {
            pathOnly
        }

        if (cleanPath.isEmpty()) {
            return Some(Path(this.rootPath).join("index.html"))
        }

        let cleanParts = ArrayList<String>()
        for (part in cleanPath.split("/", removeEmpty: true)) {
            if (part == "." || part.isEmpty()) {
                continue
            }
            if (part == "..") {
                return None
            }
            cleanParts.add(part)
        }

        cleanPath = String.join(cleanParts.toArray(), delimiter: "/")
        if (cleanPath.isEmpty()) {
            return Some(Path(this.rootPath).join("index.html"))
        }

        let directPath = Path(this.rootPath).join(cleanPath)
        if (exists(directPath)) {
            if (FileInfo(directPath).isDirectory()) {
                return Some(directPath.join("index.html"))
            }
            return Some(directPath)
        }

        if (!cleanPath.endsWith(".html")) {
            let htmlPath = Path(this.rootPath).join("${cleanPath}.html")
            if (exists(htmlPath)) {
                return Some(htmlPath)
            }
        }

        return Some(directPath)
    }

    private func serveFile(client: StreamingSocket, request: HttpRequest, filePath: Path): Unit {
        try {
            let body = File.readFrom(filePath)
            let fileInfo = FileInfo(filePath)
            let headers = ArrayList<(String, String)>()
            headers.add(("Content-Type", getContentType(filePath.toString())))
            headers.add(("Content-Length", "${body.size}"))
            headers.add(("Last-Modified", fileInfo.lastModificationTime.toString()))
            headers.add(("Cache-Control", "no-cache"))
            headers.add(("Connection", "close"))
            this.writeResponse(client, 200, "OK", headers, body, request.method != "HEAD")
        } catch (e: Exception) {
            this.sendText(client, 500, "Internal Server Error", "Error reading file: ${e.message}")
        }
    }

    private func sendText(client: StreamingSocket, status: Int64, reason: String, text: String): Unit {
        let body = text.toArray()
        let headers = ArrayList<(String, String)>()
        headers.add(("Content-Type", "text/plain; charset=utf-8"))
        headers.add(("Content-Length", "${body.size}"))
        headers.add(("Cache-Control", "no-cache"))
        headers.add(("Connection", "close"))
        this.writeResponse(client, status, reason, headers, body, true)
    }

    private func sendRedirect(client: StreamingSocket, location: String): Unit {
        let body = "Redirecting to ${location}".toArray()
        let headers = ArrayList<(String, String)>()
        headers.add(("Location", location))
        headers.add(("Content-Type", "text/plain; charset=utf-8"))
        headers.add(("Content-Length", "${body.size}"))
        headers.add(("Cache-Control", "no-cache"))
        headers.add(("Connection", "close"))
        this.writeResponse(client, 302, "Found", headers, body, true)
    }

    private func writeResponse(client: StreamingSocket, status: Int64, reason: String,
        headers: ArrayList<(String, String)>, body: Array<Byte>, sendBody: Bool): Unit {
        let response = StringBuilder()
        response.append("HTTP/1.1 ${status} ${reason}\r\n")
        for (i in 0..headers.size) {
            let (name, value) = headers[i]
            response.append("${name}: ${value}\r\n")
        }
        response.append("\r\n")

        client.write(response.toString().toArray())
        if (sendBody && body.size > 0) {
            client.write(body)
        }
    }

    private func redirectToLanguageHome(client: StreamingSocket, requestPath: String): Bool {
        let pathOnly = stripQuery(requestPath)
        if (!pathOnly.startsWith("/") || pathOnly.size <= 1) {
            return false
        }

        let parts = pathOnly[1..].split("/")
        if (parts.size < 2) {
            return false
        }

        let lang = parts[0]
        if (lang.isEmpty() || lang == "." || lang == "..") {
            return false
        }

        let langHomePath = Path(this.rootPath).join(lang).join("index.html")
        if (exists(langHomePath)) {
            this.sendRedirect(client, "/${lang}/")
            return true
        }

        return false
    }

    private func startFileWatching(registration: WatchRegistration): Unit {
        try {
            let monitor = FileMonitor()
            synchronized(this.fileMonitorLock) {
                this.fileMonitors.add(monitor)
            }

            let pendingPaths = HashSet<String>()
            let pendingLock = Mutex()
            let flushScheduled = AtomicBool(false)
            let eventVersion = AtomicInt64(0)

            monitor.addEventHandler {
                event =>
                    synchronized(pendingLock) {
                        pendingPaths.add(event.path.toString())
                        match (event.oldPath) {
                            case Some(oldPath) => pendingPaths.add(oldPath.toString())
                            case None => ()
                        }
                        eventVersion.fetchAdd(1)
                    }

                    if (flushScheduled.compareAndSwap(false, true)) {
                        spawn {
                            var done = false
                            while (!done && !this.quit.load()) {
                                let observedVersion = synchronized(pendingLock) {
                                    eventVersion.load()
                                }
                                sleep(registration.debounce)

                                let (ready, batch) = synchronized(pendingLock) {
                                    if (eventVersion.load() == observedVersion) {
                                        let paths = pendingPaths.toArray()
                                        pendingPaths.clear()
                                        (true, paths)
                                    } else {
                                        (false, ArrayList<String>().toArray())
                                    }
                                }

                                if (ready) {
                                    if (batch.size > 0) {
                                        registration.handler(batch)
                                    }

                                    let shouldContinue = synchronized(pendingLock) {
                                        if (pendingPaths.size > 0) {
                                            true
                                        } else {
                                            flushScheduled.store(false)
                                            false
                                        }
                                    }
                                    done = !shouldContinue
                                }
                            }
                            if (this.quit.load()) {
                                flushScheduled.store(false)
                            }
                        }
                    }
            }

            monitor.watch(Path(registration.path), recursive: registration.recursive)
            @Info("Watching: ${registration.path}")
            monitor.start()
            while (!quit.load()) {
                sleep(Duration.second)
            }
        } catch (e: Exception) {
            @Err("File watching failed: ${e.message}")
        }
    }
}

private func stripQuery(path: String): String {
    let withoutQuery = if (let Some(queryIndex) <- path.indexOf("?")) {
        path[..queryIndex]
    } else {
        path
    }

    return if (let Some(hashIndex) <- withoutQuery.indexOf("#")) {
        withoutQuery[..hashIndex]
    } else {
        withoutQuery
    }
}

private func getContentType(filePath: String): String {
    let lowerPath = filePath.toAsciiLower()

    return match (lowerPath) {
        case path where path.endsWith(".html") || path.endsWith(".htm") => "text/html; charset=utf-8"
        case path where path.endsWith(".css") => "text/css"
        case path where path.endsWith(".js") || path.endsWith(".mjs") => "application/javascript"
        case path where path.endsWith(".json") => "application/json"
        case path where path.endsWith(".png") => "image/png"
        case path where path.endsWith(".jpg") || path.endsWith(".jpeg") => "image/jpeg"
        case path where path.endsWith(".gif") => "image/gif"
        case path where path.endsWith(".svg") => "image/svg+xml"
        case path where path.endsWith(".webp") => "image/webp"
        case path where path.endsWith(".ico") => "image/x-icon"
        case path where path.endsWith(".bmp") => "image/bmp"
        case path where path.endsWith(".tiff") || path.endsWith(".tif") => "image/tiff"
        case path where path.endsWith(".pdf") => "application/pdf"
        case path where path.endsWith(".txt") => "text/plain; charset=utf-8"
        case path where path.endsWith(".md") || path.endsWith(".markdown") => "text/markdown; charset=utf-8"
        case path where path.endsWith(".xml") => "application/xml"
        case path where path.endsWith(".woff") => "font/woff"
        case path where path.endsWith(".woff2") => "font/woff2"
        case path where path.endsWith(".ttf") => "font/ttf"
        case path where path.endsWith(".eot") => "application/vnd.ms-fontobject"
        case path where path.endsWith(".otf") => "font/otf"
        case path where path.endsWith(".mp4") => "video/mp4"
        case path where path.endsWith(".webm") => "video/webm"
        case path where path.endsWith(".avi") => "video/x-msvideo"
        case path where path.endsWith(".mov") => "video/quicktime"
        case path where path.endsWith(".wmv") => "video/x-ms-wmv"
        case path where path.endsWith(".flv") => "video/x-flv"
        case path where path.endsWith(".mp3") => "audio/mpeg"
        case path where path.endsWith(".wav") => "audio/wav"
        case path where path.endsWith(".ogg") => "audio/ogg"
        case path where path.endsWith(".aac") => "audio/aac"
        case path where path.endsWith(".flac") => "audio/flac"
        case path where path.endsWith(".m4a") => "audio/mp4"
        case _ => "application/octet-stream"
    }
}
