set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
set(VCPKG_FIXUP_MACHO_RPATH OFF)
set(VCPKG_FIXUP_ELF_RPATH OFF)
set(VCPKG_LIBRARY_LINKAGE static)

# Upstream names its archives <cef version>+<cef commit>+chromium-<chromium version>.
# VERSION is the chromium version; all three move together on a bump.
set(CEF_VERSION "151.3.24")
set(CEF_COMMIT "g2384915")

set(CEF_OPTIONS "")

if(VCPKG_TARGET_IS_WINDOWS)
    set(CEF_PLATFORM "windows64")
    set(CEF_SHA512 95b61aa974df5bdd32b58b8dfa919593b8b1adc063fa69967940a2d0d79e089009c11bbfdb779f2b5617358a6f699454219659d64d3a9e1168973764573a533e)
    if(VCPKG_CRT_LINKAGE STREQUAL "dynamic")
        list(APPEND CEF_OPTIONS "-DCEF_RUNTIME_LIBRARY_FLAG=/MD")
    endif()
elseif(VCPKG_TARGET_IS_OSX)
    if(VCPKG_OSX_ARCHITECTURES MATCHES "arm64")
        set(CEF_PLATFORM "macosarm64")
        set(CEF_SHA512 821d9a3a3d57df05c52a9e9e1ebbff733ffbdbc6c7c7429bb5aa44c887859d84d8c0321e9861ddccd2e066229a1b18f563849b8b1512406bed1b408e5a43d463)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=arm64")
    else()
        set(CEF_PLATFORM "macosx64")
        set(CEF_SHA512 f4b4748f71f2e743841e92073dccf2a0ba67266571e9c3580090a9f679ec32cc183634b56e85d29e4f8b8f51c76d8cb7aef65c935ab0f122698541b34381d07a)
        list(APPEND CEF_OPTIONS "-DPROJECT_ARCH=x86_64")
    endif()
elseif(VCPKG_TARGET_IS_LINUX)
    set(CEF_PLATFORM "linux64")
    set(CEF_SHA512 2b3c052420f01a03c15d005b571572bc789228648beaf0d22066af8287f2b513c9f25b0d6f042a325825005890c8f2532b08cc2b8796ed19e2cfb281941be8d3)
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
