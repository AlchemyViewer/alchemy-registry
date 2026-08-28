set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

# The asset is named for the tag's first three components even when the tag
# carries a fourth, and it carries a CI run id that follows from nothing.
set(LSL_TAG "v${VERSION}")
string(REGEX MATCH "^[0-9]+[.][0-9]+[.][0-9]+" LSL_ASSET_VERSION "${VERSION}")
set(LSL_BUILD "32865298211")

vcpkg_download_distfile(
    LSL_ARCHIVE
    URLS "https://github.com/secondlife/lsl-definitions/releases/download/${LSL_TAG}/lsl_definitions-${LSL_ASSET_VERSION}-common-${LSL_BUILD}.tar.zst"
    FILENAME lsl-definitions.${VERSION}.tar.zst
    SHA512 d182602708ccd563c927d4eef30154a7c5a5857bb32c85cfbcc7f78486c40301b23fc1ea7e1560c1eea4ec0318b854a9a002c750a74b057fd18f84542da03ee8
)

vcpkg_extract_source_archive(LSL_DIR ARCHIVE "${LSL_ARCHIVE}" NO_REMOVE_ONE_LEVEL)

# Named rather than globbed so a new upstream file has to be adopted knowingly.
set(LSL_FILES
    builtins.txt
    lsl_definitions.yaml
    lsl_keywords.xml
    lua_keywords.xml
    secondlife.d.luau
    secondlife.docs.json
    secondlife_selene.yml
    slua_definitions.yaml
)

foreach(file IN LISTS LSL_FILES)
    file(INSTALL "${LSL_DIR}/lsl_definitions/${file}"
         DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/lsl_definitions")
endforeach()

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-lsl-definitions-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-lsl-definitions")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${LSL_DIR}/LICENSES/lsl_definitions.txt")
