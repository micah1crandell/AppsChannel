cask "appschannel" do
  version "1.0.0"
  sha256 :no_check # or SHA256 of the release zip/dmg

  url "https://github.com/micah1crandell/AppsChannel/releases/download/v#{version}/AppsChannel.dmg"
  name "AppsChannel"
  desc "Hardware-accelerated 3D Cover Flow & Channel Grid macOS application launcher"
  homepage "https://github.com/micah1crandell/AppsChannel"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on macos: ">= :sonoma"

  app "AppsChannel.app"

  zap trash: [
    "~/Library/Application Support/AppsChannel",
    "~/Library/Caches/AppsChannel",
    "~/Library/Preferences/com.micahcrandell.AppsChannel.plist",
  ]
end
