#!/bin/sh
# Builds Parable.app in the project folder. Usage: ./make-app.sh [debug|release]
set -eu
cd "$(dirname "$0")"
config=${1:-release}

swift build -c "$config" --product ParableApp
bin=$(swift build -c "$config" --show-bin-path)

app=Parable.app
rm -rf "$app"
mkdir -p "$app/Contents/MacOS"
cp "$bin/ParableApp" "$app/Contents/MacOS/Parable"
mkdir -p "$app/Contents/Resources"
cp Assets/AppIcon.icns "$app/Contents/Resources/AppIcon.icns"

cat > "$app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Parable</string>
    <key>CFBundleDisplayName</key><string>Parable</string>
    <key>CFBundleIdentifier</key><string>app.parable.Parable</string>
    <key>CFBundleExecutable</key><string>Parable</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

# Ad-hoc signature so macOS will launch it locally.
codesign --force --sign - "$app"
echo "built $PWD/$app"
