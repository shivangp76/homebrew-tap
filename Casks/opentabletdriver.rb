cask "opentabletdriver" do
  version "0.6.7"
  sha256 "c4b0d9eb2aee8ee7be12d0df80f961ea0a7235f54b5f59a2b62efa9b9ec4910e"

  url "https://github.com/OpenTabletDriver/OpenTabletDriver/releases/download/v#{version}/OpenTabletDriver-#{version}_osx-x64.tar.gz"
  name "OpenTabletDriver"
  desc "Open source, cross-platform, user-mode tablet driver"
  homepage "https://opentabletdriver.net/"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates false

  app "OpenTabletDriver.app"

  postflight_steps do
    # Releases aren't notarized, so Gatekeeper will flag them as "damaged"
    # unless the quarantine attribute is stripped.
    system_command "/usr/bin/xattr",
                    args: ["-cr", "#{appdir}/OpenTabletDriver.app"],
                    sudo: false
  end

  zap trash: [
    "~/Library/Application Support/OpenTabletDriver",
    "~/.config/OpenTabletDriver",
    "~/Library/Preferences/com.opentabletdriver.plist",
  ]
end
