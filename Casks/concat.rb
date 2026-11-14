cask "concat" do
  arch arm: "arm64", intel: "x86_64"

  version "0.2.11"
  sha256 arm:   "2831aa93b228e7c88deae80758f3e9de5a48d35cdd85dcef3d89426d6331fc4b",
         intel: "a656ed2f1a374b62f69ade0b69e4fcc4110cb31dac64203693ddfa64e102467d"

  url "https://github.com/jub0t/Concat/releases/download/v#{version}/Concat-#{version}-macos-#{arch}.dmg"
  name "Concat"
  desc "Local-first, open-source video editor"
  homepage "https://github.com/jub0t/Concat"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: :monterey

  app "Concat.app"

  postflight_steps do
    # Releases are ad-hoc signed but not notarized, so Gatekeeper rejects them
    # unless the quarantine attribute is stripped.
    run "/usr/bin/xattr", args: ["-cr", "{{appdir}}/Concat.app"]
  end

  uninstall quit: "app.concat.editor"

  zap trash: [
    "~/Library/Application Support/app.concat.editor",
    "~/Library/Caches/app.concat.editor",
    "~/Library/Preferences/app.concat.editor.plist",
    "~/Library/Saved Application State/app.concat.editor.savedState",
  ]
end
