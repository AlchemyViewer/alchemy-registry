if(TARGET unofficial::velopack::velopack)
    return()
endif()

get_filename_component(_velopack_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

if(WIN32)
    add_library(unofficial::velopack::velopack SHARED IMPORTED)
    set_target_properties(unofficial::velopack::velopack PROPERTIES
        IMPORTED_LOCATION_RELEASE "${_velopack_root}/bin/velopack_libc.dll"
        IMPORTED_IMPLIB_RELEASE "${_velopack_root}/lib/velopack_libc.dll.lib")
else()
    add_library(unofficial::velopack::velopack STATIC IMPORTED)
    set_target_properties(unofficial::velopack::velopack PROPERTIES
        IMPORTED_LOCATION_RELEASE "${_velopack_root}/lib/libvelopack_libc.a")
endif()

set_target_properties(unofficial::velopack::velopack PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${_velopack_root}/include/velopack"
    IMPORTED_CONFIGURATIONS RELEASE)

# The crate is built release-only, so every configuration takes the same binary.
set_target_properties(unofficial::velopack::velopack PROPERTIES
    MAP_IMPORTED_CONFIG_DEBUG Release
    MAP_IMPORTED_CONFIG_MINSIZEREL Release
    MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release)

# System libraries the rust runtime pulls in, which a static link has to satisfy.
if(WIN32)
    set_property(TARGET unofficial::velopack::velopack APPEND PROPERTY
        INTERFACE_LINK_LIBRARIES
            winhttp ole32 shell32 shlwapi version userenv ws2_32 bcrypt ntdll)
elseif(APPLE)
    set_property(TARGET unofficial::velopack::velopack APPEND PROPERTY
        INTERFACE_LINK_LIBRARIES
            "-framework Foundation"
            "-framework Security"
            "-framework SystemConfiguration"
            "-framework AppKit"
            "-framework CoreFoundation"
            "-framework CoreServices"
            "-framework IOKit"
            "-liconv"
            "-lresolv")
endif()

unset(_velopack_root)
