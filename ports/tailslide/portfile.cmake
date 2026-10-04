vcpkg_check_linkage(ONLY_STATIC_LIBRARY)

vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO secondlife/tailslide
    REF "v${VERSION}"
    SHA512 c01d5d82dd4e89759a4cfecd07b01e72594152aa84461b5373c075233933c5c3214ca8c944327198975ba746084c15a1af2b0739c440aec5d3945822d62f6118
    HEAD_REF main
    PATCHES
        # The library installed with a CMake package of its own.
        build.patch
        # A definitions file with a line this version cannot read -- a type
        # it does not know, a malformed constant -- has that line skipped
        # with a word on stderr, rather than the host process ended: a
        # viewer reads the grid's own definitions, which may be newer. (A
        # host that must open a UTF-8 path on Windows reads the file itself
        # and hands it to tailslide_init_builtins_from_data().)
        builtins-skip-unreadable.patch
        # The parser's depth limit is 10000 on Windows as elsewhere, not
        # 1000, its stacks grown on the heap rather than sized for that depth
        # in yyparse()'s frame: a list literal costs two states an element,
        # so a list of 500 parsed everywhere but Windows.
        parser-stack-depth.patch
        # Two vectors' dot product is each part by the same part of the
        # other, not x by the other's z, and the cross product rounds each
        # product as the VM does rather than letting the compiler fuse it
        # into the difference: <1,3,-5> * <4,-2,-1> folded to -27, not 3,
        # and a vector crossed with itself was not zero.
        vector-products.patch
        # A bit stream moved to its end with room to be made grew a byte past
        # it, which stayed where nothing was written after: an LSO image whose
        # last global is left all zeros was a byte longer than LL's compiler
        # makes it, and everything after the globals a byte late.
        bitstream-move-to-end.patch
        # Mono's constants as LL's compiler writes them, which the grid keeps
        # as written: an integer the script wrote by ldc.i4 alone, not its
        # short forms (those only for a default and the one ++ adds, as LL
        # writes them), and a minus before a number in a global's
        # initializer one constant, as LL's grammar reads it there.
        mono-constants-as-ll.patch
)

# Tailslide checks in a scanner and a parser generated from libtailslide/
# lslmini.l and lslmini.y, but from the grammar as it is: ours, under
# generated/, are made from the grammar with parser-stack-depth.patch applied,
# and take their place, generation skipped so that the build needs neither
# flex nor bison (Apple's bison is too old for the grammar, and the Windows
# runner has neither). Made in libtailslide/ at this version with GNU flex
# 2.6.4 (Homebrew; Apple's flex of the same name emits the older yy_size_t
# length) and bison 3.8.2, without #line directives so that they carry no
# path:
#
#     bison -l -o lslmini.tab.cc --defines=lslmini.tab.hh lslmini.y
#     flex -L -o lslmini.flex.cc lslmini.l
#
# Regenerate them whenever the version, or a patch to either file, changes.
file(COPY "${CMAKE_CURRENT_LIST_DIR}/generated/" DESTINATION "${SOURCE_PATH}/libtailslide")
vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DTAILSLIDE_BUILD_CLI=OFF
        -DTAILSLIDE_BUILD_TESTS=OFF
        -DTAILSLIDE_SKIP_GEN=ON
)
vcpkg_cmake_install()
vcpkg_cmake_config_fixup(PACKAGE_NAME unofficial-tailslide)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include" "${CURRENT_PACKAGES_DIR}/debug/share")

file(INSTALL "${CMAKE_CURRENT_LIST_DIR}/usage" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}")
vcpkg_install_copyright(FILE_LIST "${SOURCE_PATH}/LICENSE" "${SOURCE_PATH}/NOTICE.txt")
