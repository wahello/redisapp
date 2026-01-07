import Cocoa

@main
@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var updater: SUUpdater!

    let paths = FileManager.default.urls(
        for: .documentDirectory,
        in: .userDomainMask
    )

    let documentsDirectory: URL
    let dataPath: String
    let logPath: String

    var task = Process()
    var pipe = Pipe()
    var file: FileHandle

    let statusBar = NSStatusBar.system
    var statusBarItem: NSStatusItem!
    let menu = NSMenu()

    let statusMenuItem = NSMenuItem()
    let openCLIMenuItem = NSMenuItem()
    let openLogsMenuItem = NSMenuItem()
    let docsMenuItem = NSMenuItem()
    let aboutMenuItem = NSMenuItem()
    let versionMenuItem = NSMenuItem()
    let quitMenuItem = NSMenuItem()
    let updatesMenuItem = NSMenuItem()

    override init() {
        self.file = pipe.fileHandleForReading
        self.documentsDirectory = paths[0]
        self.dataPath = documentsDirectory
            .appendingPathComponent("RedisData").path
        self.logPath = documentsDirectory
            .appendingPathComponent("RedisData/Logs").path

        super.init()
    }

    func startServer() {
        task = Process()
        pipe = Pipe()
        file = pipe.fileHandleForReading

        if let path = Bundle.main.path(
            forResource: "redis-server",
            ofType: "",
            inDirectory: "Vendor/redis/bin"
        ) {
            task.executableURL = URL(fileURLWithPath: path)
        }

        task.arguments = [
            "--dir", dataPath,
            "--logfile", "\(logPath)/redis.log"
        ]
        task.standardOutput = pipe

        print("Run redis-server")

        do {
            try task.run()
        } catch {
            print("Failed to start redis-server:", error)
        }
    }

    func stopServer() {
        print("Terminate redis-server")
        task.terminate()

        let data = file.readDataToEndOfFile()
        file.closeFile()

        if let output = String(data: data, encoding: .utf8) {
            print(output)
        }
    }

    @objc func openCLI(_ sender: Any?) {
        guard let path = Bundle.main.path(
            forResource: "redis-cli",
            ofType: "",
            inDirectory: "Vendor/redis/bin"
        ) else { return }

        let source: String

        if appExists("iTerm") {
            source = """
            tell application "iTerm"
                activate
                create window with default profile
                tell current session of current window
                    write text "\(path)"
                end tell
            end tell
            """
        } else {
            source = """
            tell application "Terminal"
                activate
                do script "\(path)"
            end tell
            """
        }

        NSAppleScript(source: source)?.executeAndReturnError(nil)
    }

    @objc func openDocumentationPage(_ sender: Any?) {
        if let url = URL(string: "https://github.com/jpadilla/redisapp") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc func openLogsDirectory(_ sender: Any?) {
        NSWorkspace.shared.openFile(logPath)
    }

    func createDirectories() {
        let fm = FileManager.default

        if !fm.fileExists(atPath: dataPath) {
            try? fm.createDirectory(
                atPath: dataPath,
                withIntermediateDirectories: false
            )
        }

        if !fm.fileExists(atPath: logPath) {
            try? fm.createDirectory(
                atPath: logPath,
                withIntermediateDirectories: false
            )
        }

        print("Redis data directory:", dataPath)
        print("Redis logs directory:", logPath)
    }

    @objc func checkForUpdates(_ sender: Any?) {
        updater.checkForUpdates(sender)
    }

    func setupSystemMenuItem() {
        statusBarItem = statusBar.statusItem(withLength: NSStatusItem.variableLength)
        statusBarItem.menu = menu

        let icon = NSImage(named: "logo")
        icon?.isTemplate = true
        icon?.size = NSSize(width: 18, height: 18)
        statusBarItem.image = icon

        versionMenuItem.title = "Redis"
        if let version = Bundle.main
            .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            versionMenuItem.title = "Redis v\(version)"
        }
        menu.addItem(versionMenuItem)

        statusMenuItem.title = "Running on Port 6379"
        menu.addItem(statusMenuItem)

        menu.addItem(.separator())

        openCLIMenuItem.title = "Open redis-cli"
        openCLIMenuItem.action = #selector(openCLI(_:))
        menu.addItem(openCLIMenuItem)

        openLogsMenuItem.title = "Open logs directory"
        openLogsMenuItem.action = #selector(openLogsDirectory(_:))
        menu.addItem(openLogsMenuItem)

        menu.addItem(.separator())

        updatesMenuItem.title = "Check for Updates..."
        updatesMenuItem.action = #selector(checkForUpdates(_:))
        menu.addItem(updatesMenuItem)

        aboutMenuItem.title = "About"
        aboutMenuItem.action =
            #selector(NSApplication.orderFrontStandardAboutPanel(_:))
        menu.addItem(aboutMenuItem)

        docsMenuItem.title = "Documentation..."
        docsMenuItem.action = #selector(openDocumentationPage(_:))
        menu.addItem(docsMenuItem)

        menu.addItem(.separator())

        quitMenuItem.title = "Quit"
        quitMenuItem.action =
            #selector(NSApplication.shared.terminate(_:))
        menu.addItem(quitMenuItem)
    }

    func appExists(_ appName: String) -> Bool {
        let paths = [
            "/Applications/\(appName).app",
            "/Applications/Utilities/\(appName).app",
            "\(NSHomeDirectory())/Applications/\(appName).app"
        ]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        createDirectories()
        setupSystemMenuItem()
        startServer()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopServer()
    }
}

