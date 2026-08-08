plugins {
    `kotlin-dsl`
}

repositories {
    gradlePluginPortal()
    mavenCentral()
    maven("https://maven.fabricmc.net/")
    maven("https://maven.minecraftforge.net/")
    maven("https://maven.neoforged.net/releases")
}

dependencies {
    implementation("me.modmuss50:mod-publish-plugin:2.1.1")
}
