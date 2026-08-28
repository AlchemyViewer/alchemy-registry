if(TARGET unofficial::bugsplat::bugsplat)
    return()
endif()

get_filename_component(_bugsplat_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# BsSndRpt64.exe and the symbol upload helpers, which the packaging step ships.
set(BUGSPLAT_TOOLS_DIR "${_bugsplat_root}/tools")

# Headers are reached as <bugsplat/BugSplat.h>, so the include root goes on the
# interface rather than the bugsplat/ subdirectory.
add_library(unofficial::bugsplat::bugsplat SHARED IMPORTED)
set_target_properties(unofficial::bugsplat::bugsplat PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${_bugsplat_root}/include"
    IMPORTED_CONFIGURATIONS RELEASE
    IMPORTED_LOCATION_RELEASE "${_bugsplat_root}/bin/BugSplat64.dll"
    IMPORTED_IMPLIB_RELEASE "${_bugsplat_root}/lib/BugSplat64.lib")

# Only the release redistributable is ever staged beside the viewer, so every
# configuration links against it.
set_target_properties(unofficial::bugsplat::bugsplat PROPERTIES
    MAP_IMPORTED_CONFIG_DEBUG Release
    MAP_IMPORTED_CONFIG_MINSIZEREL Release
    MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release)

unset(_bugsplat_root)
