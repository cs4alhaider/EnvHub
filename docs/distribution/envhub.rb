# Formula template for cs4alhaider/homebrew-tap → Formula/envhub.rb
# Phase 1: build from source (requires Xcode 26 on the user's machine).
# Phase 2 (preferred once notarized binaries ship): see the commented variant below.
class Envhub < Formula
  desc "Discover and manage every .env file on your machine"
  homepage "https://github.com/cs4alhaider/EnvHub"
  url "https://github.com/cs4alhaider/EnvHub/archive/refs/tags/v0.2.0.tar.gz"
  sha256 "REPLACE_WITH_TARBALL_SHA256"
  license "GPL-3.0-only"
  head "https://github.com/cs4alhaider/EnvHub.git", branch: "main"

  depends_on macos: :tahoe
  depends_on xcode: ["26.0", :build]

  def install
    system "swift", "build", "-c", "release", "--product", "envhub", "--disable-sandbox"
    bin.install ".build/release/envhub"
  end

  test do
    assert_match "Discover and manage", shell_output("#{bin}/envhub --help")
    (testpath/".env").write("A=1\n")
    assert_match ".env", shell_output("#{bin}/envhub scan #{testpath}")
  end
end

# --- Phase 2: binary formula (swap in once release zips are notarized) ------------
# class Envhub < Formula
#   desc "Discover and manage every .env file on your machine"
#   homepage "https://github.com/cs4alhaider/EnvHub"
#   url "https://github.com/cs4alhaider/EnvHub/releases/download/v0.2.0/envhub-0.2.0-macos-arm64.zip"
#   sha256 "REPLACE_WITH_ZIP_SHA256"
#   license "GPL-3.0-only"
#
#   depends_on macos: :tahoe
#   depends_on arch: :arm64
#
#   def install
#     bin.install "envhub"
#   end
#
#   test do
#     assert_match "Discover and manage", shell_output("#{bin}/envhub --help")
#   end
# end
