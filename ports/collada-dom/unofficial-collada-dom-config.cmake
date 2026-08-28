if(TARGET unofficial::collada-dom::collada14dom)
    return()
endif()

include(CMakeFindDependencyMacro)
find_dependency(LibXml2)
find_dependency(minizip CONFIG)
# daeUtils/dae/daeZAEUncompressHandler call into boost::filesystem.
find_dependency(Boost CONFIG COMPONENTS filesystem)

get_filename_component(_collada_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# The DOM headers are reached both as <dae.h> and as <dom/domFoo.h> under 1.4.
set(COLLADA_DOM_INCLUDE_DIR "${_collada_root}/include/collada-dom")

# UNKNOWN because the linkage follows the triplet; on Windows a dynamic build
# leaves the import library here and the DLL in bin/.
add_library(unofficial::collada-dom::collada14dom UNKNOWN IMPORTED)
set_target_properties(unofficial::collada-dom::collada14dom PROPERTIES
    INTERFACE_INCLUDE_DIRECTORIES "${COLLADA_DOM_INCLUDE_DIR};${COLLADA_DOM_INCLUDE_DIR}/1.4"
    INTERFACE_LINK_LIBRARIES "LibXml2::LibXml2;MINIZIP::minizip;Boost::filesystem"
    IMPORTED_CONFIGURATIONS RELEASE
    IMPORTED_LOCATION_RELEASE "${_collada_root}/lib/${CMAKE_STATIC_LIBRARY_PREFIX}collada14dom${CMAKE_STATIC_LIBRARY_SUFFIX}")

if(EXISTS "${_collada_root}/debug/lib/${CMAKE_STATIC_LIBRARY_PREFIX}collada14dom${CMAKE_STATIC_LIBRARY_SUFFIX}")
    set_property(TARGET unofficial::collada-dom::collada14dom APPEND PROPERTY IMPORTED_CONFIGURATIONS DEBUG)
    set_target_properties(unofficial::collada-dom::collada14dom PROPERTIES
        IMPORTED_LOCATION_DEBUG "${_collada_root}/debug/lib/${CMAKE_STATIC_LIBRARY_PREFIX}collada14dom${CMAKE_STATIC_LIBRARY_SUFFIX}")
endif()

# Only Debug takes the debug artifact; every other configuration is built
# against the release one.
set_target_properties(unofficial::collada-dom::collada14dom PROPERTIES
    MAP_IMPORTED_CONFIG_MINSIZEREL Release
    MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release)

unset(_collada_root)
