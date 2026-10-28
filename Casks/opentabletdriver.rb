cask "opentabletdriver" do
  arch arm: "arm64", intel: "x64"

  version "0.6.8"
  sha256 arm:   "5f5f8443d9741ab3d8e7166c2984e04d274f813cacd846be63d402e0d6b1328c",
         intel: "c3b843e416f79abc6d2ca59bbbf1fd990eded2e5d71b4747c8c383ef415230db"

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
