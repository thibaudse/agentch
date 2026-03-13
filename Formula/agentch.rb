class Agentch < Formula
  desc "Notch-style Claude companion UI for macOS"
  homepage "https://github.com/thibaudse/agentch"
  url "https://github.com/thibaudse/agentch/archive/refs/heads/main.tar.gz"
  version "main"
  sha256 :no_check

  depends_on :macos

  def install
    system "swift", "build", "--configuration", "release", "--product", "AgentIsland"
    bin_path = Utils.safe_popen_read(
      "swift", "build", "--configuration", "release", "--product", "AgentIsland", "--show-bin-path"
    ).strip

    libexec.install "#{bin_path}/AgentIsland"
    (libexec/"scripts/hooks").mkpath
    (libexec/"scripts").install "scripts/island.sh", "scripts/install-claude-hooks.sh"
    (libexec/"scripts/hooks").install "scripts/hooks/claude-show.sh"
    (libexec/"scripts/hooks").install "scripts/hooks/claude-permission.sh"
    (libexec/"scripts/hooks").install "scripts/hooks/claude-dismiss.sh"
    (share/"agentch/hooks/claude-code").install "hooks/claude-code/hooks.json"

    write_wrapper("agentch", "#{opt_libexec}/AgentIsland")
    write_wrapper("agentch-island", "#{opt_libexec}/scripts/island.sh")
    write_wrapper("agentch-install-hooks", "#{opt_libexec}/scripts/install-claude-hooks.sh")
    write_wrapper("agentch-claude-show", "#{opt_libexec}/scripts/hooks/claude-show.sh")
    write_wrapper("agentch-claude-permission", "#{opt_libexec}/scripts/hooks/claude-permission.sh")
    write_wrapper("agentch-claude-dismiss", "#{opt_libexec}/scripts/hooks/claude-dismiss.sh")
  end

  service do
    run [opt_bin/"agentch"]
    keep_alive true
    log_path var/"log/agentch.log"
    error_log_path var/"log/agentch.log"
  end

  def caveats
    <<~EOS
      Install Claude hooks:
        agentch-install-hooks

      Start at login:
        brew services start agentch

      Manual control:
        agentch-island start
        agentch-island stop
    EOS
  end

  private

  def write_wrapper(name, target)
    (bin/name).write <<~EOS
      #!/bin/bash
      set -euo pipefail
      export AGENT_ISLAND_HOME="#{opt_libexec}"
      exec "#{target}" "$@"
    EOS
    chmod 0755, bin/name
  end
end
