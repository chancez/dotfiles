{-# LANGUAGE OverloadedStrings #-}

import XMonad
import XMonad.Actions.CopyWindow
import XMonad.Actions.DynamicWorkspaces as DW
import XMonad.Actions.CycleWS
import XMonad.Actions.GridSelect

import XMonad.Hooks.DynamicLog
import XMonad.Hooks.ManageDocks
import XMonad.Hooks.ManageHelpers
import XMonad.Hooks.SetWMName
import XMonad.Hooks.UrgencyHook
import XMonad.Hooks.Place

import XMonad.Layout.Gaps
import XMonad.Layout.Named
import XMonad.Layout.IM
import XMonad.Layout.PerWorkspace
import XMonad.Layout.Grid
import XMonad.Layout.Tabbed
import XMonad.Layout.Spacing
import XMonad.Layout.LayoutHints
import XMonad.Layout.Spacing
import XMonad.Layout.NoBorders(smartBorders, noBorders)
import XMonad.Layout.Reflect
import XMonad.Layout.Fullscreen
import XMonad.Layout.NoFrillsDecoration

import Graphics.X11.ExtraTypes.XF86
import XMonad.Util.Run(spawnPipe)
import XMonad.Util.EZConfig(additionalKeysP)
import System.IO
import System.Posix.Unistd

import Data.Ratio ((%))
import qualified Data.List as L
import qualified Data.Map as M
import qualified XMonad.StackSet as W

import XMonad.Hooks.ManageDocks
import XMonad.Config.Xfce

myHome = "/home/chance"
myBgColor = "#1b1d1e"
myFgColor = "#bbbbbb"
myBorderColor = "#CEEDEB"
myFocusedColor = "#1793D1"
--myCurrentColor = "#cd5c5c"
myCurrentColor = "#1793D1"
myEmptyColor = "#4c4c4c"
myHiddenColor = "#dddddd"
--myLayoutColor = "#666666"
myLayoutColor = "#ebac54"
myUrgentColor = "#2b9ac8"
myFont = "xftfont Bitstream Vera Sans Mono:size=9"

myTerminal = "urxvt"
--myTerminal = "terminator"
myBorderWidth = 1
myStartupHook = setWMName "LG3D"


myLayoutHook = avoidStruts $
                modWorkspace "7:gfx" noBorders . fullscreenFull $
                modWorkspace "4:chat" noBorders . im $
                -- onWorkspace "2:www" (Tall) $
                Full ||| Grid-- The layouts here are the defaults from left->right
                where im =   withIM (1%7) (Role "buddy_list")

myWorkspaces  = ["1:main","2:www","3:games","4:chat","5:mail","6:ext", "7:gfx"]

-- Determines where to place certain floating windows
-- withGaps  (top, right, bottom and left gaps) (placement_loc)
--myPlacement = withGaps (16,16,16,16) (fixed (1,40/100))

myManageHook = (composeAll . concat $
    [ [resource     =? r            --> doIgnore            |   r   <- myIgnores] -- ignore desktop
    , [className    =? c            --> doShift  "2:www"    |   c   <- myWebs   ] -- move webs to web
    , [className    =? c            --> doShift  "3:games"  |   c   <- myGames  ] -- move games to games
    , [className    =? c            --> doShift  "4:chat"   |   c   <- myChats  ] -- move chats and ims to chats
    , [className    =? c            --> doShift  "5:mail"   |   c   <- myMail   ] -- move mail to mail
    , [className    =? c            --> doShift  "6:ext"    |   c   <- myExt    ] -- move external (rdesktop etc) to ext
    , [className    =? c            --> doShift  "7:gfx"    |   c   <- myGfxs   ] -- move graphicapps to gfx
    , [className    =? c            --> doFloat             |   c   <- myFloats ] -- float my floats
    , [name         =? n            --> doFloat             |   n   <- myNames  ] -- float my names
    , [role         =? r            --> doCenterFloat       |   r   <- myRoles  ] -- Float my roles
    , [isDialog                     --> doCenterFloat                           ] -- Float dialogs
    , [isFullscreen                 --> doF W.focusDown <+> doFullFloat         ] -- YouTube fullscreen fix
    --, [className    =? c            --> placeHook myPlacement             |   c   <- myGames ] -- float my floats
    ])

    where

        role      = stringProperty "WM_WINDOW_ROLE"
        name      = stringProperty "WM_NAME"

        -- classnames
        myFloats  = ["MPlayer","Zenity","VirtualBox","Xmessage","Save As...","XFontSel","Downloads",
        "Nm-connection-editor","Add to Panel","gvbam","Gvbam","nautilus","Nautilus","desmume","Desmume",
        "Places","Update","Thunar","skype", "Skype"]

        myWebs    = ["Navigator","Shiretoko","Firefox","Uzbl","uzbl","Uzbl-core","uzbl-core","firefox","Shredder"]
        myMail    = ["Thunderbird","Mail","Calendar"]
        myExt     = ["Remmina","rdesktop"]
        myGfxs    = ["Inkscape", "Gimp", "vlc", "Vlc"]
        myChats   = ["Pidgin","Skype"]
        myGames   = ["gvbam","Gvbam","desmume","Desmume","Heroes of Newerth"]
        myHoN     = ["Heroes of Newerth"]

        -- resources
        myIgnores = ["desktop","desktop_window","notify-osd","stalonetray","trayer","xfce4-notifyd","Xfce4-notifyd"]
       -- names
        myNames   = ["bashrun","Google Chrome Options","Chromium Options","gmrun","Library",
        "DownThemAll! - Make Your Selection","Software Update","Applications Menu"]

        --roles
        myRoles   = ["EventDialog","Preferences","Msgcompose","Manager","EventSummaryDialog","About","Wizard"]

dmenu_opts = "dmenu_run -fn \"" ++ myFont ++ "\" -nb \"" ++ myBgColor ++ "\" -nf \"" ++ myFgColor ++ "\" -sb \"" ++ myFocusedColor ++ "\" -sf white"

main :: IO ()
main = do
    xmonad $ withUrgencyHook NoUrgencyHook
           $ xfceConfig
           { workspaces = myWorkspaces
           -- , modMask = mod4Mask
           , terminal = myTerminal
           , borderWidth = myBorderWidth
           , normalBorderColor = myBorderColor
           , focusedBorderColor = myFocusedColor
           , handleEventHook    = fullscreenEventHook
           , manageHook = myManageHook <+> fullscreenManageHook <+> manageHook xfceConfig
           , layoutHook = myLayoutHook ||| layoutHook xfceConfig
           } `additionalKeysP`
             [ ("M-S-t", spawn "nightly")
             , ("M-S-m", spawn "thunderbird")
             , ("M-p", spawn dmenu_opts) -- %! Launch dmenu
             , ("<XF86AudioLowerVolume>", spawn "amixer -q set Master 2%- & amixer -q set Master unmute") -- decrease volume
             , ("<XF86AudioRaiseVolume>", spawn "amixer -q set Master 2%+ & amixer -q set Master unmute") -- raise volume
             , ("<XF86AudioMute>", spawn "amixer -q set Master toggle") -- toggle mute
             --, ("<Print>", spawn "~/bin/shoot") -- Runs shooter, a script located in ~/bin/
             , ("M-S-q", spawn "xfce4-session-logout")
             ]

