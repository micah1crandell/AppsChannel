cask "appschannel" do
  version "1.1.0"
  sha256 "1c529570ac89a1e201d1fbca39f202f68675aa23c774e210beeb735acf01693a"

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
    "~/.local/bin/appschannel",
    "~/Library/Application Support/AppsChannel",
    "~/Library/Caches/AppsChannel",
    "~/Library/HTTPStorages/com.micahcrandell.AppsChannel",
    "~/Library/Preferences/com.micahcrandell.AppsChannel.plist",
  ]
end
