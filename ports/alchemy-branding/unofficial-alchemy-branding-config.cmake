get_filename_component(_branding_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# Data only, no library: artwork staged by the build and the packaging step.
set(ALCHEMY_BRANDING_DIR "${_branding_root}/share/alchemy-branding")
set(ALCHEMY_BRANDING_VIEWER_DIR "${ALCHEMY_BRANDING_DIR}/viewer")
set(ALCHEMY_BRANDING_INSTALLER_DIR "${ALCHEMY_BRANDING_DIR}/installer")

unset(_branding_root)
