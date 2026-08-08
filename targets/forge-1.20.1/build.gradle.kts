plugins {
    id("sighs.target-conventions")
    id("net.neoforged.moddev.legacyforge") version "2.0.142"
}

val mod_id: String by project
val mod_name: String by project
val forge_minecraft_version: String by project
val forge_version: String by project
val forge_version_range: String by project
val forge_loader_version_range: String by project
val mod_license: String by project
val mod_authors: String by project
val mod_description: String by project
val mod_version: String by project

java {
    toolchain.languageVersion.set(JavaLanguageVersion.of(17))
}

legacyForge {
    version = "$forge_minecraft_version-$forge_version"
    validateAccessTransformers.set(true)

    runs {
        create("client") {
            client()
        }
        create("server") {
            server()
            programArgument("--nogui")
        }
    }

    mods {
        create(mod_id) {
            sourceSet(sourceSets.named("main").get())
        }
    }
}

repositories {
    mavenCentral()
}

tasks.named<ProcessResources>("processResources") {
    val replaceProperties = mapOf(
        "minecraft_version" to forge_minecraft_version,
        "forge_version" to forge_version,
        "forge_version_range" to forge_version_range,
        "loader_version_range" to forge_loader_version_range,
        "mod_id" to mod_id,
        "mod_name" to mod_name,
        "mod_license" to mod_license,
        "mod_version" to mod_version,
        "mod_authors" to mod_authors,
        "mod_description" to mod_description,
    )
    inputs.properties(replaceProperties)
    filesMatching("META-INF/mods.toml") {
        expand(replaceProperties + mapOf("project" to project))
    }
}
