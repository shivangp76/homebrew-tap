cask "sioyek-head" do
  version :latest
  sha256 :no_check
  # Source: https://github.com/ahrm/sioyek/discussions/1602

  url "https://github.com/ahrm/sioyek.git",
      branch: "development",
      using:  :git
  name "Sioyek"
  desc "PDF viewer for research papers and technical books (built from development HEAD)"
  homepage "https://sioyek.info/"

  conflicts_with cask: "sioyek"
  depends_on arch: :arm64 # guide was only tested on Apple Silicon
  depends_on formula: "qt"

  qt_bin     = HOMEBREW_PREFIX/"opt/qt/bin"
  shimscript = "#{staged_path}/sioyek.wrapper.sh"

  # Homebrew's git strategy clones recursively, so the mupdf/zlib submodules come along.
  preflight do
    ncpu        = Hardware::CPU.cores.to_s
    macos_major = system_command("/usr/bin/sw_vers", args: ["-productVersion"], must_succeed: true)
                  .stdout.strip.split(".").first
    build_env   = { "PATH" => "#{qt_bin}:#{ENV.fetch("PATH")}" }

    # 1. Build MuPDF
    system_command "/usr/bin/make",
                   args:         ["HAVE_GLUT=no", "-j#{ncpu}"],
                   chdir:        staged_path/"mupdf",
                   print_stdout: true,
                   must_succeed: true

    # 2. Patch deployment target to the running macOS major version
    pro = staged_path/"pdf_viewer_build_config.pro"
    pro.write pro.read.gsub(/QMAKE_MACOSX_DEPLOYMENT_TARGET.=.[0-9]+/,
                            "QMAKE_MACOSX_DEPLOYMENT_TARGET = #{macos_major}")

    # 3. Configure with Qt6 (the -Wno flag works around Qt 6.11's qyieldcpu.h __yield bug)
    system_command "#{qt_bin}/qmake",
                   args:         ["CONFIG+=non_portable",
                                  "QMAKE_CXXFLAGS+=-Wno-implicit-function-declaration",
                                  "pdf_viewer_build_config.pro"],
                   chdir:        staged_path,
                   env:          build_env,
                   print_stdout: true,
                   must_succeed: true

    # 4. Build
    system_command "/usr/bin/make",
                   args:         ["-j#{ncpu}"],
                   chdir:        staged_path,
                   env:          build_env,
                   print_stdout: true,
                   must_succeed: true

    # 5. Assemble the app bundle
    build = staged_path/"build"
    FileUtils.rm_rf build
    FileUtils.mkdir_p build
    FileUtils.mv staged_path/"sioyek.app", build/"sioyek.app"

    macos_dir = build/"sioyek.app/Contents/MacOS"
    FileUtils.cp_r staged_path/"pdf_viewer/shaders", macos_dir/"shaders"
    %w[prefs.config prefs_user.config keys.config keys_user.config].each do |f|
      FileUtils.cp staged_path/"pdf_viewer"/f, macos_dir/f
    end
    FileUtils.cp staged_path/"tutorial.pdf", macos_dir/"tutorial.pdf"

    # 6. Embed a PATH into Info.plist so shell utilities resolve when launched from the Dock.
    #    (Homebrew's build PATH is sanitized, so use a sensible fixed one instead.)
    plist      = (build/"sioyek.app/Contents/Info.plist").to_s
    launch_path = "#{HOMEBREW_PREFIX}/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    buddy      = "/usr/libexec/PlistBuddy"
    system_command buddy, args: ["-c", "Add :LSEnvironment dict", plist], must_succeed: false
    added = system_command buddy, args: ["-c", "Add :LSEnvironment:PATH string #{launch_path}", plist],
                                  must_succeed: false
    unless added.success?
      system_command buddy, args: ["-c", "Set :LSEnvironment:PATH #{launch_path}", plist],
                            must_succeed: true
    end

    # 7. Bundle Qt frameworks ("Cannot resolve rpath" warnings for QtPdf/QtVirtualKeyboard are harmless)
    system_command "#{qt_bin}/macdeployqt",
                   args:         [(build/"sioyek.app").to_s],
                   print_stdout: true,
                   must_succeed: true

    # 8. Ad-hoc codesign
    system_command "/usr/bin/codesign",
                   args:         ["--force", "--sign", "-", "--deep", (build/"sioyek.app").to_s],
                   must_succeed: true

    # CLI wrapper (from the thread's follow-up comment); exec keeps Qt's bundle paths intact
    File.write shimscript, <<~EOS
      #!/bin/sh
      exec "#{appdir}/sioyek.app/Contents/MacOS/sioyek" "$@"
    EOS
    FileUtils.chmod "+x", shimscript
  end

  app "build/sioyek.app"
  binary shimscript, target: "sioyek"

  # Not notarized: strip quarantine so Gatekeeper doesn't block launch.
  postflight do
    system_command "/usr/bin/xattr",
                   args:         ["-dr", "com.apple.quarantine", "#{appdir}/sioyek.app"],
                   must_succeed: false
  end

  caveats <<~EOS
    This cask compiles sioyek from the `development` branch and needs the
    Xcode Command Line Tools (`xcode-select --install`). The build takes
    several minutes.

    To pick up newer commits: brew reinstall --cask sioyek-head
  EOS
end
