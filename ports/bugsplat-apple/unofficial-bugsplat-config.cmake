if(TARGET unofficial::bugsplat::bugsplat)
    return()
endif()

get_filename_component(_bugsplat_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# The framework bundle the packaging step embeds, and its separated symbols.
set(BUGSPLAT_FRAMEWORK_DIR "${_bugsplat_root}/lib/BugSplat.framework")
set(BUGSPLAT_FRAMEWORK_DSYM_DIR "${_bugsplat_root}/lib/BugSplat.framework.dSYM")
set(BUGSPLAT_TOOLS_DIR "${_bugsplat_root}/tools")

# The headers come from inside the bundle, so linking the framework by path is
# all a consumer needs.
add_library(unofficial::bugsplat::bugsplat INTERFACE IMPORTED)
set_property(TARGET unofficial::bugsplat::bugsplat APPEND PROPERTY
    INTERFACE_LINK_LIBRARIES "${BUGSPLAT_FRAMEWORK_DIR}")

unset(_bugsplat_root)
