# Show the ~/Library folder
chflags nohidden ~/Library

# Finder: Display full path in Finder title window
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# Finder: Show icons for hard drives, servers, and removable media on the desktop
defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
defaults write com.apple.finder ShowMountedServersOnDesktop -bool true
defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true
# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Finder: Show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true
# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true
# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true
# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `glyv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
# Auto empty trash after 30 days
defaults write com.apple.finder FXRemoveOldTrashItems -bool "true"
# Don't show warning when changing extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool "false"
# Show icon in finder title bar
defaults write com.apple.universalaccess showWindowTitlebarIcons -bool "true"

# Save screenshots in ~/screenshots
mkdir -p "$HOME/screenshots"
defaults write com.apple.screencapture location -string "$HOME/screenshots"

# Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false

# Safari: Enable the Develop menu and the Web Inspector
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true
# Safari: Show full URL
defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool "true"

# Trackpad: Enable two/three finger swipe between pages and four fingers between full screen apps/workspaces
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadFourFingerHorizSwipeGesture 2
defaults write Apple Global Domain AppleEnableSwipeNavigateWithScrolls 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadThreeFingerHorizSwipeGesture 1
defaults write com.apple.AppleMultitouchTrackpad TrackpadFourFingerHorizSwipeGesture 2

# Trackpad: speed
defaults write -g com.apple.trackpad.scaling 0.875

# Trackpad: Scroll direction natural false
defaults write -g com.apple.swipescrolldirection -bool false

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode2 -bool true

# Save to disk (not to iCloud) by default
defaults write NSGlobalDomain NSDocumentSaveNewDocumentsToCloud -bool false

# Disable smart dashes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticDashSubstitutionEnabled -bool false
# Disable automatic period substitution as it’s annoying when typing code
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
# Disable smart quotes as they’re annoying when typing code
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Enable AirDrop over Ethernet and on unsupported Macs running Lion
defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

# dock: Automatically hide and show the Dock
defaults write com.apple.dock autohide -bool true
# dock size
defaults write com.apple.dock largesize -int 30
defaults write com.apple.dock tilesize -int 40
defaults write com.apple.dock magnification -int  1

# mission control: Don’t automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false
# mission control: Displays have separate spaces
defaults write com.apple.spaces spans-displays -bool true

# Hot corners
# Possible values:
#  0: no-op
#  2: Mission Control
#  3: Show application windows
#  4: Desktop
#  5: Start screen saver
#  6: Disable screen saver
#  7: Dashboard
# 10: Put display to sleep
# 11: Launchpad
# 12: Notification Center
# 13: Lock Screen

# hotcorner: bottom right = lock screen
defaults write com.apple.dock wvous-br-corner -int 13
