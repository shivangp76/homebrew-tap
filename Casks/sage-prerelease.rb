cask "sage-prerelease" do
  arch arm: "arm64", intel: "x86_64"

  # Same layout as homebrew/cask's `sage`, but tracking 3-manifolds/Sage_macOS
  # pre-releases, which that cask skips (it uses :github_latest).
  # version is "<SageMath version>,<Sage_macOS release tag without the v>".
  version "10.10,10.10.0"
  sha256 arm:   "2adadf4ee625155e21b0441a0f9dae78973e9557cf1e786ef8654de559a2b367",
         intel: "a8abe05aeace30ebf5b6baec83a60bd81780cb17a4c7a801a6cf6ed66a9a5ff8"

  url "https://github.com/3-manifolds/Sage_macOS/releases/download/v#{version.csv.second}/SageMath-#{version.csv.first}_#{arch}.dmg"
  name "Sage"
  desc "Mathematics software system (pre-release app build)"
  homepage "https://www.sagemath.org/"

  livecheck do
    url :url
    regex(%r{/v?(\d+(?:\.\d+)+)/SageMath[._-]v?(\d+(?:\.\d+)+)[._-].*?#{arch}\.dmg$}i)
    strategy :github_releases do |json, regex|
      json.map do |release|
        next if release["draft"]

        release["assets"]&.map do |asset|
          match = asset["browser_download_url"]&.match(regex)
          next if match.blank?

          "#{match[2]},#{match[1]}"
        end
      end.flatten.compact
    end
  end

  # Both casks' Recommended pkg installs /usr/local/bin/sage, the Jupyter kernel
  # spec and sagetex.sty, so uninstalling one would remove files the other uses.
  conflicts_with cask: "sage"
  depends_on :macos

  app "SageMath-#{version.csv.first.dots_to_hyphens}.app"
  pkg "Recommended_#{version.csv.first.dots_to_underscores}.pkg"

  uninstall quit:    [
              "com.tcltk.tcllibrary",
              "com.tcltk.tklibrary",
              "org.computop.sage",
              "org.computop.SageMath",
            ],
            pkgutil: [
              "org.computop.SageMath.#{version.csv.first.dots_to_underscores}.bin",
              "org.computop.SageMath.#{version.csv.first.dots_to_underscores}.share",
              "org.computop.SageMath.#{version.csv.first.dots_to_underscores}.texlive",
            ]

  zap trash: [
    "~/.sage",
    "~/Library/Application Support/SageMath",
    "~/Library/Preferences/SageMath.plist",
  ]

  caveats <<~EOS
    This is a pre-release build of the SageMath macOS app. It may predate
    the final SageMath #{version.csv.first} source release.

    Once homebrew/cask's `sage` reaches #{version.csv.first}, switch back:
      brew uninstall --cask sage-prerelease && brew install --cask sage
  EOS
end
