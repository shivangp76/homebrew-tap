cask "opentabletdriver" do
  version "0.6.7"

  on_arm do
    sha256 "95e8fe646ccfcee97da5477f2432ce3265ec6c0c5356a23b1b2f41a0b738796f"

    # Upstream only publishes osx-x64 binaries, so build osx-arm64 from source.
    url "https://github.com/OpenTabletDriver/OpenTabletDriver/archive/refs/tags/v#{version}.tar.gz"

    # Upstream's macOS build docs require Homebrew bash (>= 4.3 for `local -n`) and GNU coreutils.
    depends_on formula: ["bash", "coreutils", "dotnet@8"]

    # Install steps are declarative and sandboxed, so the build lives in a script that is
    # written into the staged source tree and then run from there.
    preflight_steps do
      # Backport arm64 support from upstream PR #4943 (first shipped in v0.6.8-rc1): Eto 2.5.10
      # crashes on Apple Silicon, and the csproj pins osx-x64. These inreplaces fail once the
      # source already contains the change, which is the cue to drop them.
      inreplace "OpenTabletDriver-{{version}}/OpenTabletDriver.UX.MacOS/OpenTabletDriver.UX.MacOS.csproj",
                '"Eto.Platform.Mac64" Version="2.5.10"',
                '"Eto.Platform.Mac64" Version="2.11.0"'
      inreplace "OpenTabletDriver-{{version}}/OpenTabletDriver.UX.MacOS/OpenTabletDriver.UX.MacOS.csproj",
                "<RuntimeIdentifiers>osx-x64</RuntimeIdentifiers>",
                "<UseCurrentRuntimeIdentifier>true</UseCurrentRuntimeIdentifier>"

      write_file "otd-build.sh", <<~SH
        #!/bin/sh
        set -eu

        SRC="{{staged_path}}/OpenTabletDriver-{{version}}"
        DOTNET="{{HOMEBREW_PREFIX}}/opt/dotnet@8"

        # Homebrew's PATH is sanitized; keep every .NET cache inside the staged path so the
        # sandbox allows the writes and nothing is left behind in $HOME.
        GNUBIN="{{HOMEBREW_PREFIX}}/opt/coreutils/libexec/gnubin"
        export PATH="$GNUBIN:$DOTNET/bin:{{HOMEBREW_PREFIX}}/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        export DOTNET_ROOT="$DOTNET/libexec"
        export DOTNET_CLI_HOME="{{staged_path}}/.dotnet-home"
        export NUGET_PACKAGES="{{staged_path}}/.nuget-packages"
        export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
        # Don't leave MSBuild/Roslyn server processes running after the build.
        export MSBUILDDISABLENODEREUSE=1 DOTNET_CLI_USE_MSBUILD_SERVER=0 UseSharedCompilation=false

        cd "$SRC"

        # 1. Build, ad-hoc sign (required for arm64) and bundle OpenTabletDriver.app using
        #    upstream's documented "Signed arm64 Package" command.
        "{{HOMEBREW_PREFIX}}/bin/bash" eng/bash/package.sh \\
          --signed true \\
          --runtime osx-arm64 \\
          --package macos \\
          --output "$SRC/dist"

        # 2. Move the bundle where the `app` stanza expects it and drop the build tree.
        rm -rf "{{staged_path}}/OpenTabletDriver.app"
        mv "$SRC/dist/OpenTabletDriver.app" "{{staged_path}}/OpenTabletDriver.app"
        rm -rf "$SRC" "{{staged_path}}/.dotnet-home" "{{staged_path}}/.nuget-packages"
      SH
      run "/bin/sh",
          args:           ["{{staged_path}}/otd-build.sh"],
          print_stdout:   true,
          writable_paths: ["{{staged_path}}"],
          network_access: true # dotnet restore pulls NuGet packages
    end

    caveats <<~EOS
      Upstream doesn't publish Apple Silicon binaries, so this cask builds
      OpenTabletDriver from source with dotnet@8. This takes a few minutes.
    EOS
  end
  on_intel do
    sha256 "c4b0d9eb2aee8ee7be12d0df80f961ea0a7235f54b5f59a2b62efa9b9ec4910e"

    url "https://github.com/OpenTabletDriver/OpenTabletDriver/releases/download/v#{version}/OpenTabletDriver-#{version}_osx-x64.tar.gz"
  end

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
    # Releases aren't notarized, so Gatekeeper will flag them as "damaged"
    # unless the quarantine attribute is stripped.
    run "/usr/bin/xattr", args: ["-cr", "{{appdir}}/OpenTabletDriver.app"]
  end

  zap trash: [
    "~/Library/Application Support/OpenTabletDriver",
    "~/Library/Preferences/com.opentabletdriver.plist",
  ]
end
