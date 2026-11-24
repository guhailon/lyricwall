# LyricWall 1.0.0 — build notes (2026-11-25)

## What it is
Standalone TrollStore IPA of the 3D water lyrics wall, display-only (no music).
App name 歌词墙， bundle ID `com.guhailong.lyricwall`, version 1.0.0.

## Wall source (found, reused as-is)
- `~/workspace/goals/space/files/ios-jailbreak-split-screen-github/prefs/Resources/lyricwall/`
  (branch v43.41, 1.0.114) — the exact files the SeaDragon Split settings-homepage
  player loads. Copied byte-identical into this project (`lyricwall/`).
- SHA256 of `lyricwall/index.html`: `ea78ff837650d45db6ef4b66f3bed0b7b167940be1607867d53f98f06dc4820c`
- Contents verified in the bundled file: 123 songs (PREVIEW_URLS), 51 wall styles
  (WALL_STYLES, incl. default 原版·梦幻紫 + 50 added), 53 covers (COVER_LIST).
  Note: memory said "103 songs / 50 styles" — the live wall actually has 123 / 51
  (20 Douyin hot-list songs were added in web v7; the 51st style is the default).
- The wall file itself was NOT edited. The splitscreen copy is newer than the web
  artifact v8 in two ways: bottom-row play button already removed (1.0.114) and
  WebAudio synth piano already removed (1.0.111, preview-only + song-0 piano.m4a).

## App (src/)
- Single WKWebView loading local `lyricwall/index.html` via loadFileURL
  (read access to the lyricwall dir) — mirrors the splitscreen player:
  single webview built once, container bg #17112b, pinch-zoom locked
  (pinch off, maximumZoomScale 1.0, bouncesZoom off), 9:16 stage centred by the
  page itself (.page flex center).
- 3D kept intact: the full Three.js WebGL wall (buildLyrics/layoutLyrics,
  water shader, reflections, butterflies) is bundled unchanged
  (`lyricwall/assets/three.min.js` local). Nothing flattened.
- Display-only, enforced in the wrapper (not by editing the wall):
  - document-start user script stubs `HTMLMediaElement.prototype.play` to return
    a resolved Promise ("fake success"): the page believes a preview is playing,
    so lyric lines keep flowing and ripples keep firing, but nothing sounds and
    no audio URL is ever fetched. The page's own preview-failure path is never hit.
  - document-end user script hides playback/external/import UI:
    #bigPlay, #tapHint, #playerNote, #dyBtn, #pvToast, .btn-row, .seek-row,
    .dy-link, .pl-foot — and auto-taps the first song item so the wall flows
    from launch (silent).
  - Navigation delegate allows file:// only; target=_blank links do nothing.
