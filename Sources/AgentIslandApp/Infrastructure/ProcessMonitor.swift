import Foundation

/// Monitors an agent process by PID, firing a callback when it exits.
/// Uses `kill(pid, 0)` polling — lightweight and works for any same-user process.
@MainActor
final class ProcessMonitor {
    private var task: Task<Void, Never>?
    private(set) var monitoredPID: pid_t = 0

    func monitor(pid: pid_t, onExit: @escaping @MainActor () -> Void) {
        stop()
        guard pid > 0 else { return }

        monitoredPID = pid
        NSLog("AgentIsland: Monitoring process %d", pid)

        task = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: AppConfig.processMonitorIntervalNanos)
                guard !Task.isCancelled else { return }

                // signal 0 checks existence without actually signaling
                if kill(pid, 0) != 0, errno == ESRCH {
                    NSLog("AgentIsland: Process %d exited, auto-dismissing", pid)
                    onExit()
                    return
                }
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        monitoredPID = 0
    }
}
