class Yabai < Formula
  desc "Tiling window manager for macOS based on binary space partitioning"
  homepage "https://github.com/AhsanFazal/yabai"
  # Built from the AhsanFazal fork (macOS 27 scripting-addition fixes), pinned to a commit.
  url "https://github.com/AhsanFazal/yabai.git",
      revision: "ad8d5adfdc39c76399599ae79a264f2525f6ca5e"
  version "7.1.25-ad8d5ad"
  license "MIT"
  head "https://github.com/AhsanFazal/yabai.git", branch: "master"

  depends_on :macos

  conflicts_with "asmvik/formulae/yabai", because: "both install a `yabai` binary"

  def install
    system "make", "-j1", "install"
    system "codesign", "-fs", "-", "bin/yabai"

    bin.install "bin/yabai"
    (pkgshare/"examples").install "examples/yabairc", "examples/skhdrc"
    man1.install "doc/yabai.1"
  end

  def caveats
    <<~EOS
      Copy the example configuration into your home directory:
        cp #{opt_pkgshare}/examples/yabairc ~/.yabairc
        cp #{opt_pkgshare}/examples/skhdrc ~/.skhdrc

      If you want yabai to be managed by launchd (start automatically upon login):
        yabai --start-service

      If you are using the scripting-addition, update your sudoers file after
      every install/upgrade (the binary hash changes):
        sudo visudo -f /private/etc/sudoers.d/yabai
      with the line produced by:
        echo "$(whoami) ALL=(root) NOPASSWD: sha256:$(shasum -a 256 $(which yabai) | cut -d " " -f 1) $(which yabai) --load-sa"
    EOS
  end

  test do
    assert_match "yabai-v7.1.25", shell_output("#{bin}/yabai --version")
  end
end
