plugins {
    id("sighs.target-conventions")
    id("fabric-loom") version "1.10.5"
}

val mod_id: String by project
val mod_name: String by project
val fabric_minecraft_version: String by project
val fabric_loader_version: String by project
val fabric_api_version: String by project
val mod_license: String by project
val mod_authors: String by project
val mod_description: String by project
val mod_version: String by project

java {
    toolchain.languageVersion.set(JavaLanguageVersion.of(17))
}

repositories {
    mavenCentral()
}

dependencies {
    minecraft("com.mojang:minecraft:$fabric_minecraft_version")
    mappings(loom.officialMojangMappings())
    modImplementation("net.fabricmc:fabric-loader:$fabric_loader_version")
    modImplementation("net.fabricmc.fabric-api:fabric-api:$fabric_api_version")
    implementation(project(":common"))
}

tasks.named<ProcessResources>("processResources") {
    val replaceProperties = mapOf(
        "minecraft_version" to fabric_minecraft_version,
        "fabric_loader_version" to fabric_loader_version,
        "mod_id" to mod_id,
        "mod_name" to mod_name,
        "mod_license" to mod_license,
        "mod_version" to mod_version,
        "mod_authors" to mod_authors,
        "mod_description" to mod_description,
    )
    inputs.properties(replaceProperties)
    filesMatching("fabric.mod.json") {
        expand(replaceProperties + mapOf("project" to project))
    }
}

tasks.withType<JavaCompile>().configureEach {
    options.release.set(17)
}
