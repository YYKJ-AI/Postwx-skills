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

    // MARK: - Credentials

    var wechatAppId: String = ""
    var wechatAppSecret: String = ""
    var imageApiBase: String = ""
    var imageApiKey: String = ""
    var imageModel: String = ""

    // MARK: - Preferences

    var creatorRole: CreatorRole = .techBlogger
    var writingStyle: WritingStyle = .professional
    var targetAudience: TargetAudience = .general
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
        publishLog = []
        originalContent = ""
        processedContent = ""
        deAIScore = nil
        deAIRating = nil
        aiStreamingText = ""
        aiCurrentStep = ""
    }

    func stepStatus(_ step: WorkflowStep) -> StepStatus {
        stepStatuses[step] ?? .pending
    }

    func updateStep(_ step: WorkflowStep, status: StepStatus) {
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

// MARK: - Creator Settings

enum CreatorRole: String, CaseIterable, Identifiable {
    case techBlogger = "tech-blogger"
    case lifestyleWriter = "lifestyle-writer"
    case educator
    case businessAnalyst = "business-analyst"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .techBlogger: "技术博主"
        case .lifestyleWriter: "生活作者"
        case .educator: "教育者"
        case .businessAnalyst: "商业分析"
        }
    }

    var adaptationGuide: String {
        switch self {
        case .techBlogger: "技术术语保留，加入实用性观点，结构清晰，代码示例规范"
        case .lifestyleWriter: "口语化表达，加入个人感受和场景描写，拉近与读者距离"
        case .educator: "层次分明，循序渐进，加入总结要点，引导读者思考"
        case .businessAnalyst: "数据支撑，行业视角，趋势分析，专业术语得当"
        }
    }
}

enum WritingStyle: String, CaseIterable, Identifiable {
    case professional, casual, humorous, academic

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .professional: "专业"
        case .casual: "随性"
        case .humorous: "幽默"
        case .academic: "学术"
        }
    }

    var adaptationGuide: String {
        switch self {
        case .professional: "严谨用词，逻辑清晰，适度使用专业术语"
        case .casual: "亲切自然，适当口语化，拉近距离"
        case .humorous: "加入巧妙比喻，轻松表达，保持信息量"
        case .academic: "规范引用，严格论证，学术用语"
        }
    }
}

enum TargetAudience: String, CaseIterable, Identifiable {
    case general, industry, students
    case techCommunity = "tech-community"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .general: "大众"
        case .industry: "行业人士"
        case .students: "学生"
        case .techCommunity: "技术社区"
        }
    }

    var adaptationGuide: String {
        switch self {
        case .general: "通俗易懂，避免术语堆砌，多用类比"
        case .industry: "行业术语，深度分析，同行视角"
        case .students: "教学口吻，知识点标注，循序渐进"
        case .techCommunity: "代码示例，技术深度，实践导向"
        }
    }
}
