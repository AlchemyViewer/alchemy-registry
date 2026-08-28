# BugSplat64.dll is a redistributable shipped beside the viewer; the .lib here
# is its import library.
set(VCPKG_POLICY_DLLS_IN_STATIC_LIBRARY enabled)
set(VCPKG_POLICY_DLLS_WITHOUT_EXPORTS enabled)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO secondlife/3p-bugsplat
    REF v1.2.6-a475cbb
    SHA512 408ff7160c7596e8e005b9e9e85f87b727fc5068c0a7966643ea157fdd7a3ef24a402f1757096ac9078016708281d8727c42e5b8ed067c0c9577a40f6dbce31a
    HEAD_REF main
)

file(INSTALL
    DIRECTORY "${SOURCE_PATH}/BugSplat/BugSplat/inc/"
    DESTINATION "${CURRENT_PACKAGES_DIR}/include/bugsplat"
    FILES_MATCHING
    PATTERN "*.h"
)

set(BUGSPLAT_CONFIGS "Release")
if(NOT VCPKG_BUILD_TYPE)
    list(APPEND BUGSPLAT_CONFIGS "Debug")
endif()

# The prebuilt tree holds the import library, the redistributable DLLs with the
# PDBs that symbolicate them, and the crash reporter executables side by side.
foreach(config IN LISTS BUGSPLAT_CONFIGS)
    if("${config}" STREQUAL "Debug")
        set(destination_prefix "debug/")
    else()
        set(destination_prefix "")
    endif()

    set(config_dir "${SOURCE_PATH}/BugSplat/BugSplat/x64/${config}")

    file(INSTALL
        DIRECTORY "${config_dir}/"
        DESTINATION "${CURRENT_PACKAGES_DIR}/${destination_prefix}lib"
        FILES_MATCHING
        PATTERN "*.lib"
    )

    file(INSTALL
        DIRECTORY "${config_dir}/"
        DESTINATION "${CURRENT_PACKAGES_DIR}/${destination_prefix}bin"
        FILES_MATCHING
        PATTERN "*.dll"
        PATTERN "*.pdb"
    )

    file(INSTALL
        DIRECTORY "${config_dir}/"
        DESTINATION "${CURRENT_PACKAGES_DIR}/${destination_prefix}tools"
        FILES_MATCHING
        PATTERN "*.exe"
    )
endforeach()

file(INSTALL "${SOURCE_PATH}/BugSplat/Tools/symbol-upload-windows.exe"
     DESTINATION "${CURRENT_PACKAGES_DIR}/tools")

# Symbol upload helpers, invoked by whatever drives a release build.
file(INSTALL
    "${SOURCE_PATH}/upload-windows-symbols.sh"
    "${SOURCE_PATH}/SendPdbs.bat"
    DESTINATION "${CURRENT_PACKAGES_DIR}/tools/upload-extensions")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-bugsplat-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-bugsplat")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/BugSplat/BUGSPLAT_LICENSE.txt")
