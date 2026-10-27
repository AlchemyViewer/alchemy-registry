string(REGEX REPLACE "^([0-9]+)[.]([0-9]+)[.]([0-9]+)[.]([0-9]+)" "\\1,0\\2,0\\3,0\\4," SQLITE_VERSION "${VERSION}.0")
string(REGEX REPLACE "^([0-9]+),0*([0-9][0-9]),0*([0-9][0-9]),0*([0-9][0-9])," "\\1\\2\\3\\4" SQLITE_VERSION "${SQLITE_VERSION}")

vcpkg_download_distfile(ARCHIVE
    URLS "https://sqlite.org/2026/sqlite-autoconf-${SQLITE_VERSION}.tar.gz"
    FILENAME "sqlite-autoconf-${SQLITE_VERSION}.tar.gz"
    SHA512 3df4348f54f5cd0554eec6d91e1d08a70535b7b78f497b2c6f24910b5087f6ef70483c9e35fa388bd8f38483cb8d1cb84e98ccdd58b9f525a10e0cf48c8c6742
)

vcpkg_extract_source_archive(
    SOURCE_PATH
    ARCHIVE "${ARCHIVE}"
    PATCHES
        fix-arm-uwp.patch
        add-config-include.patch
)

# The recover API (ext/recover) is not part of the amalgamation the autoconf
# tarball carries, so its three files come from the source tree at the same
# release and are compiled into the library beside sqlite3.c.
set(SQLITE_RECOVER_SHA512_sqlite3recover.c 636f2e96d72ef641c63e552bb1d312b298b7a16db2e2092c389ee1debd630f8601f15362900b5935a1cc0601e4ad963a5a6f14b2f57e4d3c9400168cb089379b)
set(SQLITE_RECOVER_SHA512_sqlite3recover.h f14a11081c8da7a842b6cfb29b285450e5c9a6e46a80f6f6bfa99b5715c29eae8533fba669c0d32f5067243744286ff65ed7e3618b708c78afc4645807368380)
set(SQLITE_RECOVER_SHA512_dbdata.c f3688a2e74fa36974a8814120c2602c8c30ac0869529631f79b75aac746b0b020ebea4c9bcd9d071b22c9140fe5fa28348d4a3baae644e313d9ecaab58b50191)
foreach(recover_file IN ITEMS sqlite3recover.c sqlite3recover.h dbdata.c)
    vcpkg_download_distfile(recover_path
        URLS "https://raw.githubusercontent.com/sqlite/sqlite/version-${VERSION}/ext/recover/${recover_file}"
        FILENAME "sqlite-recover-${VERSION}-${recover_file}"
        SHA512 ${SQLITE_RECOVER_SHA512_${recover_file}}
    )
    file(READ "${recover_path}" recover_source)
    # sqlite_dbdata's entry point is exported for the shell's loadable
    # extension build. Compiled into a static library it would make whatever
    # links it export the symbol and emit an import library.
    string(REPLACE "__declspec(dllexport)" "" recover_source "${recover_source}")
    file(WRITE "${SOURCE_PATH}/${recover_file}" "${recover_source}")
endforeach()

if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
    if(VCPKG_TARGET_IS_WINDOWS)
        set(SQLITE_API "__declspec(dllimport)")
    else()
        set(SQLITE_API "__attribute__((visibility(\"default\")))")
    endif()
else()
    set(SQLITE_API "")
endif()

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        fts5                SQLITE_ENABLE_FTS5
        math                SQLITE_ENABLE_MATH_FUNCTIONS
        zlib                WITH_ZLIB
        unicode             SQLITE_ENABLE_ICU
    INVERTED_FEATURES
        tool                SQLITE3_SKIP_TOOLS
)
vcpkg_check_features(OUT_FEATURE_OPTIONS none # only using the script-mode side-effects
    FEATURES
        dbstat              SQLITE_ENABLE_DBSTAT_VTAB
        dbpage-vtab         SQLITE_ENABLE_DBPAGE_VTAB
        fts3                SQLITE_ENABLE_FTS3
        fts4                SQLITE_ENABLE_FTS4
        memsys3             SQLITE_ENABLE_MEMSYS3
        memsys5             SQLITE_ENABLE_MEMSYS5
        limit               SQLITE_ENABLE_UPDATE_DELETE_LIMIT
        rtree               SQLITE_ENABLE_RTREE
        session             SQLITE_ENABLE_SESSION
        session             SQLITE_ENABLE_PREUPDATE_HOOK
        snapshot            SQLITE_ENABLE_SNAPSHOT
        omit-load-extension SQLITE_OMIT_LOAD_EXTENSION
        geopoly             SQLITE_ENABLE_GEOPOLY
        soundex             SQLITE_SOUNDEX
        percentile          SQLITE_ENABLE_PERCENTILE
    INVERTED_FEATURES
        json1               SQLITE_OMIT_JSON
)

if(VCPKG_TARGET_IS_WINDOWS)
    set(SQLITE_OS_WIN "1")
    if(VCPKG_TARGET_IS_UWP)
        set(SQLITE_OS_WINRT "1")
    endif()
else()
    set(SQLITE_OS_UNIX "1")
endif()

file(COPY "${CMAKE_CURRENT_LIST_DIR}/CMakeLists.txt" DESTINATION "${SOURCE_PATH}")
file(COPY "${CMAKE_CURRENT_LIST_DIR}/sqlite3.pc.in" DESTINATION "${SOURCE_PATH}")
configure_file("${CMAKE_CURRENT_LIST_DIR}/sqlite3-vcpkg-config.h.in" "${SOURCE_PATH}/sqlite3-vcpkg-config.h" @ONLY)

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        ${FEATURE_OPTIONS}
        -DPKGCONFIG_VERSION=${VERSION}
    OPTIONS_DEBUG
        -DSQLITE3_SKIP_TOOLS=ON
    MAYBE_UNUSED_VARIABLES
        SQLITE_ENABLE_FTS5
        SQLITE_ENABLE_MATH_FUNCTIONS
)

vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME unofficial-${PORT} CONFIG_PATH share/unofficial-${PORT})

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/share")

if("tool" IN_LIST FEATURES)
    vcpkg_copy_tools(TOOL_NAMES sqlite3 DESTINATION "${CURRENT_PACKAGES_DIR}/tools" AUTO_CLEAN)
endif()

configure_file(
    "${CMAKE_CURRENT_LIST_DIR}/sqlite3-config.in.cmake"
    "${CURRENT_PACKAGES_DIR}/share/unofficial-${PORT}/unofficial-sqlite3-config.cmake"
    @ONLY
)
if(VCPKG_LIBRARY_LINKAGE STREQUAL "static")
    configure_file("${CURRENT_PORT_DIR}/vcpkg-cmake-wrapper.cmake" "${CURRENT_PACKAGES_DIR}/share/${PORT}/vcpkg-cmake-wrapper.cmake" @ONLY)
endif()

vcpkg_fixup_pkgconfig()
vcpkg_copy_pdbs()

file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/copyright" "SQLite is in the Public Domain.\nhttp://www.sqlite.org/copyright.html\n")
file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
