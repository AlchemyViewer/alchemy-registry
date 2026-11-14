vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO wolfpld/tracy
    REF "v${VERSION}"
    SHA512 a274fbb62ec25ab9b6025eeeb6e0458ba282fe61509dcd0daf824bdbcf3215c25eb992271d33cc88544068f83e00d791833e980eed7c8f4a1cd3ef71841cf38e
    HEAD_REF master
    PATCHES
        build-tools.patch
        fix-vendor-versions.patch
        fix-imgui-patch.patch
        downgrade-capstone-5.patch # tracy wants capstone-6-alpha but vcpkg ships the most recent production capstone, 5.0.6 as of 2026-02-04
        downgrade-libcurl-7.patch # CURLOPT_CA_CACHE_TIMEOUT is 7.87.0; the viewer's overlay curl port is older
        calibrate-timer-on-connect.patch # the timer's 200 ms calibration is done when a server first connects, not as every process that links tracy starts
)

vcpkg_check_features(OUT_FEATURE_OPTIONS FEATURE_OPTIONS
    FEATURES
        ipv4-only    TRACY_ONLY_IPV4
        localhost    TRACY_ONLY_LOCALHOST
        no-broadcast TRACY_NO_BROADCAST
        on-demand    TRACY_ON_DEMAND
        fibers       TRACY_FIBERS
        verbose      TRACY_VERBOSE
    INVERTED_FEATURES
        crash-handler TRACY_NO_CRASH_HANDLER
)

vcpkg_check_features(OUT_FEATURE_OPTIONS TOOLS_OPTIONS
    FEATURES
        cli-tools VCPKG_CLI_TOOLS
        gui-tools VCPKG_GUI_TOOLS
)

if ("gui-tools" IN_LIST FEATURES)
   vcpkg_from_github(
       OUT_SOURCE_PATH tracy_imgui_path
       REPO ocornut/imgui
       REF "v1.93.0-docking"
       SHA512 00ade7a3e2c2e34465f1bb9fafd78733d3e659617b0857cf1b3c7f04cfc1d8566d1fd6a8697946f0de7c808cce1c4d0a4b2195c7bc20144cfd8b1e9b1cfba621
       PATCHES
           "${SOURCE_PATH}/cmake/imgui-emscripten.patch"
           "${SOURCE_PATH}/cmake/imgui-loader.patch"
           "${SOURCE_PATH}/cmake/imgui-no-samplers.patch"
           "${SOURCE_PATH}/cmake/imgui-no-default-font.patch"
           "${SOURCE_PATH}/cmake/imgui-macos-clipboard.patch"
           "${SOURCE_PATH}/cmake/imgui-phantom-column.patch"
   )
   list(APPEND TOOLS_OPTIONS "-DImGui_SOURCE_DIR=${tracy_imgui_path}")

   # The profiler renders its built-in manual with pandoc and Python
   # (cmake/manual.cmake). With no pandoc of the pinned version on PATH, its
   # configure downloads one into the user's cache, past vcpkg's downloads and
   # asset cache, so fetch that same release here and hand it over as the cache
   # it looks in. A host this picks wrongly for still downloads, as before.
   vcpkg_find_acquire_program(PYTHON3)
   list(APPEND TOOLS_OPTIONS "-DPython3_EXECUTABLE=${PYTHON3}")

   set(tracy_pandoc_version 3.12.1)
   if(VCPKG_HOST_IS_WINDOWS)
       set(tracy_pandoc_asset "pandoc-${tracy_pandoc_version}-windows-x86_64.zip")
       set(tracy_pandoc_sha512 7a81ebeada6df48010a40f572e9dd1e6feb7570588c44a4ddecc377738203aa4fe8fa673be97d3feeb61c143b7bb1f71dcfd23828404954c11342874851b029a)
   elseif(VCPKG_HOST_IS_OSX AND HOST_TRIPLET MATCHES "^arm64-")
       set(tracy_pandoc_asset "pandoc-${tracy_pandoc_version}-arm64-macOS.zip")
       set(tracy_pandoc_sha512 a5a33fdf60e8d7e1b388f4e5db451fc5726611bac899ed3d32d7c57940ef8bc36d792f345f44fd44f015a5689daf5b23ccf0e30dd3e121eaedae1b6a7af9e2f5)
   elseif(VCPKG_HOST_IS_OSX)
       set(tracy_pandoc_asset "pandoc-${tracy_pandoc_version}-x86_64-macOS.zip")
       set(tracy_pandoc_sha512 fe1c0a14f827c07bd2bea91e5d7fac33c89708088fab6e8471625b9da1c3618c8a76d464d7ac2d0475575053964e66ce4f2e778856568a3f3b9d65bf44af7b7a)
   elseif(HOST_TRIPLET MATCHES "^arm64-")
       set(tracy_pandoc_asset "pandoc-${tracy_pandoc_version}-linux-arm64.tar.gz")
       set(tracy_pandoc_sha512 1a0c12ec4e82143d1a11e3af3465a6b24a9e6c373e3e58e29fd36a81ff45f97edd64c34366c9b01bcf49cd2f6e53b618e0df78f6bf30696f96a674d1c9edea31)
   else()
       set(tracy_pandoc_asset "pandoc-${tracy_pandoc_version}-linux-amd64.tar.gz")
       set(tracy_pandoc_sha512 543e16bbfa6feadb3d768efb8bbd06dd58b0ebff24000d2019f8fa7a5af33e992806c435f6a18ccd2149341df18f598a8055d195d213e74914401a4549b01184)
   endif()
   vcpkg_download_distfile(tracy_pandoc_archive
       URLS "https://github.com/jgm/pandoc/releases/download/${tracy_pandoc_version}/${tracy_pandoc_asset}"
       FILENAME "${tracy_pandoc_asset}"
       SHA512 ${tracy_pandoc_sha512}
   )
   vcpkg_extract_source_archive(tracy_pandoc_dir
       ARCHIVE "${tracy_pandoc_archive}"
       NO_REMOVE_ONE_LEVEL
   )
   set(ENV{PANDOC_CACHE_DIR} "${tracy_pandoc_dir}")
