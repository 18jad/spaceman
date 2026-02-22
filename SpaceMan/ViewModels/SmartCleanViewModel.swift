import Foundation
import SwiftUI

enum SmartCleanState {
    case idle
    case scanning
    case results
    case executing
    case done(CleanLogEntry)
    case error(String)
}

@MainActor
@Observable
final class SmartCleanViewModel {
    var state: SmartCleanState = .idle
    var plan: SmartCleanPlan?
    var scanScope: ScanScope = .home

    // Scan progress
    var scanPhase: SmartCleanProgress.Phase = .downloads
    var scanDetail: String = ""
    var scanItemsFound: Int = 0

    // Execution progress
    var executionCurrent: Int = 0
    var executionTotal: Int = 0
    var executionCurrentItem: String = ""

    // Clean log
    var cleanLog: [CleanLogEntry] = []
    var showCleanLog = false

    private var scanTask: Task<Void, Never>?
    private var executeTask: Task<Void, Never>?

    init() {
        cleanLog = CleanLog.entries()
    }

    // MARK: - Scanning

    func startScan() {
        switch state {
        case .idle, .results, .error:
            break
        case .done:
            break
        case .scanning, .executing:
            return
        }

        scanTask?.cancel()
        plan = nil
        state = .scanning

        scanTask = Task.detached { [weak self] in
            guard let self else { return }
            let scope = await self.scanScope

            let result = await SmartCleanService.scan(scope: scope) { progress in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.scanPhase = progress.phase
                    self.scanDetail = progress.detail
                    self.scanItemsFound = progress.itemsFound
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                if Task.isCancelled {
                    self.state = .idle
                } else {
                    self.plan = result
                    self.state = result.groups.isEmpty ? .idle : .results
                }
            }
        }
    }

    func cancelScan() {
        scanTask?.cancel()
        state = .idle
    }

    func resetToIdle() {
        scanTask?.cancel()
        executeTask?.cancel()
        plan = nil
        state = .idle
    }

    // MARK: - Selection

    func toggleItem(_ itemId: UUID) {
        guard var plan else { return }
        for gi in plan.groups.indices {
            if let ii = plan.groups[gi].items.firstIndex(where: { $0.id == itemId }) {
                plan.groups[gi].items[ii].isSelected.toggle()
                self.plan = plan
                return
            }
        }
    }

    func selectAllSafe() {
        guard var plan else { return }
        for gi in plan.groups.indices {
            for ii in plan.groups[gi].items.indices {
                plan.groups[gi].items[ii].isSelected = plan.groups[gi].items[ii].risk == .safe
            }
        }
        self.plan = plan
    }

    func deselectAll() {
        guard var plan else { return }
        for gi in plan.groups.indices {
            for ii in plan.groups[gi].items.indices {
                plan.groups[gi].items[ii].isSelected = false
            }
        }
        self.plan = plan
    }

    func selectAll(in category: CleanableCategory) {
        guard var plan else { return }
        if let gi = plan.groups.firstIndex(where: { $0.category == category }) {
            for ii in plan.groups[gi].items.indices {
                plan.groups[gi].items[ii].isSelected = true
            }
        }
        self.plan = plan
    }

    func deselectAll(in category: CleanableCategory) {
        guard var plan else { return }
        if let gi = plan.groups.firstIndex(where: { $0.category == category }) {
            for ii in plan.groups[gi].items.indices {
                plan.groups[gi].items[ii].isSelected = false
            }
        }
        self.plan = plan
    }

    // MARK: - Execution

    func executeClean() {
        guard let plan, plan.totalSelectedCount > 0 else { return }
        state = .executing
        executionCurrent = 0
        executionTotal = plan.totalSelectedCount

        executeTask = Task.detached { [weak self] in
            guard let self else { return }
            let currentPlan = await self.plan!

            let entry = await SmartCleanExecutor.execute(plan: currentPlan) { current, total, name in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.executionCurrent = current
                    self.executionTotal = total
                    self.executionCurrentItem = name
                }
            }

            await MainActor.run { [weak self] in
                guard let self else { return }
                self.cleanLog = CleanLog.entries()
                if Task.isCancelled {
                    self.state = .results
                } else {
                    self.state = .done(entry)
                }
            }
        }
    }

    func cancelClean() {
        executeTask?.cancel()
        state = .results
    }
}
