# libvlc really is a shared library here; the .lib files beside it are import libs.
set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
set(VCPKG_POLICY_ALLOW_OBSOLETE_MSVCRT enabled)
set(VCPKG_POLICY_MISMATCHED_NUMBER_OF_BINARIES enabled)
set(VCPKG_FIXUP_MACHO_RPATH OFF)

vcpkg_from_github(
    OUT_SOURCE_PATH VLC_BIN_SOURCE
    REPO AlchemyViewer/vlc-bin
    REF c4c983e743ba5fe3194ea7365671f748ab614618
    SHA512 4a95884bf5140f9d375a7a92b83b7f9e38824b969298dc3a3b50b0c4be00cf9685fb95a07c395e4d41606b43f102caab5063ab99ae42250b2cb7c3d155a18b44
    HEAD_REF main
)

if(VCPKG_TARGET_IS_WINDOWS)
    if(VCPKG_TARGET_ARCHITECTURE MATCHES "arm64")
        set(VLC_DIR "${VLC_BIN_SOURCE}/vlc-winarm64")
    else()
        set(VLC_DIR "${VLC_BIN_SOURCE}/vlc-win64")
    endif()
elseif(VCPKG_TARGET_IS_OSX)
    if(VCPKG_OSX_ARCHITECTURES MATCHES "arm64")
        set(VLC_DIR "${VLC_BIN_SOURCE}/vlc-macos-arm64")
    else()
        set(VLC_DIR "${VLC_BIN_SOURCE}/vlc-macos-intel64")
    endif()
else()
    # Linux takes libvlc from the distribution via pkg-config instead.
    message(FATAL_ERROR "vlc-bin carries no prebuilt VLC for ${TARGET_TRIPLET}.")
endif()

file(INSTALL
    DIRECTORY "${VLC_DIR}/include/vlc/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include/vlc"
    FILES_MATCHING
    PATTERN "*.h"
)

file(INSTALL
    DIRECTORY "${VLC_DIR}/lib/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/lib"
    FILES_MATCHING
    PATTERN "*.dylib"
    PATTERN "*.lib"
)

# The codec plugins are loaded at runtime from a directory VLC is pointed at, so
# they are staged beside the media plugin rather than linked.
file(INSTALL
    DIRECTORY "${VLC_DIR}/plugins/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/plugins/${PORT}"
    FILES_MATCHING
    PATTERN "*.dll"
    PATTERN "*.so"
    PATTERN "*.dylib"
    PATTERN "*.dat"
)

if(VCPKG_TARGET_IS_WINDOWS)
    file(INSTALL
        DIRECTORY "${VLC_DIR}/bin/"
        DESTINATION "${CURRENT_PACKAGES_DIR}/bin"
        FILES_MATCHING
        PATTERN "*.dll"
    )
endif()

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-libvlc-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-libvlc")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${VLC_BIN_SOURCE}/LICENSE")
