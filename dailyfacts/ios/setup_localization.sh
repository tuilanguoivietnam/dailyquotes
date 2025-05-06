#!/bin/bash

# 设置项目路径
PROJECT_PATH="Runner.xcodeproj"
PROJECT_NAME="Runner"

# 确保本地化目录存在
mkdir -p Runner/zh-Hans.lproj
mkdir -p Runner/ja.lproj
mkdir -p Runner/en.lproj

# 设置 InfoPlist.strings 文件
cat > Runner/zh-Hans.lproj/InfoPlist.strings << EOF
CFBundleDisplayName = "每日正念";
CFBundleName = "每日正念";
EOF

cat > Runner/ja.lproj/InfoPlist.strings << EOF
CFBundleDisplayName = "デイリーマインド";
CFBundleName = "デイリーマインド";
EOF

cat > Runner/en.lproj/InfoPlist.strings << EOF
CFBundleDisplayName = "DailyFacts";
CFBundleName = "DailyFacts";
EOF

# 设置 Info.plist 的本地化
plutil -replace CFBundleDevelopmentRegion -string "en" Runner/Info.plist
plutil -replace CFBundleLocalizations -json '["en", "zh-Hans", "ja"]' Runner/Info.plist

# 设置项目文件中的本地化
/usr/libexec/PlistBuddy -c "Delete :objects:*:knownRegions" "$PROJECT_PATH/project.pbxproj" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :objects:*:knownRegions array" "$PROJECT_PATH/project.pbxproj"
/usr/libexec/PlistBuddy -c "Add :objects:*:knownRegions: string en" "$PROJECT_PATH/project.pbxproj"
/usr/libexec/PlistBuddy -c "Add :objects:*:knownRegions: string Base" "$PROJECT_PATH/project.pbxproj"
/usr/libexec/PlistBuddy -c "Add :objects:*:knownRegions: string zh-Hans" "$PROJECT_PATH/project.pbxproj"
/usr/libexec/PlistBuddy -c "Add :objects:*:knownRegions: string ja" "$PROJECT_PATH/project.pbxproj"

# 确保 Info.plist 在项目文件中的引用正确
/usr/libexec/PlistBuddy -c "Delete :objects:*:buildSettings:INFOPLIST_FILE" "$PROJECT_PATH/project.pbxproj" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :objects:*:buildSettings:INFOPLIST_FILE string Runner/Info.plist" "$PROJECT_PATH/project.pbxproj"

echo "Localization setup completed!" 