# «Добро пожаловать в Атлас»: запускалка QML первого входа, собирается стадией образа (recipes/*.yml).
# Интерфейс — /usr/share/atlasos/welcome/Main.qml (files/system), чтобы правка не требовала пересборки.
cmake_minimum_required(VERSION 3.16)
project(atlas-welcome LANGUAGES CXX)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets Qml Quick)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

add_executable(atlas-welcome main.cpp)
target_link_libraries(atlas-welcome PRIVATE Qt6::Core Qt6::Gui Qt6::Widgets Qt6::Qml Qt6::Quick)
install(TARGETS atlas-welcome RUNTIME DESTINATION bin)
