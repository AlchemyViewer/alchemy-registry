set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
set(VCPKG_FIXUP_MACHO_RPATH OFF)
set(VCPKG_FIXUP_ELF_RPATH OFF)
set(VCPKG_LIBRARY_LINKAGE static)

# Upstream names its archives <cef version>+<cef commit>+chromium-<chromium version>.
# VERSION is the chromium version; all three move together on a bump.
set(CEF_VERSION "156.0.30")
set(CEF_COMMIT "g6028375")

set(CEF_OPTIONS "")

if(VCPKG_TARGET_IS_WINDOWS)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(CEF_PLATFORM "windowsarm64")
        set(CEF_SHA512 3b95bf08c8469494733055d98a3b990d8dfefdae6e8b4e42deb636ba78d6c3d2ab72eb5c238ebe90eb9a5be539a9bcdcbf333654637243876f98165acd3d18ee)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=arm64")
    else()
        set(CEF_PLATFORM "windows64")
        set(CEF_SHA512 1268132e72ad06fee46238c020846990a4054cb58766e397faa1d4f21d92b5aa9755b13f82f2f988e4ab6ca7a99768e733ae98cc8d114bd0e36f16359a48e50b)
    endif()
    if(VCPKG_CRT_LINKAGE STREQUAL "dynamic")
        list(APPEND CEF_OPTIONS "-DCEF_RUNTIME_LIBRARY_FLAG=/MD")
    endif()
elseif(VCPKG_TARGET_IS_OSX)
    if(VCPKG_OSX_ARCHITECTURES MATCHES "arm64")
        set(CEF_PLATFORM "macosarm64")
        set(CEF_SHA512 30faa9a877c98bb4b91e958efe21d4fb549cb395ba917435a2acc45c9111fb57ff712bc396569c6bb86220a803b6c2311ec791749d23adca11bd5b83a775a5e8)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=arm64")
    else()
        set(CEF_PLATFORM "macosx64")
        set(CEF_SHA512 20dd63bcc6c0667ad37c7bf4fdbed702e7a4e846cc23cea6509bb0a55645455f68c8642005742390e983acccc0c8d58ff4a8a63b4a83d36c8082e487dd77951c)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=x86_64")
    endif()
elseif(VCPKG_TARGET_IS_LINUX)
    if(VCPKG_TARGET_ARCHITECTURE MATCHES "arm64")
        set(CEF_PLATFORM "linuxarm64")
        set(CEF_SHA512 bb06f7c34159308076cce9431c2150c395a13ec347beda2fd22397a2f7f9bd33b51ffb2e803bb312ba860328341406adc6ac7052ee19071151f069ce4a2426e6)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=arm64")
    else()
        set(CEF_PLATFORM "linux64")
        set(CEF_SHA512 96459c2bcc2edc198f1673d6f66bea35849e19a16a84c4721e08b3c65d2285b598196edfd7c2b8801ccbc2342d893b90bd0d6b5ec299f06b408fae674cc00c9a)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=x86_64")
    endif()
else()
    message(FATAL_ERROR "cef-bin has no upstream binary distribution for ${TARGET_TRIPLET}.")
endif()

vcpkg_download_distfile(ARCHIVE
    URLS "https://cef-builds.spotifycdn.com/cef_binary_${CEF_VERSION}%2B${CEF_COMMIT}%2Bchromium-${VERSION}_${CEF_PLATFORM}.tar.bz2"
    FILENAME "cef.${VERSION}.${CEF_PLATFORM}.tar.bz2"
    SHA512 ${CEF_SHA512}
)

vcpkg_extract_source_archive(
    CEF_SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
)

vcpkg_cmake_configure(
    SOURCE_PATH "${CEF_SOURCE_PATH}"
    OPTIONS
        ${CEF_OPTIONS}
)

vcpkg_cmake_build(
    TARGET libcef_dll_wrapper
)

# The distribution ships a Release tree always and a Debug tree beside it; a
# release-only triplet takes the former alone.
set(CEF_CONFIGS "Release")
if(NOT VCPKG_BUILD_TYPE)
    list(APPEND CEF_CONFIGS "Debug")
endif()

file(INSTALL "${CEF_SOURCE_PATH}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include/cef/include")

# The wrapper is built here rather than shipped, and upstream has no install rule
# for it, so take it out of the build tree.
if(VCPKG_TARGET_IS_WINDOWS)
    set(CEF_WRAPPER_NAME "libcef_dll_wrapper.lib")
else()
    set(CEF_WRAPPER_NAME "libcef_dll_wrapper.a")
endif()

file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/libcef_dll_wrapper/${CEF_WRAPPER_NAME}"
     DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
if(NOT VCPKG_BUILD_TYPE)
    file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg/libcef_dll_wrapper/${CEF_WRAPPER_NAME}"
         DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
endif()

if(VCPKG_TARGET_IS_WINDOWS)
    file(INSTALL "${CEF_SOURCE_PATH}/Release/libcef.dll" DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
    file(INSTALL "${CEF_SOURCE_PATH}/Release/libcef.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    if(NOT VCPKG_BUILD_TYPE)
        file(INSTALL "${CEF_SOURCE_PATH}/Debug/libcef.dll" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/bin")
        file(INSTALL "${CEF_SOURCE_PATH}/Debug/libcef.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
    endif()

    # The rest of the loader payload — bootstrap, ANGLE, SwiftShader, snapshots —
    # is staged next to the consumer's executable, not linked against.
    foreach(config IN LISTS CEF_CONFIGS)
        file(INSTALL
            DIRECTORY "${CEF_SOURCE_PATH}/${config}/"
            DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/${config}"
            FILES_MATCHING
            PATTERN "*.*"
            PATTERN "libcef.dll" EXCLUDE
            PATTERN "libcef.lib" EXCLUDE
        )
    endforeach()

    file(INSTALL "${CEF_SOURCE_PATH}/Resources" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
elseif(VCPKG_TARGET_IS_OSX)
    # Everything the loader needs lives inside the framework bundle, which the
    # consumer embeds rather than stages file by file.
    file(RENAME "${CEF_SOURCE_PATH}/Release/Chromium Embedded Framework.framework"
                "${CURRENT_PACKAGES_DIR}/lib/Chromium Embedded Framework.framework")
    if(NOT VCPKG_BUILD_TYPE)
        file(RENAME "${CEF_SOURCE_PATH}/Debug/Chromium Embedded Framework.framework"
                    "${CURRENT_PACKAGES_DIR}/debug/lib/Chromium Embedded Framework.framework")
    endif()
elseif(VCPKG_TARGET_IS_LINUX)
    file(INSTALL "${CEF_SOURCE_PATH}/Release/libcef.so" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    if(NOT VCPKG_BUILD_TYPE)
        file(INSTALL "${CEF_SOURCE_PATH}/Debug/libcef.so" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
    endif()

    # chrome-sandbox carries no extension, so it needs a pattern of its own to
    # survive the "*.*" filter.
    foreach(config IN LISTS CEF_CONFIGS)
        file(INSTALL
            DIRECTORY "${CEF_SOURCE_PATH}/${config}/"
            DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/${config}"
            FILES_MATCHING
            PATTERN "*.*"
            PATTERN "chrome-sandbox"
            PATTERN "libcef.so" EXCLUDE
        )
    endforeach()

    file(INSTALL "${CEF_SOURCE_PATH}/Resources" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
endif()

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-cef-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-cef")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${CEF_SOURCE_PATH}/LICENSE.txt")
