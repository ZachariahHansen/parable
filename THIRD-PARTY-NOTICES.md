# Third-party notices

Parable's own code (the app, the command-line tool and the scripts in this repository) is released under the MIT license; see `LICENSE`.

The **Parable engine**, distributed separately on the releases page, bundles the software below. Each component remains under its own license. License texts are included in the engine archive's `licenses` folder or available from the links.

## Wine

The engine is built from CodeWeavers' CrossOver 26.3 source release (Wine 11.0), with the patches in `Engine/patches`.

- License: GNU Lesser General Public License, version 2.1 or later
- Source: <https://www.codeweavers.com/crossover/source> (`crossover-sources-26.3.0.tar.gz`), plus `Engine/patches` in this repository
- Build procedure: `Engine/build-engine.sh`

Wine is a trademark of its respective owners, and CrossOver is a trademark of CodeWeavers. Parable is not affiliated with or endorsed by the Wine project or CodeWeavers.

## Libraries bundled with the engine

These are unmodified builds, taken from the Wine for macOS packages published at <https://github.com/Gcenx/macOS_Wine_builds>.

| Library | License | Source |
| --- | --- | --- |
| FreeType | FreeType License (FTL) | <https://freetype.org> |
| GnuTLS | LGPL 2.1 or later | <https://gnutls.org> |
| Nettle, Hogweed | LGPL 3 or later, or GPL 2 or later | <https://www.lysator.liu.se/~nisse/nettle/> |
| GMP | LGPL 3 or later, or GPL 2 or later | <https://gmplib.org> |
| libtasn1 | LGPL 2.1 or later | <https://www.gnu.org/software/libtasn1/> |
| libidn2 | LGPL 3 or later, or GPL 2 or later | <https://www.gnu.org/software/libidn/> |
| libunistring | LGPL 3 or later, or GPL 2 or later | <https://www.gnu.org/software/libunistring/> |
| p11-kit | BSD 3-Clause | <https://p11-glue.github.io/p11-glue/p11-kit.html> |
| libiconv, libcharset | LGPL 2.1 or later | <https://www.gnu.org/software/libiconv/> |
| gettext (libintl) | LGPL 2.1 or later | <https://www.gnu.org/software/gettext/> |
| SDL 2 | zlib License | <https://libsdl.org> |
| MoltenVK | Apache License 2.0 | <https://github.com/KhronosGroup/MoltenVK> |
| Vulkan Loader | Apache License 2.0 | <https://github.com/KhronosGroup/Vulkan-Loader> |
| libpng | PNG Reference Library License | <http://www.libpng.org> |
| zlib | zlib License | <https://zlib.net> |
| bzip2 | bzip2 License (BSD-style) | <https://sourceware.org/bzip2/> |
| Brotli | MIT | <https://github.com/google/brotli> |
| LZ4 | BSD 2-Clause | <https://lz4.org> |
| XZ Utils (liblzma) | 0BSD | <https://tukaani.org/xz/> |
| Zstandard | BSD 3-Clause | <https://facebook.github.io/zstd/> |
| libffi | MIT | <https://sourceware.org/libffi/> |
| ICU | Unicode License | <https://icu.unicode.org> |
| libxml2, libxslt | MIT | <https://gitlab.gnome.org/GNOME/libxml2> |
| libpcap | BSD 3-Clause | <https://www.tcpdump.org> |
| libinotify-kqueue | MIT | <https://github.com/libinotify-kqueue/libinotify-kqueue> |
| MacPorts Legacy Support | BSD-style (see project) | <https://github.com/macports/macports-legacy-support> |

For the LGPL libraries, the corresponding source is the upstream release of each library; they are linked dynamically and can be replaced inside the engine's `lib` folder.

## Not included: Apple's D3DMetal

The engine does not contain Apple's Game Porting Toolkit or its D3DMetal framework. Parable can import them from a copy that you download yourself from <https://developer.apple.com/games/>, under Apple's license for that software, which permits non-commercial use only.

## Not included: Steam and games

Parable does not distribute Steam, any game, or any other Windows software. Steam is a trademark of Valve Corporation. Parable is not affiliated with Valve, Apple, Nintendo or any game publisher.
