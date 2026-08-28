# Runs one libgrapheme table generator, capturing its stdout into a header.
# add_custom_command has no output redirection, so the generator is driven
# through cmake -P instead.
execute_process(
    COMMAND "${GENERATOR}"
    OUTPUT_FILE "${OUTPUT}"
    WORKING_DIRECTORY "${WORKDIR}"
    RESULT_VARIABLE generator_result
    ERROR_VARIABLE generator_error
)

if(NOT generator_result EQUAL 0)
    file(REMOVE "${OUTPUT}")
    message(FATAL_ERROR "${GENERATOR} failed (${generator_result}): ${generator_error}")
endif()
