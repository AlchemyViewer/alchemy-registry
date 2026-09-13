if(TARGET unofficial::sentry-cocoa::sentry)
    return()
endif()

get_filename_component(_sentry_cocoa_root "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)

# The framework bundle the packaging step embeds, and its separated symbols.
set(SENTRY_COCOA_FRAMEWORK_DIR "${_sentry_cocoa_root}/lib/SentryObjC.framework")
set(SENTRY_COCOA_FRAMEWORK_DSYM_DIR "${_sentry_cocoa_root}/lib/SentryObjC.framework.dSYM")

# The headers come from inside the bundle, so linking the framework by path is
# all a consumer needs: #import <SentryObjC/SentryObjC.h>, or @import SentryObjC
# where modules are on.
add_library(unofficial::sentry-cocoa::sentry INTERFACE IMPORTED)
set_property(TARGET unofficial::sentry-cocoa::sentry APPEND PROPERTY
    INTERFACE_LINK_LIBRARIES "${SENTRY_COCOA_FRAMEWORK_DIR}")

unset(_sentry_cocoa_root)
