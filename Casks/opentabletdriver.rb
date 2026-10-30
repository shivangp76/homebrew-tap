cask "opentabletdriver" do
  arch arm: "arm64", intel: "x64"

  version "0.6.8.1"
  sha256 arm:   "bbd3957ba5a8809e377cda0b746c9a0578d382970375a8ee3f51db68f7b2e328",
         intel: "c8a90bd5627f3e1f7360d553484897f006416b3fc84674ef9c2cddfb1b941305"

  url "https://github.com/OpenTabletDriver/OpenTabletDriver/releases/download/v#{version}/OpenTabletDriver-#{version}_osx-#{arch}.tar.gz"
  name "OpenTabletDriver"
  desc "Open source, cross-platform, user-mode tablet driver"
  homepage "https://opentabletdriver.net/"

  livecheck do
    url "https://github.com/OpenTabletDriver/OpenTabletDriver"
    strategy :github_latest
  end

  auto_updates false
  depends_on :macos

  app "OpenTabletDriver.app"

  postflight_steps do
    # Releases are ad-hoc signed but not notarized, so Gatekeeper blocks them
    # unless the quarantine attribute is stripped.
    run "/usr/bin/xattr", args: ["-cr", "{{appdir}}/OpenTabletDriver.app"]
  end

  zap trash: [
    "~/Library/Application Support/OpenTabletDriver",
    "~/Library/Preferences/com.opentabletdriver.plist",
  ]
end
