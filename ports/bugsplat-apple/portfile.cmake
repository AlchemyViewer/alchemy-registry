set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)
set(VCPKG_FIXUP_MACHO_RPATH OFF)

# The framework itself comes from BugSplat upstream; 3p-bugsplat is fetched only
# for the symbol upload helpers.
vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO secondlife/3p-bugsplat
    REF v1.2.6-a475cbb
    SHA512 408ff7160c7596e8e005b9e9e85f87b727fc5068c0a7966643ea157fdd7a3ef24a402f1757096ac9078016708281d8727c42e5b8ed067c0c9577a40f6dbce31a
    HEAD_REF main
)

vcpkg_download_distfile(
    BUGSPLAT_ARCHIVE
    URLS "https://github.com/BugSplat-Git/bugsplat-apple/releases/download/${VERSION}/BugSplat.xcframework.zip"
    FILENAME "bugsplat-apple.${VERSION}.BugSplat.xcframework.zip"
    SHA512 018e0e564a67372e1bfddf1b22885e3f8b155bed6ddfb7ea87a578f312309c79203d5c7728849a7cf0393be3d3e7546a1f9588540c1b726253e9d2364bc5de93
)

vcpkg_extract_source_archive(
    BUGSPLAT_DIR
    ARCHIVE "${BUGSPLAT_ARCHIVE}"
    NO_REMOVE_ONE_LEVEL
)

set(BUGSPLAT_SLICE "${BUGSPLAT_DIR}/BugSplat.xcframework/macos-arm64_x86_64")

file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/lib")

# cp -a rather than file(COPY): a macOS framework is a versioned bundle whose
# top-level entries are symlinks into Versions/Current, and CMake would follow
# them and flatten the bundle.
vcpkg_execute_required_process(
    COMMAND cp -a "${BUGSPLAT_SLICE}/BugSplat.framework" "${CURRENT_PACKAGES_DIR}/lib/BugSplat.framework"
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
    LOGNAME "copy-framework-${TARGET_TRIPLET}"
)

vcpkg_execute_required_process(
    COMMAND cp -a "${BUGSPLAT_SLICE}/dSYMs/BugSplat.framework.dSYM" "${CURRENT_PACKAGES_DIR}/lib/BugSplat.framework.dSYM"
    WORKING_DIRECTORY "${CURRENT_BUILDTREES_DIR}"
    LOGNAME "copy-dsym-${TARGET_TRIPLET}"
)

# Symbol upload helpers, invoked by whatever drives a release build.
file(INSTALL
    "${SOURCE_PATH}/upload-archive.sh"
    "${SOURCE_PATH}/upload-mac-symbols.sh"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/upload-extensions")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-bugsplat-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-bugsplat")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/BugSplat/BUGSPLAT_LICENSE.txt")
