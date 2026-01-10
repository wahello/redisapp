#!/usr/bin/env bash
# set -e

CURR_DIR=$(pwd)

# =========================== CHECK FORCE FLAG =================================
if [ "$1" == "--force" ]; then
  FORCE=true
fi

rm -rf build

# 固定你当前使用的版本（保持原脚本行为）
VERSION=8.4.0

# =========================== DOWNLOAD =========================================
DOWNLOAD_URL="http://download.redis.io/releases/redis-$VERSION.tar.gz"
TARBALL_NAME="redis-$VERSION.tar.gz"
LOCAL_TARBALL="$CURR_DIR/$TARBALL_NAME"


if [ -f "$LOCAL_TARBALL" ]; then
  echo "--> Using local redis tarball: $LOCAL_TARBALL"
  cp "$LOCAL_TARBALL" /tmp/redis.tar.gz
else
  echo "--> Downloading: $DOWNLOAD_URL"
  curl -o /tmp/redis.tar.gz "$DOWNLOAD_URL"
fi

# =========================== PREPARE DIRECTORIES ==============================
VENDOR_DIR="$(pwd)/Vendor/redis"

echo "--> Cleaning $VENDOR_DIR"
rm -rf "$VENDOR_DIR"
mkdir -p "$VENDOR_DIR"

# =========================== EXTRACT ==========================================
echo "--> Extracting redis"
tar xzf /tmp/redis.tar.gz -C /tmp
REDIS_SRC_DIR=$(ls -d /tmp/redis-* | head -n 1)

# =========================== COMPILE & INSTALL ================================
echo "--> Compiling redis in $REDIS_SRC_DIR"
cd "$REDIS_SRC_DIR"

make distclean >/dev/null 2>&1 || true
make  || true
# make install PREFIX="../" SKIP_TESTS=yes

cd "$CURR_DIR"

# =========================== MOVE INSTALL RESULT ==============================
echo "--> Moving redis install result to $VENDOR_DIR"
# mv /tmp/redis-*/* "$VENDOR_DIR"

# =========================== COPY BINARIES INTO APP ============================
echo "--> Injecting redis binaries into app bundle"

mkdir -p $VENDOR_DIR/bin/

cp -v "$REDIS_SRC_DIR/src/redis-server"    "$VENDOR_DIR/bin/"
cp -v "$REDIS_SRC_DIR/src/redis-cli"       "$VENDOR_DIR/bin/"
cp -v "$REDIS_SRC_DIR/src/redis-benchmark" "$VENDOR_DIR/bin/"
cp -v "$REDIS_SRC_DIR/src/redis-check-aof" "$VENDOR_DIR/bin/" 2>/dev/null || true
cp -v "$REDIS_SRC_DIR/src/redis-check-rdb" "$VENDOR_DIR/bin/" 2>/dev/null || true

chmod +x "$VENDOR_DIR/"*

# =========================== CLEANUP ==========================================
echo "--> Cleaning temp files"
rm -rf /tmp/redis.tar.gz
rm -rf /tmp/redis-*

# =========================== BUILD ============================================
echo "--> Building Redis.app"

if [ "$FORCE" ]; then
  NEW_BUILD=$((CURR_BUILD + 1))
else
  NEW_BUILD=1
fi

export RELEASE_VERSION="${VERSION}-build.${NEW_BUILD}"

echo " -- Update Info.plist to $RELEASE_VERSION"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${RELEASE_VERSION}" Redis/Info.plist
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${RELEASE_VERSION}" Redis/Info.plist

BUILD_ROOT="$CURR_DIR/build"

rm -rf "$BUILD_ROOT"

xcodebuild \
  -project Redis.xcodeproj \
  -scheme Redis \
  -configuration Release \
  SYMROOT="$BUILD_ROOT" \
  BUILD_DIR="$BUILD_ROOT" \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

echo "--> Build completed"

# =========================== RELEASE ==========================================
echo "--> Creating zip"

pushd "$BUILD_ROOT/Release"
zip -r -y "$CURR_DIR/Redis.zip" Redis.app
popd
# cd "$CURR_DIR"

# FILE_SIZE=$(du "$CURR_DIR/Redis.zip" | cut -f1)

# =========================== APPCAST ==========================================
# echo "--> Creating AppCast post"

# rm -rf ./_posts/release
# mkdir -p ./_posts/release

# cat <<EOF > ./_posts/release/$(date +"%Y-%m-%d")-${RELEASE_VERSION}.md
# ---
# version: $RELEASE_VERSION
# redis_version: $VERSION
# package_url: https://github.com/jpadilla/redisapp/releases/download/$RELEASE_VERSION/Redis.zip
# package_length: $FILE_SIZE
# category: release
# ---
# - Updates redis to $VERSION
# EOF

# =========================== DONE =============================================
echo ""
echo "================== Next steps =================="
echo "git commit -am 'Release $RELEASE_VERSION'"
echo "git tag $RELEASE_VERSION"
echo "git push origin --tags"
echo ""
echo "Upload Redis.zip to GitHub"
echo "https://github.com/wahello/redisapp/releases/tag/$RELEASE_VERSION"
echo ""
echo "git checkout gh-pages"
echo "git add ."
echo "git commit -am 'Release $RELEASE_VERSION'"
echo "git push origin gh-pages"
echo ""
echo "==> Done!"
