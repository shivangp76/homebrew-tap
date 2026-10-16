cask "xournalpp" do
  arch arm: "ARM64", intel: "X64"

  version "1.3.8"
  sha256 arm:   "7d992ef097afd6db304cb9df70615e67f1a1de412e06f7dc8f907fcde3b7d6d7",
         intel: "e61a58f9dea32805f87c9a0310aa319809a1045b06600afc0a55e79a097cc4eb"

  url "https://github.com/xournalpp/xournalpp/releases/download/v#{version}/xournalpp-#{version}-macOS-#{arch}.dmg"
  name "Xournal++"
  desc "Handwriting notetaking software"
  homepage "https://github.com/xournalpp/xournalpp"

  livecheck do
    url :url
    strategy :github_latest
  end

  # Upstream's homebrew/cask entry was disabled on 2026-09-01 for failing the Gatekeeper check.
  conflicts_with cask: "xournal++"
  depends_on :macos

  app "Xournal++.app"

  postflight_steps do
    # Releases aren't notarized and ship a broken ad-hoc signature ("code has no resources but
    # signature indicates they must be present"), so strip quarantine and re-sign locally.
    run "/usr/bin/xattr", args: ["-cr", "{{appdir}}/Xournal++.app"]
    run "/usr/bin/codesign", args: ["--force", "--deep", "--sign", "-", "{{appdir}}/Xournal++.app"]
  end

  zap trash: [
    "~/.xournalpp",
    "~/Library/Saved Application State/com.github.xournalpp.savedState",
  ]
end
