class Agentch < Formula
  desc "Floating glass pill showing active AI agent sessions on macOS"
  homepage "https://github.com/thibaudse/agentch"
  head "https://github.com/thibaudse/agentch.git", branch: "main"
  license "MIT"

  depends_on xcode: ["16.0", :build]
  depends_on :macos

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/agentch"
  end

  service do
    run [opt_bin/"agentch"]
    keep_alive true
    log_path var/"log/agentch.log"
  end

  def caveats
    <<~EOS
      To start agentch now and on login:
        brew services start agentch

      agentch auto-installs Claude Code hooks on first launch.

      Grant Accessibility permission in:
        System Settings > Privacy & Security > Accessibility
    EOS
  end
end
