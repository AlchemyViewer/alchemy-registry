set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
set(VCPKG_FIXUP_MACHO_RPATH OFF)
set(VCPKG_FIXUP_ELF_RPATH OFF)
set(VCPKG_LIBRARY_LINKAGE static)

# Upstream names its archives <cef version>+<cef commit>+chromium-<chromium version>.
# VERSION is the chromium version; all three move together on a bump.
set(CEF_VERSION "154.0.34")
set(CEF_COMMIT "g14c5a08")

set(CEF_OPTIONS "")

if(VCPKG_TARGET_IS_WINDOWS)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(CEF_PLATFORM "windowsarm64")
        set(CEF_SHA512 9a9fe2c88a0fc61f619c5a02d821d01a43a044405045d6b479548df47f20fc84c99e74835601457d18c39e66ef8238ac15ed5deb917edb5163e40c903a7797e6)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=arm64")
    else()
        set(CEF_PLATFORM "windows64")
        set(CEF_SHA512 0193a02c784b7313cf2322e4d0fc4110b6eaffadc3d121ee2b613503483a4d4621971f617d7b8a4309d9fec3c51a4201852eef388e74fbb62cd57c8c1de7de9d)
    endif()
    if(VCPKG_CRT_LINKAGE STREQUAL "dynamic")
        list(APPEND CEF_OPTIONS "-DCEF_RUNTIME_LIBRARY_FLAG=/MD")
    endif()
elseif(VCPKG_TARGET_IS_OSX)
    if(VCPKG_OSX_ARCHITECTURES MATCHES "arm64")
        set(CEF_PLATFORM "macosarm64")
        set(CEF_SHA512 be05a1285a67c51f558a4cc6e6bbd85d2358bb56d80b08ebae2e28910eeba1295b48778121f33f671d6ebcf2f3f146825a75d56531ca56accf561aff8a5087f2)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=arm64")
    else()
        set(CEF_PLATFORM "macosx64")
        set(CEF_SHA512 8d9485b2224ba2cb9f93cec4175e05f7c9d7a1c2ca0483fe099b66fa6ff44124336a9ee039a6445bdac9b04e630128141efc51fce1811c3eff3dddb89ac115e1)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=x86_64")
    endif()
elseif(VCPKG_TARGET_IS_LINUX)
    if(VCPKG_TARGET_ARCHITECTURE MATCHES "arm64")
        set(CEF_PLATFORM "linuxarm64")
        set(CEF_SHA512 00b9924cf487e3c0a2bc42cb9862b7228900445ae8becfebc5a7319f94acefe750bf161d5cf258847bb7be370ebe9469a0d165f6362d39f3671b2d39b2a70205)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=arm64")
    else()
        set(CEF_PLATFORM "linux64")
        set(CEF_SHA512 ad8f732da50a822a8fbb8cff9cbb3570d1cd562712d246d94e0e1241c1233e022d2f6292de8ad8b5fd67edae73b8aba39d4b5a0b2a0c4cacc7379285dcd82b5f)
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
