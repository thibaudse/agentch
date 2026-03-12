import AgentIslandApp

@main
struct AgentIslandMain {
    @MainActor
    static func main() {
        AgentIslandRunner.run()
    }
}
