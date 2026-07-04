# Cask template for cs4alhaider/homebrew-tap → Casks/envhub-app.rb
# Requires a Developer-ID-signed, notarized, stapled EnvHub.app zipped on the
# GitHub Release (see HOMEBREW.md §2).
cask "envhub-app" do
  version "0.2.0"
  sha256 "REPLACE_WITH_ZIP_SHA256"

  url "https://github.com/cs4alhaider/EnvHub/releases/download/v#{version}/EnvHub-#{version}.zip"
  name "EnvHub"
  desc "Every .env file on your machine, in one window"
  homepage "https://github.com/cs4alhaider/EnvHub"

  depends_on macos: ">= :tahoe"

  app "EnvHub.app"

  zap trash: [
    "~/Library/Application Support/EnvHub",
  ]
end
