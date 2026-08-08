pluginManagement {
    includeBuild("../../build-logic")
    repositories {
        gradlePluginPortal()
        maven("https://maven.neoforged.net/releases")
        mavenCentral()
    }
}

rootProject.name = "SighsTemple-neoforge-1.21.1"

include(":common")
project(":common").projectDir = file("../../common")
