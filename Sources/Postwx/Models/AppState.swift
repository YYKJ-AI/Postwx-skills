import SwiftUI

@Observable
final class AppState: @unchecked Sendable {
    // MARK: - Content

    var content: String = ""
    var title: String = ""
    var author: String = ""
    var summary: String = ""

    var selectedTheme: Theme = .default_
    var selectedColor: ThemeColor = .blue

    // MARK: - Workflow

    var workflowState: WorkflowState = .idle
    var stepStatuses: [WorkflowStep: StepStatus] = [:]
    var stepStartTimes: [WorkflowStep: Date] = [:]
    var stepDurations: [WorkflowStep: TimeInterval] = [:]
    var publishLog: [String] = []

    /// 原始内容（AI 处理前的快照，用于审核时对比）
    var originalContent: String = ""
    /// AI 处理后的内容
    var processedContent: String = ""
    /// 检测到的输入格式
    var inputFormat: InputFormat = .markdown
    /// 去 AI 味评分（满分 50）
    var deAIScore: Int?
    /// 去 AI 味评级
    var deAIRating: String?

    /// AI 实时输出（流式显示）
    var aiStreamingText: String = ""
    /// 当前 AI 步骤名称
    var aiCurrentStep: String = ""

    var isProcessing: Bool { workflowState == .processing }
    var isReviewing: Bool { workflowState == .reviewing }
    var isPublishing: Bool { workflowState == .publishing }
    var isBusy: Bool { isProcessing || isPublishing }

    // MARK: - 目标账号（多选）

    var selectedProfileIds: Set<UUID> = []
    /// 每个账号的发布状态
    var profilePublishStatuses: [UUID: ProfilePublishStatus] = [:]
    /// 每个账号独立适配后的内容
    var profileContents: [UUID: String] = [:]
    /// 审核时当前查看的账号
    var activeReviewProfileId: UUID?

    /// 用于 AI 处理的主账号（取第一个选中的）
    var primaryProfileId: UUID? { selectedProfileIds.sorted(by: { $0.uuidString < $1.uuidString }).first }

    var hasSelectedProfiles: Bool { !selectedProfileIds.isEmpty }

    // MARK: - Credentials（从主账号同步，用于 AI 处理）

    var wechatAppId: String = ""
    var wechatAppSecret: String = ""
    var imageApiBase: String = ""
    var imageApiKey: String = ""
    var imageModel: String = ""

    // MARK: - Preferences（从选中 Profile 同步）

    var personaId: String = "tech-blogger"
    var username: String = ""
    var defaultAuthor: String = ""
    var needOpenComment: Bool = true
    var onlyFansCanComment: Bool = false

    var hasCredentials: Bool {
        !wechatAppId.isEmpty && !wechatAppSecret.isEmpty
    }

    // MARK: - Workflow Helpers

    func resetWorkflow() {
        workflowState = .idle
        stepStatuses = [:]
        stepStartTimes = [:]
        stepDurations = [:]
        publishLog = []
        originalContent = ""
        processedContent = ""
        deAIScore = nil
        deAIRating = nil
        aiStreamingText = ""
        aiCurrentStep = ""
        profilePublishStatuses = [:]
        profileContents = [:]
        activeReviewProfileId = nil
    }

    func stepStatus(_ step: WorkflowStep) -> StepStatus {
        stepStatuses[step] ?? .pending
    }

    func updateStep(_ step: WorkflowStep, status: StepStatus) {
        if case .running = status {
            stepStartTimes[step] = Date()
        } else if status.isTerminal, let start = stepStartTimes[step] {
            stepDurations[step] = Date().timeIntervalSince(start)
        }
        stepStatuses[step] = status
    }
}

// MARK: - Workflow Enums

enum WorkflowState: Equatable {
    case idle
    case processing
    case reviewing
    case publishing
    case done(String) // media_id
    case failed(String)

    static func == (lhs: WorkflowState, rhs: WorkflowState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.processing, .processing),
             (.reviewing, .reviewing), (.publishing, .publishing):
            true
        case (.done(let a), .done(let b)): a == b
        case (.failed(let a), .failed(let b)): a == b
        default: false
        }
    }
}

enum WorkflowStep: Int, CaseIterable, Identifiable {
    case inputDetection = 1
    case roleAdaptation = 2
    case deAI = 3
    case themeSelection = 4
    case imageGeneration = 5
    case publishing = 6

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .inputDetection: "输入检测"
        case .roleAdaptation: "角色适配"
        case .deAI: "去 AI 味"
        case .themeSelection: "主题配色"
        case .imageGeneration: "AI 配图"
        case .publishing: "发布"
        }
    }

    var icon: String {
        switch self {
        case .inputDetection: "doc.text.magnifyingglass"
        case .roleAdaptation: "person.text.rectangle"
        case .deAI: "wand.and.stars"
        case .themeSelection: "paintpalette"
        case .imageGeneration: "photo.artframe"
        case .publishing: "paperplane"
        }
    }
}

enum StepStatus: Equatable {
    case pending
    case running
    case completed(String) // 简短结果描述
    case skipped(String)
    case failed(String)

    var isTerminal: Bool {
        switch self {
        case .completed, .skipped, .failed: true
        default: false
        }
    }
}

enum ProfilePublishStatus: Equatable {
    case pending
    case publishing
    case success(String) // media_id
    case failed(String)  // error message
}

enum InputFormat: String {
    case markdown = "Markdown"
    case html = "HTML"
    case plainText = "纯文本"
}

// MARK: - Theme & Color

enum Theme: String, CaseIterable, Identifiable {
    case default_ = "default"
    case grace
    case simple
    case modern

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .default_: "Default"
        case .grace: "Grace"
        case .simple: "Simple"
        case .modern: "Modern"
        }
    }
}

enum ThemeColor: String, CaseIterable, Identifiable {
    case blue, green, vermilion, yellow, purple
    case sky, rose, olive, black, gray
    case pink, red, orange

    var id: String { rawValue }
}