- Toolbar (bottom, native UIToolbar, colours sampled from the approved mockup
  `workspace/your_files/lyric-wall-ipa-mockup-3d.png`: bar #0D525E, white text),
  exactly four items, all driving the wall's own DOM controls:
  - 下一首 → nextBtn.click()
  - 换主题 → wallBtn.click() (opens the 墙面 panel, 51 themes)
  - 搜索 → native alert with text field; JS finds the first .song-item whose
    name/artist contains the query (case-insensitive) and clicks it; "没找到"
    alert when there is no match
  - 随机一首 → clicks a random .song-item
- Icon + launch images are original (PIL-drawn: purple→teal gradient, stars,
  water waves, 歌词 type). No other app's icon copied.
- No SceneDelegate / scene manifest (classic AppDelegate window lifecycle),
  portrait only, status bar hidden, MinimumOSVersion 15.0.

## Build
- `build.sh`: Theos toolchain clang (arm64, iOS 15.0, SDK iPhoneOS16.5) +
  `ldid -S` fake-sign (TrollStore route). NOTE: ldid fails in place under
  ~/workspace ("Operation not permitted" on that mount) — build.sh signs a /tmp
  copy and copies it back. The toolchain's ldid is a Linux binary
  (`~/theos/toolchain/linux/iphone/bin/ldid`); no apt install needed.
- Output: `LyricWall-1.0.0.ipa`, 4,716,551 B,
  SHA256 `133fa76ed5fe98db398836acc7f99ac9ace7ce63f6b4ba3698206cb9cdefdda2`
- `verify.sh`: all checks pass (structure, plist, arm64 Mach-O,
  LC_CODE_SIGNATURE present, toolbar labels + injected-JS markers in binary,
  wall byte-identical, counts 123/51/53, 3D code present, no remote .js/.css/.png).
  Injected JS snippets also pass `node --check`.
- Only remote strings left in the wall are the 123 iTunes preview-audio URLs and
  Douyin search links — both inert in the app (play() stubbed, external
  navigation blocked). No network is needed for lyrics/styles.

## Not verified (needs Lee's device test)
- No headless browser on this machine (no chromium/playwright; WebGL render
  can't be exercised here), so the live behaviour is proven by code inspection
  + syntax checks only, NOT by a render run. Device test must confirm:
  TrollStore install + open, 3D wall renders and flows, toolbar's four items
  (next / theme panel / search / random), theme switching, song list opens.
- UILaunchImages (static PNG launch screens) are included but iOS 15+ may
  ignore them in favour of a black launch screen — cosmetic only.
- No auto-advance to the next song in the app: the fake-success preview never
  fires 'ended', so the current song's lines loop until the user switches
  (via 下一首 / 搜索 / 随机一首）.

## Activation gate (added 2026-11-25, Lee: 加入授权码)
- Model mirrors China Fly 1.0.0: codes live in a hosted JSON, fetched async
  (NSURLSession, 3s timeout); fetch failure never locks; comparison is
  case-insensitive; code is trimmed; the code itself is never logged.
  Differences: this is an app, not a tweak — first launch shows a native
  activation screen and the wall stays locked behind it; activation persists
  in NSUserDefaults (LWActivated + LWActivationCode + LWActivationState).
- List is LyricWall's OWN: `license/codes-lyricwall.json`
  (`{"master": "LW-...", "codes": ["LW-...", "LW-..."]}` — master + 2 samples,
  LW-XXXX-XXXX-XXXX, no 0/O/1/I). Nothing reused from China Fly or splitscreen.
  Master: `LW-AYQP-TXCY-KHVW` (Lee sets/changes masters himself — edit the
  `master` value in this file + the hosted copy, rebuild, redeploy the list).
- URL: `https://guhailong-repo.pages.dev/license/codes-lyricwall.json`
  (mirrors codes-fly.json). A copy is staged at
  `~/workspace/goals/space/files/ios-jailbreak-repo/license/codes-lyricwall.json`
  LOCALLY ONLY — not deployed; the URL goes live when Lee approves the deploy.
  Until then the app uses the bundled fallback (offline activation works).
- Bundled fallback: build.sh copies the same file into the app
  (`LyricWall.app/license/codes-lyricwall.json`); activation checks remote
  first, then the bundled copy. Fresh activation rejects a code absent from
  both; re-validation only revokes when the REMOTE list definitely lacks the
  stored code (a code issued after the build is not in the bundled copy).
- Files: `src/ActivationManager.{h,m}` (fetch/check/persist/revalidate),
  `src/ActivationViewController.{h,m}` (native screen, #17112b bg, #0D525E
  button; text field does NOT force uppercase — China Fly's master bug was
  the box uppercasing input while the comparison was case-sensitive).
  AppDelegate picks the root VC by activation state and swaps back to the
  activation screen on an LWActivationRevoked notification.
- Exposure note: the list is fetchable by design (same as China Fly) and the
  bundled copy ships inside the IPA — anyone who fetches the URL or unpacks
  the IPA can read the codes. Rotate the master if that matters.
- verify.sh now also checks: list bundled + byte-identical to the project
  file, master/codes format + distinct + no CF- prefix, URL/persistence/
  revoke/case-insensitive markers and activation UI strings in the binary.

## Not done (needs Lee's separate approval)
- No push (no repo/workflow for this IPA was created), no deploy, no Telegram.

## 181-install hardening rebuild (2026-11-25)
- Lee's install on iPhone 11 / iOS 16.5 / TrollStore 2.1.1 failed with error 181
  ("Failed to add app to icon cache"); device log proved ldid, CoreTrust bypass
  and container creation all passed — registration (registerApplicationDictionary)
  refused. Icons were verified valid on our side, so the rebuild maximises
  LaunchServices acceptance by making the bundle metadata look like a normal
  Xcode-built app.
- Info.plist additions only (bundle ID, version, name unchanged):
  CFBundleSupportedPlatforms=(iPhoneOS), DTPlatformName=iphoneos,
  DTSDKName=iphoneos16.4, DTSDKBuild=20E247, DTXcode=1430, DTXcodeBuild=14E222.
- NOTE: the SDK dir is named iPhoneOS16.5.sdk but its SDKSettings.plist says
  Version 16.4 / CanonicalName iphoneos16.4 — the SDK actually used is 16.4,
  so DTSDKName/DTSDKBuild/DTXcode follow Xcode 14.3 (the release that shipped
  the 16.4 SDK). BuildMachineOSBuild omitted (no real Xcode build machine).
- Rebuilt IPA: LyricWall-1.0.0.ipa, 4,726,146 B,
  SHA256 2eed221030d9d0956587deddf76630b226541b75ef84703f454c5dc57141f91c
  (prev a41f9600… superseded). verify.sh: 63 PASS, 0 FAIL (57 prior + 6 new
  hardening checks). Activation gate intact (same master/codes, all markers).
- Device install still needs Lee's test; if 181 persists, the cause is
  device-side (stale registration/icon cache), not the package.
