# Декорация окон «Атласа»: KDecoration3-плагин, собирается стадией образа (recipes/*.yml).
cmake_minimum_required(VERSION 3.16)
project(atlas-decoration LANGUAGES CXX)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
set(QT_MAJOR_VERSION 6)
find_package(Qt6 REQUIRED COMPONENTS Core Gui DBus)
include(KDEInstallDirs6)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(KF6CoreAddons REQUIRED)
find_package(KDecoration3 REQUIRED)

add_library(atlasdecoration MODULE atlasdecoration.cpp atlasshadow.cpp atlassnap.cpp)
set_target_properties(atlasdecoration PROPERTIES OUTPUT_NAME org.atlasos.decoration PREFIX "")
target_link_libraries(atlasdecoration PRIVATE Qt6::Core Qt6::Gui Qt6::DBus KF6::CoreAddons KDecoration3::KDecoration)

install(TARGETS atlasdecoration DESTINATION ${KDE_INSTALL_PLUGINDIR}/org.kde.kdecoration3)
