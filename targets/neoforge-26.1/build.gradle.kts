plugins {
    id("sighs.target-conventions")
    id("net.neoforged.moddev") version "2.0.141"
}

val mod_id: String by project
val mod_name: String by project
val neoforge_261_minecraft_version: String by project
val neoforge_261_version: String by project
val neoforge_261_version_range: String by project
val mod_license: String by project
val mod_authors: String by project
val mod_description: String by project
val mod_version: String by project

java {
    toolchain.languageVersion.set(JavaLanguageVersion.of(25))
}

neoForge {
    version = neoforge_261_version

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

tasks.named<ProcessResources>("processResources") {
    val replaceProperties = mapOf(
        "minecraft_version" to neoforge_261_minecraft_version,
        "neoforge_version" to neoforge_261_version,
        "neoforge_version_range" to neoforge_261_version_range,
        "mod_id" to mod_id,
        "mod_name" to mod_name,
        "mod_license" to mod_license,
        "mod_version" to mod_version,
        "mod_authors" to mod_authors,
        "mod_description" to mod_description,
    )
    inputs.properties(replaceProperties)
    filesMatching("META-INF/neoforge.mods.toml") {
        expand(replaceProperties + mapOf("project" to project))
    }
}
