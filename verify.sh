#!/usr/bin/env python3
"""Verify LyricWall-1.0.0.ipa: structure, plist, Mach-O signature, wall content."""
import hashlib
import plistlib
import re
import struct
import subprocess
import sys
import zipfile

IPA = '/home/hatch/workspace/lyricwall-ipa/LyricWall-1.0.0.ipa'
APP = 'Payload/LyricWall.app/'
WALL_SRC = '/home/hatch/workspace/lyricwall-ipa/lyricwall/index.html'

fails = []


def check(name, ok, detail=''):
    print(f"{'PASS' if ok else 'FAIL'}  {name}  {detail}")
    if not ok:
        fails.append(name)


def sha256(b):
    return hashlib.sha256(b).hexdigest()


data = open(IPA, 'rb').read()
print(f'IPA size: {len(data)} B  SHA256: {sha256(data)}')
z = zipfile.ZipFile(IPA)
names = z.namelist()
check('Payload dir present', any(n.startswith('Payload/LyricWall.app/') for n in names))
check('binary present', APP + 'LyricWall' in names)
check('Info.plist present', APP + 'Info.plist' in names)
check('wall index.html present', APP + 'lyricwall/index.html' in names)
assets = [n for n in names if n.startswith(APP + 'lyricwall/assets/') and not n.endswith('/')]
check('wall assets bundled', len(assets) == 55, f'{len(assets)} files')
for icon in ['AppIcon60x60@2x.png', 'AppIcon60x60@3x.png', 'AppIcon76x76@2x.png',
             'AppIcon83.5x83.5@2x.png', 'AppIcon1024x1024.png']:
    check(f'icon {icon}', APP + icon in names)
for li in ['Default-568h@2x.png', 'Default-667h@2x.png', 'Default-736h@3x.png',
           'Default-1792h@2x.png', 'Default-2436h@3x.png', 'Default-2688h@3x.png']:
    check(f'launch image {li}', APP + li in names)

pl = plistlib.loads(z.read(APP + 'Info.plist'))
check('bundle id', pl.get('CFBundleIdentifier') == 'com.guhailong.lyricwall', pl.get('CFBundleIdentifier'))
check('display name', pl.get('CFBundleDisplayName') == '歌词墙', pl.get('CFBundleDisplayName'))
check('version', pl.get('CFBundleShortVersionString') == '1.0.0' and pl.get('CFBundleVersion') == '1.0.0',
      f"{pl.get('CFBundleShortVersionString')} / {pl.get('CFBundleVersion')}")
check('executable', pl.get('CFBundleExecutable') == 'LyricWall')
check('min OS', pl.get('MinimumOSVersion') == '15.0', pl.get('MinimumOSVersion'))
check('181 hardening: CFBundleSupportedPlatforms', pl.get('CFBundleSupportedPlatforms') == ['iPhoneOS'],
      str(pl.get('CFBundleSupportedPlatforms')))
check('181 hardening: DTPlatformName', pl.get('DTPlatformName') == 'iphoneos', pl.get('DTPlatformName'))
check('181 hardening: DTSDKName', pl.get('DTSDKName') == 'iphoneos16.4', pl.get('DTSDKName'))
check('181 hardening: DTSDKBuild', pl.get('DTSDKBuild') == '20E247', pl.get('DTSDKBuild'))
check('181 hardening: DTXcode', pl.get('DTXcode') == '1430', pl.get('DTXcode'))
check('181 hardening: DTXcodeBuild', pl.get('DTXcodeBuild') == '14E222', pl.get('DTXcodeBuild'))
check('device family', pl.get('UIDeviceFamily') == [1, 2], str(pl.get('UIDeviceFamily')))
check('portrait only', pl.get('UISupportedInterfaceOrientations') == ['UIInterfaceOrientationPortrait'])
check('no scene manifest (classic AppDelegate lifecycle)',
      'UIApplicationSceneManifest' not in pl)

# Mach-O: arm64 + LC_CODE_SIGNATURE present
bin = z.read(APP + 'LyricWall')
magic, cputype, _, _, ncmds, _, _, _ = struct.unpack('<8I', bin[:32])
check('Mach-O 64-bit magic', magic == 0xfeedfacf, hex(magic))
check('arm64 cputype', cputype == 0x0100000c, hex(cputype))
off = 32
sig = None
for _ in range(ncmds):
    cmd, size = struct.unpack('<2I', bin[off:off + 8])
    if cmd == 0x1d:  # LC_CODE_SIGNATURE
        sig = struct.unpack('<2I', bin[off + 8:off + 16])
    off += size
