class Agentch < Formula
  desc "Floating glass pill showing active AI agent sessions on macOS"
  homepage "https://github.com/thibaudse/agentch"
  url "https://github.com/thibaudse/agentch/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "REPLACE_WITH_SHA256"
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
      agentch will auto-install Claude Code hooks on first launch.

      To start agentch now and on login:
        brew services start agentch

      Grant Accessibility permission in:
        System Settings > Privacy & Security > Accessibility
    EOS
  end
end
