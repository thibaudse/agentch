import SwiftUI

@MainActor
final class IslandViewModel: ObservableObject {
    @Published var message: String = ""
    @Published var conversation: String = ""
    @Published var agentName: String = ""
    @Published var expanded: Bool = false
    @Published var isFullExpanded: Bool = false
    @Published var geometry: NotchGeometry = .detect()
    @Published var interactive: Bool = false
    @Published var inputText: String = ""

    // Permission mode
    @Published var isPermission: Bool = false
    @Published var permissionTool: String = ""
    @Published var permissionCommand: String = ""
    @Published var permissionSuggestions: [PermissionSuggestion] = []

    // Elicitation mode
    @Published var isElicitation: Bool = false
    @Published var elicitationQuestion: String = ""
    @Published var elicitationOptions: [ElicitationOption] = []

    var onSubmit: ((String) -> Void)?
    var onExpandToggle: (() -> Void)?
    var onPermissionDecision: ((Bool) -> Void)?  // true = allow, false = deny
    var onPermissionSuggestion: ((PermissionSuggestion) -> Void)?
    var onElicitationAnswer: ((String) -> Void)?

    func update(message: String, agentName: String, geometry: NotchGeometry, interactive: Bool, conversation: String = "") {
        self.message = message
        self.conversation = conversation
        self.agentName = agentName
        self.geometry = geometry
        self.interactive = interactive
        self.isPermission = false
        self.permissionTool = ""
        self.permissionCommand = ""
        self.isElicitation = false
        self.elicitationQuestion = ""
        self.elicitationOptions = []
        self.isFullExpanded = false
        self.inputText = ""
    }

    func updatePermission(tool: String, command: String, agentName: String, geometry: NotchGeometry, suggestions: [PermissionSuggestion] = []) {
        self.permissionTool = tool
        self.permissionCommand = command
        self.message = command
        self.agentName = agentName
        self.geometry = geometry
        self.isPermission = true
        self.isElicitation = false
        self.interactive = true
        self.isFullExpanded = false
        self.inputText = ""
        self.conversation = ""
        self.permissionSuggestions = suggestions
    }

    func updateElicitation(question: Elicitation, agentName: String, geometry: NotchGeometry) {
        self.elicitationQuestion = question.question
        self.elicitationOptions = question.options
        self.agentName = agentName
        self.geometry = geometry
        self.isElicitation = true
        self.isPermission = false
        self.interactive = true
        self.isFullExpanded = false
        self.inputText = ""
        self.conversation = ""
        self.message = question.question
    }

    func toggleExpand() {
        isFullExpanded.toggle()
        onExpandToggle?()
    }

    func submit() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        NSLog("AgentIsland: submit() called, text=%@, hasCallback=%d", text, onSubmit != nil ? 1 : 0)
        guard !text.isEmpty else { return }

        // Append the user's input to the conversation so it shows in expanded view
        if conversation.isEmpty {
            conversation = "**You:** " + text
        } else {
            conversation += "\n\n**You:** " + text
        }

        onSubmit?(text)
    }

    func approvePermission() {
        NSLog("AgentIsland: permission approved")
        onPermissionDecision?(true)
    }

    func denyPermission() {
        NSLog("AgentIsland: permission denied")
        onPermissionDecision?(false)
    }

    func selectSuggestion(_ suggestion: PermissionSuggestion) {
        NSLog("AgentIsland: suggestion selected: %@", suggestion.label)
        onPermissionSuggestion?(suggestion)
    }

    func answerElicitation(_ option: String) {
        NSLog("AgentIsland: elicitation answered: %@", option)
        onElicitationAnswer?(option)
    }
}
