#!/bin/zsh
# لقطات App Store من التطبيق الحقيقي على المحاكي — بلا XCUITest.
#
# يعتمد على خطافات بناء Debug فقط (Core/System/ScreenshotSeed.swift):
#   -NTShotTool <id>      يفتح أداة (`__sidebar__` = قائمة الأدوات)
#   -NTShotInput <text>   يملأ مدخل الأداة ويشغّلها مرة واحدة
#   -NTScreenshotDemo YES يستبدل IP/المزوّد/المدينة الحقيقية بعنوان توثيقي
#
# الاستخدام (على Mac، من جذر المستودع):
#   xcodegen generate
#   xcodebuild -project NetToolbox.xcodeproj -scheme NetToolbox -configuration Debug \
#     -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" \
#     -derivedDataPath /tmp/ntdd -skipMacroValidation build
#   scripts/store-screenshots.sh <sim-udid> <iphone|ipad> <en|ar>
#
# الناتج: /tmp/shots/<label>-<lang>/NN-name.png
# المقاسات المطلوبة: iPhone 17 Pro Max ‏1320×2868 (APP_IPHONE_67)
#                    iPad Pro 13-inch ‏2064×2752 (APP_IPAD_PRO_3GEN_129)
# ⚠️ لقطات المحاكي RGBA — حوّلها إلى RGB قبل الرفع، فالمتجر يرفض قناة الألفا.
# ⚠️ على المحاكي البطيء قد تخرج اللقطة بيضاء قبل أول رسم؛ ارفع SLOW (مثلاً SLOW=3).
set -e
UDID=$1; LABEL=$2; LANGC=$3
SLOW=${SLOW:-1}
APP=${APP:-/tmp/ntdd/Build/Products/Debug-iphonesimulator/NetToolbox.app}
BID=com.m-s-jaber.nettoolbox
OUT=/tmp/shots/$LABEL-$LANGC; rm -rf $OUT; mkdir -p $OUT
LOC=en_US; [ $LANGC = ar ] && LOC=ar_AE

xcrun simctl boot $UDID 2>/dev/null || true
xcrun simctl bootstatus $UDID -b >/dev/null
xcrun simctl status_bar $UDID override --time 9:41 --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --batteryState charged --batteryLevel 100
xcrun simctl ui $UDID appearance light
# تثبيت نظيف: لا سجلّ سابق يظهر في «الأخيرة».
xcrun simctl uninstall $UDID $BID 2>/dev/null || true
xcrun simctl install $UDID $APP

shot() { # name tool input wait
  xcrun simctl terminate $UDID $BID 2>/dev/null || true
  args=(-nettoolbox.onboarded YES -NTScreenshotDemo YES -AppleLanguages "($LANGC)" -AppleLocale $LOC
        -nettoolbox.expandedCategories calculators,diagnostics)
  [ -n "$2" ] && args+=(-NTShotTool $2)
  [ -n "$3" ] && args+=(-NTShotInput "$3")
  xcrun simctl launch $UDID $BID $args >/dev/null
  sleep $(( $4 * SLOW ))
  xcrun simctl io $UDID screenshot $OUT/$1.png 2>/dev/null
  echo "shot $1"
}

shot 00-warmup "" "" 8
rm -f $OUT/00-warmup.png
shot 01-dashboard "" "" 6
shot 02-subnet subnet-calculator "10.20.0.0 22" 5
shot 03-ssl ssl-checker "apple.com" 14
shot 04-dns dns-lookup "apple.com" 8
shot 05-ping ping "1.1.1.1" 10
shot 06-tools __sidebar__ "" 5
xcrun simctl terminate $UDID $BID
