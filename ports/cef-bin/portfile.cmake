set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
set(VCPKG_FIXUP_MACHO_RPATH OFF)
set(VCPKG_FIXUP_ELF_RPATH OFF)
set(VCPKG_LIBRARY_LINKAGE static)

# Upstream names its archives <cef version>+<cef commit>+chromium-<chromium version>.
# VERSION is the chromium version; all three move together on a bump.
set(CEF_VERSION "152.0.6")
set(CEF_COMMIT "g708dc14")

set(CEF_OPTIONS "")

if(VCPKG_TARGET_IS_WINDOWS)
    set(CEF_PLATFORM "windows64")
    set(CEF_SHA512 6c004bfebac4f2b05770fb3448c34a9a6538703038c028b58c7b853153da9d7980655086a97cf15d0d0220419a15c5435fbc6c459251c25f156809d6f6bf92b4)
    if(VCPKG_CRT_LINKAGE STREQUAL "dynamic")
        list(APPEND CEF_OPTIONS "-DCEF_RUNTIME_LIBRARY_FLAG=/MD")
    endif()
elseif(VCPKG_TARGET_IS_OSX)
    if(VCPKG_OSX_ARCHITECTURES MATCHES "arm64")
        set(CEF_PLATFORM "macosarm64")
        set(CEF_SHA512 d76937343dfa798aba493873999742fb0b30cce029c29ca9ed5d99f0fe18fddef045933d9de1e81d0daaea17cef6cbad166326f17150b2bb1e89a17738bf5d3c)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=arm64")
    else()
        set(CEF_PLATFORM "macosx64")
        set(CEF_SHA512 70f6611a01bbf94435e91c250a566e0562bf97b3af4263c3b3215694a52e66b10868d55f702ff7ba094f9dfab89f083ef876653b703f310fadab0756670e6622)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=x86_64")
    endif()
elseif(VCPKG_TARGET_IS_LINUX)
    if(VCPKG_TARGET_ARCHITECTURE MATCHES "arm64")
        set(CEF_PLATFORM "linuxarm64")
        set(CEF_SHA512 bb7e1576c35b3b2aeddca81f452f11d537e793842e8a3a292d4c4f96bfb713a457d30f2f6b73085420288907c5e6f3bf3bbb1f1407d75863c278f7c61b892537)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=arm64")
    else()
        set(CEF_PLATFORM "linux64")
        set(CEF_SHA512 dfa0afc5fb41988904c2a7e0835cab0c41afafc2e01e57b64a9726e11350d5bbbb11685bba089fca6d0dd1f6516429c44c14c4dc592572cca3a632ded6ef2ad9)
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
