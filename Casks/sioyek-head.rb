cask "sioyek-head" do
  version :latest
  sha256 :no_check

  # Source: https://github.com/ahrm/sioyek/discussions/1602
  url "https://github.com/shivangp76/sioyek.git",
      branch: "development",
      using:  :git
  name "Sioyek"
  desc "PDF viewer for research papers and technical books (built from development HEAD)"
  homepage "https://sioyek.info/"

  conflicts_with cask: "sioyek"
  depends_on arch: :arm64 # guide was only tested on Apple Silicon
  depends_on formula: "qt"
  depends_on :macos

  app "build/sioyek.app"
  binary "sioyek.wrapper.sh", target: "sioyek"

  # Homebrew's git strategy clones recursively, so the mupdf/zlib submodules come along.
  # Install steps are declarative and sandboxed, so the build lives in a script that is
  # written into the staged source tree and then run from there.
  preflight_steps do
    write_file "sioyek-build.sh", <<~SH
      #!/bin/sh
      set -eu

      QT_BIN="{{HOMEBREW_PREFIX}}/opt/qt/bin"
      # Homebrew's PATH is sanitized; put Qt first so qmake/macdeployqt resolve.
      export PATH="$QT_BIN:/usr/bin:/bin:/usr/sbin:/sbin"
      NCPU="$(sysctl -n hw.ncpu)"
      cd "{{staged_path}}"

      # 1. Build MuPDF
      make -C mupdf HAVE_GLUT=no -j"$NCPU"

      # 2. Patch deployment target to the running macOS major version
      sed -Ei '' "s/QMAKE_MACOSX_DEPLOYMENT_TARGET.=.[0-9]+/QMAKE_MACOSX_DEPLOYMENT_TARGET = $(sw_vers -productVersion | cut -d. -f1)/" \\
        pdf_viewer_build_config.pro

      # 3. Configure with Qt6 (the -Wno flag works around Qt 6.11's qyieldcpu.h __yield bug)
      qmake CONFIG+=non_portable \\
        QMAKE_CXXFLAGS+=-Wno-implicit-function-declaration \\
        pdf_viewer_build_config.pro

      # 4. Build
      make -j"$NCPU"

      # 5. Assemble the app bundle. On macOS sioyek resolves shaders/configs/tutorial from
      #    Contents/Resources (see configure_paths() in pdf_viewer/main.cpp). Without the
      #    shaders the document still loads (page count/scroll bar work) but no pages are drawn.
      rm -rf build
      mkdir build
      mv sioyek.app build/sioyek.app
      RESOURCES=build/sioyek.app/Contents/Resources
      mkdir -p "$RESOURCES"
      cp -R pdf_viewer/shaders "$RESOURCES/shaders"
      for f in prefs.config prefs_user.config keys.config keys_user.config; do
        cp "pdf_viewer/$f" "$RESOURCES/$f"
      done
      cp tutorial.pdf "$RESOURCES/tutorial.pdf"

      # 6. Embed a PATH into Info.plist so shell utilities resolve when launched from the Dock.
      PLIST=build/sioyek.app/Contents/Info.plist
      LAUNCH_PATH="{{HOMEBREW_PREFIX}}/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
      /usr/libexec/PlistBuddy -c "Add :LSEnvironment dict" "$PLIST" 2>/dev/null || true
      /usr/libexec/PlistBuddy -c "Add :LSEnvironment:PATH string $LAUNCH_PATH" "$PLIST" 2>/dev/null ||
        /usr/libexec/PlistBuddy -c "Set :LSEnvironment:PATH $LAUNCH_PATH" "$PLIST"

      # 7. Bundle Qt frameworks ("Cannot resolve rpath" warnings for QtPdf/QtVirtualKeyboard are harmless)
      macdeployqt build/sioyek.app

      # 8. Ad-hoc codesign
      codesign --force --sign - --deep build/sioyek.app
    SH
    run "/bin/sh", args: ["{{staged_path}}/sioyek-build.sh"], print_stdout: true

    # CLI wrapper (from the thread's follow-up comment); exec keeps Qt's bundle paths intact
    write_file "sioyek.wrapper.sh", <<~SH
      #!/bin/sh
      exec "{{appdir}}/sioyek.app/Contents/MacOS/sioyek" "$@"
    SH
    set_permissions "sioyek.wrapper.sh", "0755"
  end

  # Not notarized: strip quarantine so Gatekeeper doesn't block launch.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/sioyek.app"], must_succeed: false
  end

  caveats <<~EOS
    This cask compiles sioyek from the `development` branch of the
    shivangp76/sioyek fork and needs the Xcode Command Line Tools
    (`xcode-select --install`). The build takes several minutes.

    To pick up newer commits: brew reinstall --cask sioyek-head
  EOS
end
