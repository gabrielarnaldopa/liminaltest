#!/bin/bash
# Compila Kuolki.ipa sin firmar en tu Mac (AltServer la firma con tu Apple ID).
# Uso: abre Terminal en esta carpeta y escribe:  bash compilar-ipa.sh
set -e
cd "$(dirname "$0")"

# Xcode 26 da el Liquid Glass real; con Xcode 16 compila igual, con cristal esmerilado.
XC=$(ls -d /Applications/Xcode_26*.app /Applications/Xcode-26*.app 2>/dev/null | sort -V | tail -1)
[ -n "$XC" ] && export DEVELOPER_DIR="$XC/Contents/Developer"
echo "Usando: $(xcodebuild -version | head -1)"

rm -rf build Payload Kuolki.ipa
xcodebuild -project Liminal.xcodeproj -target Liminal -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build | grep -E "error:|BUILD (SUCCEEDED|FAILED)" || true

APP=build/Release-iphoneos/Liminal.app
[ -d "$APP" ] || { echo "No se compiló. Abre el proyecto en Xcode para ver el error."; exit 1; }
[ -d "$APP/PlugIns/LiminalWidgets.appex" ] || { echo "Falta LiminalWidgets.appex"; exit 1; }
[ -n "$(find "$APP" -name 'BricolageGrotesque-Regular.ttf' -print -quit)" ] || { echo "Falta la fuente Bricolage (carpeta Liminal/Fonts)"; exit 1; }

mkdir Payload && cp -R "$APP" Payload/
zip -qry Kuolki.ipa Payload && rm -rf Payload
echo "Listo: $(pwd)/Kuolki.ipa ($(du -h Kuolki.ipa | cut -f1))"
