set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
set(VCPKG_FIXUP_MACHO_RPATH OFF)
set(VCPKG_FIXUP_ELF_RPATH OFF)
set(VCPKG_LIBRARY_LINKAGE static)

# Upstream names its archives <cef version>+<cef commit>+chromium-<chromium version>.
# VERSION is the chromium version; all three move together on a bump.
set(CEF_VERSION "154.0.32")
set(CEF_COMMIT "g682c378")

set(CEF_OPTIONS "")

if(VCPKG_TARGET_IS_WINDOWS)
    if(VCPKG_TARGET_ARCHITECTURE STREQUAL "arm64")
        set(CEF_PLATFORM "windowsarm64")
        set(CEF_SHA512 382761d95dc5d2b7ee77846499ab7bad7d011bf2851d1ac5904a98531a32708914071f2b456a3fb8db0180041cacb841630858482d3e73ead0a9ed845337d141)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=arm64")
    else()
        set(CEF_PLATFORM "windows64")
        set(CEF_SHA512 34d696bad48cdc216a17ea481154101c4aab880d44315bbf4ae81fd2e6cd1065de42ba53022b0a4bf6c87acc770bb7cebbe30203e430a6cc1609b00f9043173a)
    endif()
    if(VCPKG_CRT_LINKAGE STREQUAL "dynamic")
        list(APPEND CEF_OPTIONS "-DCEF_RUNTIME_LIBRARY_FLAG=/MD")
    endif()
elseif(VCPKG_TARGET_IS_OSX)
    if(VCPKG_OSX_ARCHITECTURES MATCHES "arm64")
        set(CEF_PLATFORM "macosarm64")
        set(CEF_SHA512 b3fca00d848da435b8b71a81fe3de56c4dbe971fb0d981ce620558863bf497a3d76319306c08094ec7b84486f0ebc89c91a379722e891dcde0630dcfb139ab2f)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=arm64")
    else()
        set(CEF_PLATFORM "macosx64")
        set(CEF_SHA512 daad40a9db92fed392fc10153f8f1c354dcbc8869ad1210fdf0de8b146b15f9c4dd810759b9d37c9830b3c97d6e8686990af5ddb961cf2bbe3a532c24910edef)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=x86_64")
    endif()
elseif(VCPKG_TARGET_IS_LINUX)
    if(VCPKG_TARGET_ARCHITECTURE MATCHES "arm64")
        set(CEF_PLATFORM "linuxarm64")
        set(CEF_SHA512 c24f494cc454e8330f50a57b423a2cdd6e015198c4e4b434e639fae18f6c3d6ab622eb1cbd9a7ef9382591891724f0d244b5dee01bfa3a95d7f93201b5a3fd0e)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=arm64")
    else()
        set(CEF_PLATFORM "linux64")
        set(CEF_SHA512 30cf7031fcbf72d44f4e77ad8d8cad2ccbf016b7a908394e1886311079bf2bc28104137ee4fd64bba225548bb684ff340e5fab6a02e1c1984c3a86cb24aaf9c1)
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
    # Debug libcef.so has DCHECKs that break OSR rendering on Linux; always use
    # the release binary. We still need a file at the debug/lib path so the
    # linker finds it, so symlink or copy the release one there.
    if(NOT VCPKG_BUILD_TYPE)
        file(COPY "${CEF_SOURCE_PATH}/Release/libcef.so" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
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