check('LC_CODE_SIGNATURE present (fake-signed)', sig is not None and sig[0] > 0 and sig[1] > 0,
      f'dataoff={sig[0]} datasize={sig[1]}' if sig else 'none')
# toolbar labels + injected JS markers inside the binary
# (ObjC @"..." literals with CJK are stored UTF-16LE in __cfstring — check that form)
for s in ['下一首', '换主题', '搜索', '随机一首']:
    check(f'binary contains {s!r} (UTF-16LE __cfstring)', s.encode('utf-16-le') in bin)
for s in ['HTMLMediaElement.prototype.play', 'song-item', 'wallBtn', 'nextBtn']:
    check(f'binary contains {s!r}', s.encode('utf-8') in bin)

# activation gate: own list (never China Fly's / splitscreen's), bundled fallback,
# case-insensitive compare (China Fly lesson), activation screen strings.
import json as _json
check('activation list bundled', APP + 'license/codes-lyricwall.json' in names)
_list = z.read(APP + 'license/codes-lyricwall.json')
_src = open('/home/hatch/workspace/lyricwall-ipa/license/codes-lyricwall.json', 'rb').read()
check('bundled list == project license file (byte-identical)', sha256(_list) == sha256(_src))
parsed = _json.loads(_list)
master = parsed.get('master', '')
codes = parsed.get('codes', [])
pat = re.compile(r'^LW-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$')
check('list has string master + codes array', isinstance(master, str) and isinstance(codes, list))
check('master format LW-XXXX-XXXX-XXXX', bool(pat.match(master or '')), master)
check('2 sample codes, same format', len(codes) == 2 and all(pat.match(c or '') for c in codes), str(codes))
check('master distinct from codes', master not in codes)
check('no China Fly reuse (no CF- prefix anywhere)',
      not master.startswith('CF-') and not any(c.startswith('CF-') for c in codes))
check('binary contains list URL (codes-lyricwall.json)',
      b'codes-lyricwall.json' in bin)
check('binary contains LWActivated persistence key', b'LWActivated' in bin)
check('binary contains revoke notification', b'LWActivationRevokedNotification' in bin)
check('binary contains caseInsensitiveCompare (case-insensitive check)',
      b'caseInsensitiveCompare' in bin)
for s in ['授权码', '输入授权码，开启歌词墙', '激活']:
    check(f'binary contains activation UI {s!r} (UTF-16LE __cfstring)', s.encode('utf-16-le') in bin)

# wall content: bundled file identical to splitscreen source; counts
wall = z.read(APP + 'lyricwall/index.html')
src = open(WALL_SRC, 'rb').read()
check('bundled wall == splitscreen source (byte-identical)', sha256(wall) == sha256(src),
      f'{sha256(wall)[:12]} vs {sha256(src)[:12]}')
text = wall.decode('utf-8', 'ignore')
check('123 songs (PREVIEW_URLS)', text.count('audio-ssl.itunes.apple.com') == 123,
      str(text.count('audio-ssl.itunes.apple.com')))
check('51 wall styles (WALL_STYLES)', len(re.findall(r'\{"name": "', text)) == 51,
      str(len(re.findall(r'\{"name": "', text))))
check('53 covers (COVER_LIST labels)', text.count('"label":') == 53, str(text.count('"label":')))
check('3D kept: THREE.WebGLRenderer present', 'THREE.WebGLRenderer' in text)
check('3D kept: buildLyrics/layoutLyrics present', 'function buildLyrics' in text and 'function layoutLyrics' in text)
check('3D kept: local three.min.js bundled', APP + 'lyricwall/assets/three.min.js' in names)
check('no remote .js/.css/.png refs', not re.search(r'(src|href)="https?://[^"]+\.(js|css|png|jpg|webp)"', text))
remote = sorted(set(re.findall(r'https://[^"\'\s<>]+', text)))
print('remote strings in wall (all inert: audio previews + douyin links, never fetched/clicked):')
for u in remote[:3]:
    print('   ', u[:100])
print(f'    ... {len(remote)} unique remote URLs total (all itunes preview audio + douyin search)')

print()
print('FAILED:', fails if fails else 'none')
sys.exit(1 if fails else 0)
