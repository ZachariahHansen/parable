#!/bin/zsh
# Configures the Parable engine build (run from EngineBuild/build under `arch -x86_64`).
B=${0:A:h:h}/EngineBuild
export PATH="/opt/homebrew/opt/bison/bin:/opt/homebrew/bin:$PATH"
../sources/wine/configure \
  CC="clang -arch x86_64" CXX="clang++ -arch x86_64" \
  --enable-archs=i386,x86_64 --prefix="$B/install" \
  --without-x --without-gstreamer --without-cups --without-sane --without-krb5 --without-gphoto --without-v4l2 \
  --without-oss --without-alsa --without-pulse --without-capi --without-usb --without-netapi --without-wayland \
  --without-unwind --without-opencl --without-ffmpeg \
  --with-freetype --with-gnutls --with-sdl --with-vulkan --with-coreaudio --with-mingw \
  FREETYPE_CFLAGS="-I/opt/homebrew/include/freetype2" FREETYPE_LIBS="-L$B/x86libs -lfreetype" \
  GNUTLS_CFLAGS="-I/opt/homebrew/include" GNUTLS_LIBS="-L$B/x86libs -lgnutls" \
  SDL2_CFLAGS="-I/opt/homebrew/include/SDL2 -D_THREAD_SAFE" SDL2_LIBS="-L$B/x86libs -lSDL2" \
  LDFLAGS="-L$B/x86libs"
