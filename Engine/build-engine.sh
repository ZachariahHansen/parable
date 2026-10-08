#!/bin/zsh
# Builds the Parable engine: CrossOver's Wine source plus the patches in Engine/patches.
#
# Needs: Xcode, Rosetta 2, and Homebrew's mingw-w64 bison pkg-config freetype gnutls sdl2
# (the last three only for their headers). Also needs, already in EngineBuild/:
#   crossover-sources-26.3.0.tar.gz   from https://www.codeweavers.com/crossover/source
#   x86libs/                          x86_64 builds of FreeType, GnuTLS, SDL2, Vulkan...
#                                     whose install names end in their own file name
#
# Usage: Engine/build-engine.sh [engine-name]     (default: parable-new)
# The result lands in ~/Library/Application Support/Parable/Engines/<engine-name>.
set -eu
root=${0:A:h:h}
B=$root/EngineBuild
data="${PARABLE_HOME:-$HOME/Library/Application Support/Parable}"
name=${1:-parable-new}
export PATH="/opt/homebrew/opt/bison/bin:/opt/homebrew/bin:$PATH"   # Wine needs bison 3; macOS ships 2.3

# 1. Source, patched.
if [[ ! -d $B/sources/wine ]]; then
    tar -xzf $B/crossover-sources-26.3.0.tar.gz -C $B sources/wine
    for patch in $root/Engine/patches/*.patch; do patch -d $B/sources/wine -p1 < $patch; done
fi

# 2. Configure. Run under Rosetta so the build targets x86_64, the only kind of
#    Wine that can run x86 Windows games.
mkdir -p $B/build && cd $B/build
arch -x86_64 $root/Engine/configure-engine.sh > configure.log 2>&1

# configure's check for the Vulkan library records a garbled name; a wrong name
# sends Wine into a crash loop on first start.
sed -i '' 's|#define SONAME_LIBVULKAN .*|#define SONAME_LIBVULKAN "libvulkan.1.dylib"|' include/config.h

# 3. Compile. The font tool runs during the build and must find FreeType, so it
#    alone gets a library search path baked in.
arch -x86_64 make tools/sfnt2fon/sfnt2fon LDFLAGS="-L$B/x86libs -Wl,-rpath,$B/x86libs" >> make.log 2>&1
arch -x86_64 make -j$(sysctl -n hw.ncpu) >> make.log 2>&1
arch -x86_64 make install -j$(sysctl -n hw.ncpu) >> make.log 2>&1

# 4. Assemble the engine: Wine, the support libraries it loads by name, and D3DMetal.
E=$data/Engines/$name
rm -rf $E && mkdir -p $E/bin $E/lib $E/share $E/wined3d-originals
cp $B/install/bin/wine $B/install/bin/wineserver $E/bin/
cp -R $B/install/lib/wine $E/lib/
cp -R $B/install/share/wine $E/share/
cp -a $B/x86libs/*.dylib $E/lib/

# Apple's D3DMetal (non-commercial redistribution only) is kept outside the repo.
if [[ -d $data/D3DMetal ]]; then
    cp -R $data/D3DMetal/external $E/lib/external
    for dll in $data/D3DMetal/x86_64-windows/*.dll; do
        module=${dll:t:r}
        [[ -f $E/lib/wine/x86_64-windows/$module.dll ]] && mv $E/lib/wine/x86_64-windows/$module.dll $E/wined3d-originals/
        cp $dll $E/lib/wine/x86_64-windows/
        # Symlinks, not copies: libd3dshared finds the framework relative to its real location.
        ln -sf ../../external/libd3dshared.dylib $E/lib/wine/x86_64-unix/$module.so
    done
fi

# Records which fixes this build carries.
print -l steam-ui recv-tos sdl-controllers > $E/parable-features
echo "built engine '$name' at $E"
