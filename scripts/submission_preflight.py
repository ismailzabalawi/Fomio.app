#!/usr/bin/env python3
"""Check source or a built .app. A pass is packaging evidence, not review acceptance."""
import argparse
from pathlib import Path
import plistlib
import sys
from urllib.parse import urlsplit


def load(path):
    with path.open("rb") as stream:
        return plistlib.load(stream)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, help="Built Fomio.app, including inside an xcarchive")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    source_info = load(root / "Fomio/Info.plist")
    source_privacy = load(root / "Fomio/Resources/PrivacyInfo.xcprivacy")
    info = load(args.app / "Info.plist") if args.app else source_info
    privacy = load(args.app / "PrivacyInfo.xcprivacy") if args.app else source_privacy
    failures = []

    def check(condition, message):
        print(("PASS " if condition else "FAIL ") + message)
        if not condition:
            failures.append(message)

    base = urlsplit(info.get("FomioBaseURL", ""))
    check(base.scheme == "https" and bool(base.hostname) and not base.username
          and not base.password and not base.query and not base.fragment, "HTTPS community URL")
    callback = urlsplit(info.get("FomioAuthCallback", ""))
    schemes = [s for entry in info.get("CFBundleURLTypes", [])
               for s in entry.get("CFBundleURLSchemes", [])]
    check(bool(callback.scheme) and callback.scheme in schemes, "Authentication callback scheme registered")
    scopes = set(info.get("FomioUserAPIScopes", "").split(","))
    check({"read", "write", "session_info"} <= scopes, "Member API scopes configured")
    check(info.get("ITSAppUsesNonExemptEncryption") is False, "Existing encryption declaration retained")
    check(privacy.get("NSPrivacyTracking") is False, "No tracking declared")
    reasons = {entry["NSPrivacyAccessedAPIType"]: entry.get("NSPrivacyAccessedAPITypeReasons", [])
               for entry in privacy.get("NSPrivacyAccessedAPITypes", [])}
    check("CA92.1" in reasons.get("NSPrivacyAccessedAPICategoryUserDefaults", []),
          "App-only preferences have an approved UserDefaults reason")
    data = {entry["NSPrivacyCollectedDataType"]: entry
            for entry in privacy.get("NSPrivacyCollectedDataTypes", [])}
    for kind in ("Name", "EmailAddress", "UserID", "OtherUserContent", "PhotosorVideos", "SearchHistory", "ProductInteraction", "OtherDataTypes"):
        entry = data.get("NSPrivacyCollectedDataType" + kind, {})
        check(entry.get("NSPrivacyCollectedDataTypeLinked") is True
              and entry.get("NSPrivacyCollectedDataTypeTracking") is False
              and "NSPrivacyCollectedDataTypePurposeAppFunctionality" in entry.get("NSPrivacyCollectedDataTypePurposes", []),
              kind + " disclosed for linked account functionality")
    if args.app:
        check(privacy == source_privacy, "Packaged privacy manifest matches source")
        check(info.get("CFBundleIdentifier") == "com.fomio.mobile", "Production bundle identifier")
        check(bool(info.get("CFBundleIconName") or info.get("CFBundleIcons")), "Compiled app icon metadata")
        check(str(info.get("CFBundleVersion", "")).isdigit(), "Resolved numeric build number")
        check("$(" not in info.get("CFBundleShortVersionString", ""), "Resolved marketing version")
        check(not info.get("NSAppTransportSecurity", {}).get("NSAllowsArbitraryLoads", False), "No global insecure transport exception")
        print(f"Build: {info.get('CFBundleShortVersionString')} ({info.get('CFBundleVersion')})")
    print("Packaging checks do not replace live member/device acceptance and App Store Connect validation.")
    return 1 if failures else 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, plistlib.InvalidFileException) as error:
        print(f"FAIL Could not inspect packaging: {error}", file=sys.stderr)
        sys.exit(1)