endif()

if("cli-tools" IN_LIST FEATURES OR "gui-tools" IN_LIST FEATURES)
    vcpkg_find_acquire_program(PKGCONFIG)
    list(APPEND TOOLS_OPTIONS "-DPKG_CONFIG_EXECUTABLE=${PKGCONFIG}")
endif()

vcpkg_cmake_configure(
    SOURCE_PATH ${SOURCE_PATH}
    OPTIONS
        -DDOWNLOAD_CAPSTONE=OFF
        -DLEGACY=ON
        -DTRACY_ENABLE=ON
        -DCMAKE_FIND_PACKAGE_TARGETS_GLOBAL=ON
        -DCMAKE_DISABLE_FIND_PACKAGE_Git=ON
        ${FEATURE_OPTIONS}
    OPTIONS_RELEASE
        ${TOOLS_OPTIONS}
    MAYBE_UNUSED_VARIABLES
        DOWNLOAD_CAPSTONE
        LEGACY
        CMAKE_DISABLE_FIND_PACKAGE_Git
        ImGui_SOURCE_DIR
)
vcpkg_cmake_install()
vcpkg_copy_pdbs()
vcpkg_cmake_config_fixup(PACKAGE_NAME Tracy CONFIG_PATH "lib/cmake/Tracy")

function(tracy_copy_tool tool_name tool_dir)
    vcpkg_copy_tools(
        TOOL_NAMES "${tool_name}"
        SEARCH_DIR "${CURRENT_BUILDTREES_DIR}/${TARGET_TRIPLET}-rel/${tool_dir}"
    )
endfunction()

set(TOOLS)
if("cli-tools" IN_LIST FEATURES)
    list(APPEND TOOLS tracy-capture tracy-capture-daemon tracy-csvexport tracy-update)
    tracy_copy_tool(tracy-import-chrome import)
    tracy_copy_tool(tracy-import-fuchsia import)
endif()
if("gui-tools" IN_LIST FEATURES)
    list(APPEND TOOLS tracy-profiler)
endif()

if(TOOLS)
    vcpkg_copy_tools(TOOL_NAMES ${TOOLS} AUTO_CLEAN)
endif()
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE")
file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
