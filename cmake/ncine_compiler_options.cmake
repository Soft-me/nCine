if(MSVC)
	if(NOT (MSVC_VERSION LESS 1800)) # If Visual Studio 2013 or greater
		set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /FS")
	endif()

	string(REGEX REPLACE "/Zm[0-9]*" "" CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS}")
	
	if(NCINE_EXTRA_OPTIMIZATION)
		set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /Ox /Qpar")
	endif()
	
	if(NCINE_AUTOVECTORIZATION_REPORT)
		set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} /Qvec-report:2 /Qpar-report:2")
	endif()
	
	list(APPEND PRIVATE_COMPILE_DEFINITIONS "WITH_GLEW" "_CRT_SECURE_NO_DEPRECATE")
	
	# Disabling incremental linking and manifest generation
	set(CMAKE_EXE_LINKER_FLAGS_DEBUG "${CMAKE_EXE_LINKER_FLAGS_DEBUG} /MANIFEST:NO /INCREMENTAL:NO")
	set(CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO "${CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO} /MANIFEST:NO /INCREMENTAL:NO")

	if(NCINE_DYNAMIC_LIBRARY)
		# Disabling incremental linking and manifest generation
		set(CMAKE_SHARED_LINKER_FLAGS_DEBUG "${CMAKE_SHARED_LINKER_FLAGS_DEBUG} /MANIFEST:NO /INCREMENTAL:NO")
		set(CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO "${CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO} /MANIFEST:NO /INCREMENTAL:NO")
	else()
		list(APPEND PRIVATE_COMPILE_DEFINITIONS "NCINE_STATIC")
	endif()
else() # GCC and LLVM
	set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fno-exceptions")
	set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -ffast-math")
	
	if(NCINE_DYNAMIC_LIBRARY)
		set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fvisibility=hidden -fvisibility-inlines-hidden")
	endif()

	if(CMAKE_BUILD_TYPE MATCHES "Debug" AND NCINE_ADDRESS_SANITIZER)
		set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -O1 -ggdb -fsanitize=address -fno-omit-frame-pointer -rdynamic")
		set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -fsanitize=address")
		set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} -fsanitize=address")
	endif()
	
	if("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
		set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -pedantic -Wextra -Wold-style-cast -Wno-long-long -Wno-unused-parameter -Wno-ignored-qualifiers -Wno-variadic-macros")
		
		if(NCINE_DYNAMIC_LIBRARY)
			set(CMAKE_SHARED_LINKER_FLAGS "-Wl,--no-undefined")
		endif()

		if(CMAKE_BUILD_TYPE MATCHES "Debug")
			set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -fvar-tracking-assignments")
		endif()
		
		if(CMAKE_BUILD_TYPE MATCHES "Release")
			if(NCINE_EXTRA_OPTIMIZATION)
				set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Ofast -funsafe-loop-optimizations -ftree-loop-if-convert-stores")
			endif()

			if(NCINE_AUTOVECTORIZATION_REPORT)
				set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -fopt-info-vec-optimized")
			endif()

			if(NCINE_GCC_HARDENING)
				set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -fstack-protector-strong")
				set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -Wl,-z,relro -Wl,-z,now")
				set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} -Wl,-z,relro -Wl,-z,now")
				set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -D_FORTIFY_SOURCE=2 -Wformat-security")
			endif()
		endif()
		
		if(CMAKE_CXX_COMPILER_VERSION VERSION_GREATER 4.9.0 OR CMAKE_CXX_COMPILER_VERSION VERSION_EQUAL 4.9.0)
			set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fdiagnostics-color=auto")
			# Enabling Link Time Optimizations of GCC 4.9
			if(CMAKE_BUILD_TYPE MATCHES "Release")
				set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -flto")
				set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} -flto")
				set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} -flto")
			endif()
		endif()
	elseif("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
		set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Wextra -pedantic -Wno-gnu-zero-variadic-macro-arguments -Wno-unused-parameter -Wno-variadic-macros -Wno-c++11-long-long -Wno-missing-braces")
		
		if(NCINE_DYNAMIC_LIBRARY)
			set(CMAKE_SHARED_LINKER_FLAGS "-Wl,-undefined,error")
		endif()

		if(CMAKE_BUILD_TYPE MATCHES "Release")
			if(NCINE_EXTRA_OPTIMIZATION)
				set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Ofast -fslp-vectorize-aggressive")
			endif()

			if(NCINE_AUTOVECTORIZATION_REPORT)
				set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -Rpass=loop-vectorize -Rpass-analysis=loop-vectorize")
			endif()
		endif()
	endif()
endif()