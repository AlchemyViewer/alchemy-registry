set(VCPKG_POLICY_EMPTY_INCLUDE_FOLDER enabled)

# The asset is named for the tag's first three components even when the tag
# carries a fourth, and it carries a CI run id that follows from nothing.
set(LSL_TAG "v${VERSION}")
string(REGEX MATCH "^[0-9]+[.][0-9]+[.][0-9]+" LSL_ASSET_VERSION "${VERSION}")
set(LSL_BUILD "34724367572")

vcpkg_download_distfile(
    LSL_ARCHIVE
    URLS "https://github.com/secondlife/lsl-definitions/releases/download/${LSL_TAG}/lsl_definitions-${LSL_ASSET_VERSION}-common-${LSL_BUILD}.tar.zst"
    FILENAME lsl-definitions.${VERSION}.tar.zst
    SHA512 8d8043ea0b5bd57c474b0a7445a39a16b32e3b4bbd8e0832611b4dc50ed0bf4b9a32b96e26dce118380d52b3336d58a5c3591b84fb509c1b9e8c51461a88afbd
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

# LL's generator, which writes the parts of their LSL compiler's lexer,
# grammar, tree and library table that follow from the definitions above.
file(INSTALL "${LSL_DIR}/lsl_definitions/python/gen_definitions.py"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/python")
file(INSTALL "${LSL_DIR}/lsl_definitions/python/lsl_definitions"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}/python"
     PATTERN "__pycache__" EXCLUDE)

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/unofficial-lsl-definitions-config.cmake"
     DESTINATION "${CURRENT_PACKAGES_DIR}/share/unofficial-lsl-definitions")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")

vcpkg_install_copyright(FILE_LIST "${LSL_DIR}/LICENSES/lsl_definitions.txt")
