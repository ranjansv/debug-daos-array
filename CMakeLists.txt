#Before running cmake and make source /work2/06753/soychan/frontera/4NODE/BUILDS/files/env_daos

cmake_minimum_required(VERSION 3.12)
project(benchmark C CXX)
set(CMAKE_BUILD_TYPE Debug)

#set(CMAKE_CXX_FLAGS "-fpic -g -std=c++11 -Wno-write-strings") 
#set(CMAKE_CXX_FLAGS "-D_GLIBCXX_USE_CXX11_ABI=0 -std=c++11")
#set(CMAKE_CXX_FLAGS "-g -std=c++11") 



find_package(MPI REQUIRED)
find_package(ADIOS2 REQUIRED)

#add_compile_definitions(-D_GLIBCXX_USE_CXX11_ABI=0)

include_directories(/work2/08126/dbohninx/frontera/4NODE/BUILDS/latest/daos/install/prereq/release/pmdk/include/)
include_directories(/work2/08126/dbohninx/frontera/4NODE/BUILDS/latest/daos/install/prereq/release/isal/include)
include_directories(/work2/08126/dbohninx/frontera/4NODE/BUILDS/latest/daos/install/prereq/release/isal_crypto/include)
include_directories(/work2/08126/dbohninx/frontera/4NODE/BUILDS/latest/daos/install/prereq/release/argobots/include/)
include_directories(/work2/08126/dbohninx/frontera/4NODE/BUILDS/latest/daos/install/prereq/release/protobufc/include)
include_directories(/work2/08126/dbohninx/frontera/4NODE/BUILDS/latest/daos/src/tests)
include_directories(/work2/08126/dbohninx/frontera/4NODE/BUILDS/latest/daos/src/mgmt)
include_directories(/work2/08126/dbohninx/frontera/4NODE/BUILDS/latest/daos/src/include)
include_directories(/work2/08059/ranjansv/frontera/caliper/install/include)
link_directories(/work2/08126/dbohninx/frontera/4NODE/BUILDS/latest/daos/install/lib64)
link_directories(/work2/08059/ranjansv/frontera/caliper/install/lib64)

add_executable(daos_array-writer-obj-per-rank daos_array-writer-obj-per-rank.c)
target_link_libraries(daos_array-writer-obj-per-rank PRIVATE daos daos_common gurt cart  uuid cmocka daos_tests MPI::MPI_C caliper)

