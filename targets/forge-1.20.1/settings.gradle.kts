pluginManagement {
    includeBuild("../../build-logic")
    repositories {
        gradlePluginPortal()
        maven("https://maven.minecraftforge.net/")
        mavenCentral()
    }
}

rootProject.name = "SighsTemple-forge-1.20.1"

include(":common")
project(":common").projectDir = file("../../common")
