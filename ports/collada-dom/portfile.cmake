vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO RyeMutt/3p-colladadom
    REF b8da6cd54083bf24dff3ac03be465e710c135195
    SHA512 bb5e6c09777d0dfd0093ff99f4114873bec7c0094e4ec15594d188c0a2bf44a0fffbcf91dfa3c4f73a924f32e6fe3eb0cf1cbe4053a6bb40979e9c2962f649b1
    HEAD_REF master
    # Upstream finds minizip through pkg-config, hence the pkgconf dependency.
    # use-vcpkg-minizip.patch switches that to find_package instead; it is kept
    # for when pkg-config is no longer wanted, and is not applied today.
)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DCMAKE_CXX_STANDARD=17
)

vcpkg_cmake_install()

# Upstream drops the DLL in lib/ next to its import library.
if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic" AND VCPKG_TARGET_IS_WINDOWS)
    foreach(prefix "" "debug/")
        if(EXISTS "${CURRENT_PACKAGES_DIR}/${prefix}lib/collada14dom.dll")
            file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/${prefix}bin")
            file(RENAME "${CURRENT_PACKAGES_DIR}/${prefix}lib/collada14dom.dll"
                        "${CURRENT_PACKAGES_DIR}/${prefix}bin/collada14dom.dll")
        endif()
    endforeach()
endif()

# Static Apple and Linux builds leave the archive behind in the build tree.
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static" AND (VCPKG_TARGET_IS_OSX OR VCPKG_TARGET_IS_LINUX))
    if(EXISTS "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/src/1.4/libcollada14dom.a")
        file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/src/1.4/libcollada14dom.a"
             DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
    endif()
    if(EXISTS "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg/src/1.4/libcollada14dom.a")
        file(INSTALL "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-dbg/src/1.4/libcollada14dom.a"
             DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
    endif()
endif()

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-collada-dom-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-collada-dom")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/license.txt")
