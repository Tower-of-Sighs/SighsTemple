pluginManagement {
    includeBuild("../../build-logic")
    repositories {
        gradlePluginPortal()
        maven("https://maven.fabricmc.net/")
        mavenCentral()
    }
}

rootProject.name = "SighsTemple-fabric-1.20.1"

include(":common")
project(":common").projectDir = file("../../common")
