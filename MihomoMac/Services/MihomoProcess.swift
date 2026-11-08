import Foundation

@MainActor
@Observable
final class MihomoProcess {
    var status: ProcessStatus = .stopped
    var processOutput: [String] = []

    private var process: Process?
    private var outputPipe: Pipe?
    private var restartCount = 0
    private var stoppingManually = false
    private static let maxRestarts = 3
    private static let restartDelay: UInt64 = 5_000_000_000 // 5s

    var isRunning: Bool {
        process?.isRunning ?? false
    }

    func start(executableURL: URL, configFileURL: URL, configDirURL: URL) {
        startInternal(executableURL: executableURL, configFileURL: configFileURL, configDirURL: configDirURL, isRestart: false)
    }

    func stop() {
        guard let process, process.isRunning else {
            status = .stopped
            return
        }
        stoppingManually = true
        process.terminate()

        let pid = process.processIdentifier
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if self.process?.isRunning == true {
                kill(pid, SIGKILL)
            }
        }
    }

    // MARK: - Private

    private func startInternal(executableURL: URL, configFileURL: URL, configDirURL: URL, isRestart: Bool) {
        guard !isRunning else { return }

        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            status = .error("File not found or not executable: \(executableURL.path)")
            return
        }

        guard FileManager.default.fileExists(atPath: configFileURL.path) else {
            status = .error("Config file not found: \(configFileURL.path)")
            return
        }

        let proc = Process()
        proc.executableURL = executableURL
        proc.arguments = ["-d", configDirURL.path, "-f", configFileURL.path]
        proc.currentDirectoryURL = configDirURL

        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        self.outputPipe = pipe

        readOutput(from: pipe)

        proc.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.handleTermination(
                    exitCode: process.terminationStatus,
                    executableURL: executableURL,
                    configFileURL: configFileURL,
                    configDirURL: configDirURL
                )
            }
        }

        let command = "\(executableURL.path) \(proc.arguments?.joined(separator: " ") ?? "")"
        print("[MihomoProcess] Launching: \(command)")
        processOutput.append("$ \(command)")

        do {
            try proc.run()
            self.process = proc
            status = .starting
            stoppingManually = false
            if !isRestart { restartCount = 0 }
        } catch {
            status = .error("Failed to start: \(error.localizedDescription)")
        }
    }

    private func handleTermination(exitCode: Int32, executableURL: URL, configFileURL: URL, configDirURL: URL) {
        process = nil

        if stoppingManually {
            stoppingManually = false
            status = .stopped
            return
        }

        if exitCode == 0 {
            status = .stopped
            return
        }

        if restartCount >= MihomoProcess.maxRestarts {
            status = .failed
            return
        }

        restartCount += 1
        status = .error("Exited with code \(exitCode), restarting (\(restartCount)/\(MihomoProcess.maxRestarts))...")

        Task {
            try? await Task.sleep(nanoseconds: MihomoProcess.restartDelay)
            self.startInternal(executableURL: executableURL, configFileURL: configFileURL, configDirURL: configDirURL, isRestart: true)
        }
    }

    private func readOutput(from pipe: Pipe) {
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let line = String(data: data, encoding: .utf8) else { return }
            print("[mihomo] \(line)", terminator: "")
            Task { @MainActor in
                self?.processOutput.append(line)
                if (self?.processOutput.count ?? 0) > 1000 {
                    self?.processOutput.removeFirst(100)
                }
            }
        }
    }
}
