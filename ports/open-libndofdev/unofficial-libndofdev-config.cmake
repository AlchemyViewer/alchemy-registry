if(TARGET unofficial::libndofdev::ndofdev)
    return()
endif()

get_filename_component(_ndof_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

set(_ndof_lib "${CMAKE_STATIC_LIBRARY_PREFIX}ndofdev${CMAKE_STATIC_LIBRARY_SUFFIX}")

add_library(unofficial::libndofdev::ndofdev STATIC IMPORTED)
set_target_properties(unofficial::libndofdev::ndofdev PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${_ndof_root}/include"
    IMPORTED_CONFIGURATIONS RELEASE
    IMPORTED_LOCATION_RELEASE "${_ndof_root}/lib/${_ndof_lib}")
if(EXISTS "${_ndof_root}/debug/lib/${_ndof_lib}")
    set_property(TARGET unofficial::libndofdev::ndofdev APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
    set_target_properties(unofficial::libndofdev::ndofdev PROPERTIES
        IMPORTED_LOCATION_DEBUG "${_ndof_root}/debug/lib/${_ndof_lib}")
endif()

# Only Debug takes the debug artifact; every other configuration is built
# against the release one.
set_target_properties(unofficial::libndofdev::ndofdev PROPERTIES
    MAP_IMPORTED_CONFIG_MINSIZEREL Release
    MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release)

# The Windows backend is DirectInput.
if(WIN32)
    set_property(TARGET unofficial::libndofdev::ndofdev APPEND PROPERTY
        INTERFACE_LINK_LIBRARIES dinput8)
endif()

unset(_ndof_lib)
unset(_ndof_root)
