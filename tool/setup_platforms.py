#!/usr/bin/env python3
"""Creates the android/ and ios/ folders (if missing) and applies the app's
native configuration: permissions, AdMob app IDs, bundle id, minimum OS.

Safe to run repeatedly. Usage:
    python3 tool/setup_platforms.py            # create + patch
    python3 tool/setup_platforms.py --patch    # patch only
Env overrides: ADMOB_ANDROID_APP_ID, ADMOB_IOS_APP_ID
"""
import os
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP_ID = "com.cyan.voicerealtimetranslater"
APP_NAME = "Voice Realtime Translater"
IOS_DISPLAY_NAME = "Voice Translater"
IOS_MIN = "16.0"
ANDROID_MIN_SDK = "24"
ANDROID_ADMOB = os.environ.get("ADMOB_ANDROID_APP_ID") or "ca-app-pub-3940256099942544~3347511713"
IOS_ADMOB = os.environ.get("ADMOB_IOS_APP_ID") or "ca-app-pub-3940256099942544~1458002511"


def run(*cmd):
    print("+", " ".join(cmd), flush=True)
    subprocess.run(cmd, cwd=ROOT, check=True)


def create_if_missing():
    missing = [p for p in ("android", "ios") if not (ROOT / p).is_dir()]
    if missing:
        run("flutter", "create", "--org", "com.cyan", "--project-name", "voice_realtime_translater",
            "--platforms", ",".join(missing), ".")


def patch_android():
    manifest = ROOT / "android/app/src/main/AndroidManifest.xml"
    if not manifest.exists():
        return
    m = manifest.read_text()
    perms = [
        "android.permission.INTERNET",
        "android.permission.RECORD_AUDIO",
        "android.permission.MODIFY_AUDIO_SETTINGS",
        "android.permission.WAKE_LOCK",
        "com.google.android.gms.permission.AD_ID",
    ]
    for p in perms:
        if p not in m:
            m = m.replace("<application", f'<uses-permission android:name="{p}"/>\n    <application', 1)
    m = re.sub(r'android:label="[^"]*"', f'android:label="{APP_NAME}"', m, count=1)
    if "com.google.android.gms.ads.APPLICATION_ID" not in m:
        meta = (
            '        <meta-data\n'
            '            android:name="com.google.android.gms.ads.APPLICATION_ID"\n'
            f'            android:value="{ANDROID_ADMOB}"/>\n'
        )
        m = m.replace("</application>", meta + "    </application>", 1)
    else:
        m = re.sub(r'(com\.google\.android\.gms\.ads\.APPLICATION_ID"\s*android:value=")[^"]*"',
                   rf'\g<1>{ANDROID_ADMOB}"', m)
    if "android.intent.action.TTS_SERVICE" not in m:
        tts = (
            '        <intent>\n'
            '            <action android:name="android.intent.action.TTS_SERVICE"/>\n'
            '        </intent>\n'
            '        <intent>\n'
            '            <action android:name="android.intent.action.VIEW"/>\n'
            '            <data android:scheme="https"/>\n'
            '        </intent>\n'
        )
        if "<queries>" in m:
            m = m.replace("<queries>", "<queries>\n" + tts, 1)
        else:
            m = m.replace("</manifest>", "    <queries>\n" + tts + "    </queries>\n</manifest>", 1)
    manifest.write_text(m)

    for name in ("build.gradle.kts", "build.gradle"):
        g = ROOT / "android/app" / name
        if not g.exists():
            continue
        s = g.read_text()
        s = re.sub(r'applicationId\s*=?\s*"[^"]*"',
                   f'applicationId = "{APP_ID}"' if name.endswith("kts") else f'applicationId "{APP_ID}"', s)
        s = re.sub(r"minSdk\s*=\s*flutter\.minSdkVersion", f"minSdk = {ANDROID_MIN_SDK}", s)
        s = re.sub(r"minSdkVersion\s+flutter\.minSdkVersion", f"minSdkVersion {ANDROID_MIN_SDK}", s)
        g.write_text(s)
    print("android patched")


def plist_set(plist: Path, key: str, typ: str, value: str):
    text = plist.read_text()
    if f"<key>{key}</key>" in text:
        text = re.sub(rf"(<key>{re.escape(key)}</key>\s*)(<string>.*?</string>|<true/>|<false/>)",
                      lambda mm: mm.group(1) + _plist_value(typ, value), text, count=1, flags=re.S)
    else:
        text = text.replace("<dict>", f"<dict>\n\t<key>{key}</key>\n\t{_plist_value(typ, value)}", 1)
    plist.write_text(text)


def _plist_value(typ, value):
    if typ == "bool":
        return "<true/>" if value == "true" else "<false/>"
    return f"<string>{value}</string>"


def patch_ios():
    plist = ROOT / "ios/Runner/Info.plist"
    if not plist.exists():
        return
    plist_set(plist, "CFBundleDisplayName", "string", IOS_DISPLAY_NAME)
    plist_set(plist, "NSMicrophoneUsageDescription", "string",
              "The microphone is used to hear the conversation so it can be translated on your device.")
    plist_set(plist, "GADApplicationIdentifier", "string", IOS_ADMOB)
    plist_set(plist, "ITSAppUsesNonExemptEncryption", "bool", "false")
    text = plist.read_text()
    if "SKAdNetworkItems" not in text:
        text = text.replace("<dict>", "<dict>\n\t<key>SKAdNetworkItems</key>\n\t<array>\n\t\t<dict>\n"
                            "\t\t\t<key>SKAdNetworkIdentifier</key>\n\t\t\t<string>cstr6suwn9.skadnetwork</string>\n"
                            "\t\t</dict>\n\t</array>", 1)
        plist.write_text(text)

    pbx = ROOT / "ios/Runner.xcodeproj/project.pbxproj"
    if pbx.exists():
        s = pbx.read_text()
        s = re.sub(r"PRODUCT_BUNDLE_IDENTIFIER = com\.cyan\.voiceRealtimeTranslater;",
                   f"PRODUCT_BUNDLE_IDENTIFIER = {APP_ID};", s)
        s = re.sub(r"PRODUCT_BUNDLE_IDENTIFIER = com\.cyan\.voiceRealtimeTranslater\.RunnerTests;",
                   f"PRODUCT_BUNDLE_IDENTIFIER = {APP_ID}.RunnerTests;", s)
        s = re.sub(r"IPHONEOS_DEPLOYMENT_TARGET = [0-9.]+;", f"IPHONEOS_DEPLOYMENT_TARGET = {IOS_MIN};", s)
        pbx.write_text(s)

    podfile = ROOT / "ios/Podfile"
    if podfile.exists():
        p = podfile.read_text()
        p = re.sub(r"^#?\s*platform :ios, '[0-9.]+'", f"platform :ios, '{IOS_MIN}'", p, flags=re.M)
        if "PERMISSION_MICROPHONE" not in p:
            p = p.replace(
                "flutter_additional_ios_build_settings(target)",
                "flutter_additional_ios_build_settings(target)\n"
                "    target.build_configurations.each do |config|\n"
                f"      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '{IOS_MIN}'\n"
                "      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= ['$(inherited)', 'PERMISSION_MICROPHONE=1']\n"
                "    end",
                1,
            )
        podfile.write_text(p)
    print("ios patched")


if __name__ == "__main__":
    if "--patch" not in sys.argv:
        create_if_missing()
    patch_android()
    patch_ios()
