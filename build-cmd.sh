#!/bin/bash

cd "$(dirname "$0")"

# turn on verbose debugging output for parabuild logs.
set -x
# make errors fatal
set -e

URIPARSER_VERSION="0.8.0.1"
URIPARSER_SOURCE_DIR="uriparser"

if [ -z "$AUTOBUILD" ] ; then 
    fail
fi

if [ "$OSTYPE" = "cygwin" ] ; then
    export AUTOBUILD="$(cygpath -u $AUTOBUILD)"
fi

# load autobuild provided shell functions and variables
set +x
eval "$("$AUTOBUILD" source_environment)"
set -x

top="$(pwd)"
stage="$top"/stage

pushd "$URIPARSER_SOURCE_DIR"
    case "$AUTOBUILD_PLATFORM" in

        "windows")
            load_vsvars

            cmake .

            build_sln "contrib/vstudio/vc10/uriparser.sln" "Debug|Win32" "uriparser"
            build_sln "contrib/vstudio/vc10/uriparser.sln" "Release|Win32" "uriparser"

            mkdir -p "$stage/lib/debug"
            mkdir -p "$stage/lib/release"
            cp -a "contrib/vstudio/vc10/x86/UriParserStatDebug/uriparser.lib" \
                "$stage/lib/debug/uriparserd.lib"
            cp -a "contrib/vstudio/vc10/x86/UriParserStatRelease/uriparser.lib" \
                "$stage/lib/release/uriparser.lib"
            mkdir -p "$stage/include/uriparser"
            cp -a include/uriparser/*.h "$stage/include/uriparser"
        ;;

        "darwin")
            # Select SDK with full path.  This shouldn't have much effect on this
            # build but adding to establish a consistent pattern.
            #
            # sdk=/Developer/SDKs/MacOSX10.6.sdk/
            # sdk=/Developer/SDKs/MacOSX10.7.sdk/
            # sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.6.sdk/
            sdk=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.7.sdk/


            # Keep min version back at 10.5 if you are using the
            # old llqtwebkit repo which builds on 10.5 systems.
            # At 10.6, zlib will start using __bzero() which doesn't
            # exist there.
            opts="${TARGET_OPTS:--arch i386 -iwithsysroot $sdk -mmacosx-version-min=10.6}"

            # Debug first
            CFLAGS="$opts -O0 -gdwarf-2 -fPIC -DPIC" \
                LDFLAGS="-Wl,-install_name,\"${install_name}\" -Wl,-headerpad_max_install_names" \
                ./configure --prefix="$stage" --includedir="$stage/include/uriparser" --libdir="$stage/lib/debug" --disable-test --disable-doc
            make
            make install
            cp -a "$top"/uriparser_darwin_debug.exp "$stage"/lib/debug/uriparser_darwin.exp

            make distclean

            # Now release
            CFLAGS="$opts -O3 -gdwarf-2 -fPIC -DPIC" \
                LDFLAGS="-Wl,-install_name,\"${install_name}\" -Wl,-headerpad_max_install_names" \
                ./configure --prefix="$stage" --includedir="$stage/include/uriparser" --libdir="$stage/lib/release" --disable-test --disable-doc
            make
            make install
            cp -a "$top"/uriparser_darwin_release.exp "$stage"/lib/release/uriparser_darwin.exp

            make distclean
        ;;

        "linux")
            # Linux build environment at Linden comes pre-polluted with stuff that can
            # seriously damage 3rd-party builds.  Environmental garbage you can expect
            # includes:
            #
            #    DISTCC_POTENTIAL_HOSTS     arch           root        CXXFLAGS
            #    DISTCC_LOCATION            top            branch      CC
            #    DISTCC_HOSTS               build_name     suffix      CXX
            #    LSDISTCC_ARGS              repo           prefix      CFLAGS
            #    cxx_version                AUTOBUILD      SIGN        CPPFLAGS
            #
            # So, clear out bits that shouldn't affect our configure-directed build
            # but which do nonetheless.
            #
            # unset DISTCC_HOSTS CC CXX CFLAGS CPPFLAGS CXXFLAGS

            # Prefer gcc-4.6 if available.
            if [[ -x /usr/bin/gcc-4.6 && -x /usr/bin/g++-4.6 ]]; then
                export CC=/usr/bin/gcc-4.6
                export CXX=/usr/bin/g++-4.6
            fi

            # Default target to 32-bit
            opts="${TARGET_OPTS:--m32}"

            # Handle any deliberate platform targeting
            if [ -z "$TARGET_CPPFLAGS" ]; then
                # Remove sysroot contamination from build environment
                unset CPPFLAGS
            else
                # Incorporate special pre-processing flags
                export CPPFLAGS="$TARGET_CPPFLAGS"
            fi

            # generate configue script
            ./autogen.sh

            # Debug first
            CFLAGS="$opts -O0 -g -fPIC -DPIC" CXXFLAGS="$opts -O0 -g -fPIC -DPIC" \
                ./configure --prefix="$stage" --includedir="$stage/include/uriparser" --libdir="$stage/lib/debug" --disable-test
            make
            make install

            # clean the build artifacts
            make distclean

            # Release last
            CFLAGS="$opts -O3 -fPIC -DPIC" CXXFLAGS="$opts -O3 -fPIC -DPIC" \
                ./configure --prefix="$stage" --includedir="$stage/include/uriparser" --libdir="$stage/lib/release" --disable-test
            make
            make install

            # clean the build artifacts
            make distclean
        ;;
    esac
    mkdir -p "$stage/LICENSES"
    pwd
    cp -a COPYING "$stage/LICENSES/uriparser.txt"
popd

pass











