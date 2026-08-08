import java.util.Properties
import org.gradle.api.plugins.BasePluginExtension
import org.gradle.api.publish.maven.MavenPublication
import org.gradle.api.publish.tasks.GenerateModuleMetadata
import org.gradle.api.tasks.SourceSetContainer
import org.gradle.jvm.tasks.Jar
import org.gradle.language.jvm.tasks.ProcessResources
import me.modmuss50.mpp.ReleaseType

plugins {
    `java-library`
    `maven-publish`
    id("me.modmuss50.mod-publish-plugin")
}

val targetProperties = Properties()
file("../../gradle.properties").inputStream().use { targetProperties.load(it) }
file("gradle.properties").inputStream().use { targetProperties.load(it) }
targetProperties.forEach { key, value -> extra[key.toString()] = value.toString() }

val mod_group_id: String by project
val mod_version: String by project
val mod_name: String by project

group = mod_group_id
version = mod_version

extensions.configure<BasePluginExtension> {
    archivesName.set("$mod_name-${project.projectDir.name}")
}

val commonProject = project(":common")
val localLibraries = fileTree(projectDir.resolve("libs")) {
    include("*.jar")
    exclude("*-sources.jar", "*-javadoc.jar")
}

dependencies {
    implementation(commonProject)
    implementation(localLibraries)
}

extensions.getByType<SourceSetContainer>().named("main") {
    output.dir(
        mapOf("builtBy" to ":common:classes"),
        commonProject.layout.buildDirectory.dir("classes/java/main"),
    )
    resources.srcDir(commonProject.file("src/main/resources"))
}

tasks.withType<JavaCompile>().configureEach {
    options.encoding = "UTF-8"
}

val publishLoader = project.projectDir.name.substringBefore('-')
val publishMinecraftVersion = when (publishLoader) {
    "forge" -> providers.gradleProperty("forge_minecraft_version")
    "fabric" -> providers.gradleProperty("fabric_minecraft_version")
    "neoforge" -> providers.gradleProperty("neoforge_121_minecraft_version")
        .orElse(providers.gradleProperty("neoforge_261_minecraft_version"))
    else -> error("Cannot determine loader from target directory '${project.projectDir.name}'")
}

val publishFile = if (tasks.findByName("remapJar") != null) {
    providers.provider {
        tasks.getByName("remapJar").let { task ->
            @Suppress("UNCHECKED_CAST")
            (task as org.gradle.api.Task).property("archiveFile") as org.gradle.api.provider.Provider<org.gradle.api.file.RegularFile>
        }.get()
    }
} else {
    tasks.named<Jar>("jar").flatMap { it.archiveFile }
}

val curseforgeProjectId = providers.gradleProperty("publish_curseforge_project_id")
    .orElse(providers.environmentVariable("CURSEFORGE_PROJECT_ID"))
val modrinthProjectId = providers.gradleProperty("publish_modrinth_project_id")
    .orElse(providers.environmentVariable("MODRINTH_PROJECT_ID"))

publishMods {
    file.set(publishFile)
    changelog.set(providers.environmentVariable("PUBLISH_CHANGELOG").orElse("See the project changelog for details."))
    type.set(ReleaseType.STABLE)
    modLoaders.add(publishLoader)

    curseforge {
        projectId.set(curseforgeProjectId)
        accessToken.set(providers.environmentVariable("CURSEFORGE_TOKEN"))
        minecraftVersions.add(publishMinecraftVersion)
        client.set(true)
        server.set(true)
    }

    modrinth {
        projectId.set(modrinthProjectId)
        accessToken.set(providers.environmentVariable("MODRINTH_TOKEN"))
        minecraftVersions.add(publishMinecraftVersion)
    }
}

tasks.named("publishMods").configure {
    doFirst {
        val missing = buildList {
            if (!curseforgeProjectId.isPresent || curseforgeProjectId.get().trim().isEmpty()) {
                add("publish_curseforge_project_id (or CURSEFORGE_PROJECT_ID)")
            }
            if (!modrinthProjectId.isPresent || modrinthProjectId.get().trim().isEmpty()) {
                add("publish_modrinth_project_id (or MODRINTH_PROJECT_ID)")
            }
            val curseforgeToken = providers.environmentVariable("CURSEFORGE_TOKEN")
            if (!curseforgeToken.isPresent || curseforgeToken.get().trim().isEmpty()) add("CURSEFORGE_TOKEN")
            val modrinthToken = providers.environmentVariable("MODRINTH_TOKEN")
            if (!modrinthToken.isPresent || modrinthToken.get().trim().isEmpty()) add("MODRINTH_TOKEN")
        }
        if (missing.isNotEmpty()) {
            error("Cannot publish mods; missing: ${missing.joinToString(", ")}")
        }
    }
}

publishing {
    publications {
        create<MavenPublication>("mavenJava") {
            from(components["java"])
            groupId = project.group.toString()
            artifactId = project.extensions.getByType<BasePluginExtension>().archivesName.get()
            version = project.version.toString()
            pom.withXml {
                val dependenciesNode = (asNode().get("dependencies") as? List<*>)
                    ?.firstOrNull() as? groovy.util.Node
                dependenciesNode?.children()?.toList()?.forEach { dependency ->
                    dependenciesNode.remove(dependency as groovy.util.Node)
                }
            }
        }
    }
    repositories {
        val isSnapshot = project.version.toString().contains("snapshot", ignoreCase = true)
        val publishUrl = if (isSnapshot) {
            "https://maven.sighs.cc/repository/maven-snapshots/"
        } else {
            "https://maven.sighs.cc/repository/maven-releases/"
        }
        maven {
            name = "remoteRepo"
            url = uri(publishUrl)
            credentials {
                username = System.getenv("SIGHS_PUBLISH_USER")
                password = System.getenv("SIGHS_PUBLISH_PASSWORD")
            }
        }
    }
}

tasks.withType<GenerateModuleMetadata>().configureEach {
    enabled = false
}
