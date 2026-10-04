get_filename_component(_lsl_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# Data only, no library: the definitions are read at build time and staged into
# app_settings/syntax_default by the packaging step.
set(LSL_DEFINITIONS_DIR "${_lsl_root}/share/lsl-definitions/lsl_definitions")
# LL's generator, run as: python3 gen_definitions.py <lsl_definitions.yaml>
# <command> ... It needs PyYAML and llsd.
set(LSL_DEFINITIONS_GENERATOR "${_lsl_root}/share/lsl-definitions/python/gen_definitions.py")

unset(_lsl_root)
