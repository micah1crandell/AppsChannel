cask "appschannel" do
  version "1.1.2"
  sha256 "7b9c1f00391369adb0b28ec86d928c60396a0c0623be3e0242919af7d77af0a6"

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
