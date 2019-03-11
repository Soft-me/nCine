target_compile_features(ncine PUBLIC cxx_std_11)
set_target_properties(ncine PROPERTIES CXX_EXTENSIONS OFF)

target_compile_definitions(ncine PRIVATE "$<$<CONFIG:Debug>:NCINE_DEBUG>")

if(MSVC)
	# Build with Multiple Processes
	target_compile_options(ncine PRIVATE /MP)
	# Always use the non debug version of the runtime library
	target_compile_options(ncine PUBLIC /MD)
	# Extra optimizations in release
	target_compile_options(ncine PRIVATE $<$<CONFIG:Release>:/fp:fast /Ox /Qpar>)

	# Enabling Whole Program Optimization
	if(NCINE_LINKTIME_OPTIMIZATION)
		target_compile_options(ncine PRIVATE $<$<CONFIG:Release>:/GL>)
		target_link_options(ncine PRIVATE $<$<CONFIG:Release>:/LTCG>)
	endif()

	if(NCINE_AUTOVECTORIZATION_REPORT)
		target_compile_options(ncine PRIVATE $<$<CONFIG:Release>:/Qvec-report:2 /Qpar-report:2>)
	endif()

	target_compile_definitions(ncine PRIVATE "_CRT_SECURE_NO_DEPRECATE")
	# Suppress linker warning about templates
	target_compile_options(ncine PUBLIC "/wd4251")

	# Disabling incremental linking and manifest generation
	target_link_options(ncine PRIVATE $<$<CONFIG:Debug>:/MANIFEST:NO /INCREMENTAL:NO>)
	target_link_options(ncine PRIVATE $<$<CONFIG:RelWithDebInfo>:/MANIFEST:NO /INCREMENTAL:NO>)

	if(NCINE_WITH_TRACY)
		target_link_options(ncine PRIVATE $<$<CONFIG:Release>:/DEBUG>)
	endif()
else() # GCC and LLVM
	target_compile_options(ncine PRIVATE $<$<CONFIG:Release>:-ffast-math>)

	if(NCINE_DYNAMIC_LIBRARY)
		target_compile_options(ncine PRIVATE -fvisibility=hidden -fvisibility-inlines-hidden)
	endif()

	# Only in debug
	if(("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU" AND NOT (CMAKE_CXX_COMPILER_VERSION VERSION_LESS 4.8.0)) OR
	  (("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang" OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "AppleClang") AND NOT (CMAKE_CXX_COMPILER_VERSION VERSION_LESS 3.0)) AND
	   NCINE_ADDRESS_SANITIZER)
		target_compile_options(ncine PRIVATE $<$<CONFIG:Debug>:-O1 -ggdb -fsanitize=address -fsanitize-address-use-after-scope -fno-optimize-sibling-calls -fno-common -fno-omit-frame-pointer -rdynamic>)
		target_link_options(ncine PRIVATE $<$<CONFIG:Debug>:-fsanitize=address>)
	endif()

	# Interface library pseudo target for unit tests
	add_library(enable_coverage INTERFACE)

	# Only in debug
	if(("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU" OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang" OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "AppleClang") AND
	   NCINE_CODE_COVERAGE)
		target_compile_options(ncine PRIVATE $<$<CONFIG:Debug>:--coverage>)
		target_link_options(ncine PRIVATE $<$<CONFIG:Debug>:--coverage>)

		# Add code coverage options to the interface library for unit tests
		target_compile_options(enable_coverage INTERFACE $<$<CONFIG:Debug>:--coverage>)
		target_link_options(enable_coverage INTERFACE $<$<CONFIG:Debug>:--coverage>)
	endif()

	if(NCINE_WITH_TRACY)
		target_compile_options(ncine PRIVATE $<$<CONFIG:Release>:-ggdb>)
		if(NOT "${CMAKE_SYSTEM_NAME}" STREQUAL "Android" AND NOT APPLE)
			target_link_libraries(ncine PRIVATE dl)
		endif()
	endif()

	if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
		target_compile_options(ncine PRIVATE -fdiagnostics-color=auto)
		target_compile_options(ncine PRIVATE -Wall -pedantic -Wextra -Wold-style-cast -Wno-long-long -Wno-unused-parameter -Wno-ignored-qualifiers -Wno-variadic-macros)

		if(NCINE_DYNAMIC_LIBRARY)
			target_link_options(ncine PRIVATE -Wl,--no-undefined)
		endif()

		target_compile_options(ncine PRIVATE $<$<CONFIG:Debug>:-fvar-tracking-assignments>)

		# Extra optimizations in release
		target_compile_options(ncine PRIVATE $<$<CONFIG:Release>:-Ofast -funsafe-loop-optimizations -ftree-loop-if-convert-stores>)

		if(NCINE_LINKTIME_OPTIMIZATION AND NOT (MINGW OR MSYS OR "${CMAKE_SYSTEM_NAME}" STREQUAL "Android"))
			target_compile_options(ncine PRIVATE $<$<CONFIG:Release>:-flto=${NCINE_CORES}>)
			target_link_options(ncine PRIVATE $<$<CONFIG:Release>:-flto=${NCINE_CORES}>)
		endif()

		if(NCINE_AUTOVECTORIZATION_REPORT)
			target_compile_options(ncine PRIVATE $<$<CONFIG:Release>:-fopt-info-vec-optimized>)
		endif()

		# Enabling strong stack protector of GCC 4.9
		if(NCINE_GCC_HARDENING AND NOT (MINGW OR MSYS))
			target_compile_options(ncine PRIVATE $<$<CONFIG:Release>:-Wformat-security -fstack-protector-strong>)
			target_compile_definitions(ncine PRIVATE "$<$<CONFIG:Release>:_FORTIFY_SOURCE=2>")
			target_link_options(ncine PRIVATE $<$<CONFIG:Release>:-Wl,-z,relro -Wl,-z,now>)
		endif()
	elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang" OR "${CMAKE_CXX_COMPILER_ID}" STREQUAL "AppleClang")
		target_compile_options(ncine PRIVATE -fcolor-diagnostics)
		target_compile_options(ncine PRIVATE -Wall -pedantic -Wextra -Wold-style-cast -Wno-gnu-zero-variadic-macro-arguments -Wno-unused-parameter -Wno-variadic-macros -Wno-c++11-long-long -Wno-missing-braces)

		if(NCINE_DYNAMIC_LIBRARY)
			target_link_options(ncine PRIVATE -Wl,-undefined,error)
		endif()

		# Extra optimizations in release
		target_compile_options(ncine PRIVATE $<$<CONFIG:Release>:-Ofast>)

		# Enabling ThinLTO of Clang 4
		if(NCINE_LINKTIME_OPTIMIZATION AND NOT (MINGW OR MSYS OR "${CMAKE_SYSTEM_NAME}" STREQUAL "Android"))
			target_compile_options(ncine PRIVATE $<$<CONFIG:Release>:-flto=thin>)
			target_link_options(ncine PRIVATE $<$<CONFIG:Release>:-flto=thin>)
		endif()

		if(NCINE_AUTOVECTORIZATION_REPORT)
			target_compile_options(ncine PRIVATE $<$<CONFIG:Release>:-Rpass=loop-vectorize -Rpass-analysis=loop-vectorize>)
		endif()
	endif()
endif()
