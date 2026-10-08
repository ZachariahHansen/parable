#!/bin/zsh
# Packages an installed engine for a GitHub release: removes Apple's D3DMetal
# (users import their own copy), strips debug data, adds the license files, and
# writes EngineBuild/parable-engine-<version>.tar.xz.
#
# Usage: Engine/package-engine.sh <installed-engine-name> <version>
#        Engine/package-engine.sh parable-new 11.0-2
# Needs Homebrew's mingw-w64 for its strip tools. Quit anything using the engine first.
set -eu
root=${0:A:h:h}
data="${PARABLE_HOME:-$HOME/Library/Application Support/Parable}"
source=$data/Engines/$1
version=$2
stage=$root/EngineBuild/package
out=$root/EngineBuild/parable-engine-$version.tar.xz

rm -rf $stage && mkdir -p $stage
cp -c -R $source $stage/parable-engine
E=$stage/parable-engine
W=$E/lib/wine

# Put the engine's own DirectX libraries back and drop everything of Apple's.
for module in atidxx64 d3d10 d3d11 d3d12 dxgi nvapi64 nvngx; do
    if [[ -e $W/x86_64-unix/$module.so ]]; then
        rm -f $W/x86_64-unix/$module.so $W/x86_64-windows/$module.dll
        [[ -f $E/wined3d-originals/$module.dll ]] && cp $E/wined3d-originals/$module.dll $W/x86_64-windows/
    fi
done
rm -rf $E/lib/external $E/wined3d-originals

# Debug data is most of an unstripped build. strip keeps the "Wine builtin DLL"
# marker that Wine needs to recognise its own libraries.
for file in $W/x86_64-windows/*; do x86_64-w64-mingw32-strip --strip-debug $file 2>/dev/null || true; done
for file in $W/i386-windows/*; do i686-w64-mingw32-strip --strip-debug $file 2>/dev/null || true; done

mkdir -p $E/licenses
cp $root/EngineBuild/sources/wine/COPYING.LIB $E/licenses/Wine-COPYING.LIB
cp $root/EngineBuild/sources/wine/LICENSE $E/licenses/Wine-LICENSE
cp $root/THIRD-PARTY-NOTICES.md $root/Engine/patches/*.patch $E/licenses/

tar -cf - -C $stage parable-engine | xz -T0 -6 > $out
rm -rf $stage
echo "wrote $out"
shasum -a 256 $out
