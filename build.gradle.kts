import org.gradle.api.tasks.Exec

data class TargetBuild(val directory: String, val task: String)

val targetBuilds = mapOf(
    "forge-1.20.1" to TargetBuild("targets/forge-1.20.1", "buildForge1201"),
    "fabric-1.20.1" to TargetBuild("targets/fabric-1.20.1", "buildFabric1201"),
    "neoforge-1.21.1" to TargetBuild("targets/neoforge-1.21.1", "buildNeoForge1211"),
)

val selectedTarget = providers.gradleProperty("target").orNull
val buildAllTargets = providers.gradleProperty("allTargets")
    .map(String::toBoolean)
    .getOrElse(false)

if (selectedTarget != null && selectedTarget !in targetBuilds) {
    error("Unknown target '$selectedTarget'. Available targets: ${targetBuilds.keys.joinToString(", ")}")
}

targetBuilds.forEach { (targetName, targetBuild) ->
    tasks.register<Exec>(targetBuild.task) {
        group = "build"
        description = "Builds $targetName in its independent Gradle project."
        workingDir(rootDir)
        commandLine(
            "cmd", "/c", "gradlew.bat", "-p",
            targetBuild.directory.replace('/', '\\'),
            "build", "--console", "plain", "--no-daemon",
        )
    }
}

tasks.register("build") {
    group = "build"
    description = "Builds common and an optionally selected JDK 21 target."
    dependsOn(":common:build")

    selectedTarget?.let { dependsOn(targetBuilds.getValue(it).task) }
    if (buildAllTargets) {
        targetBuilds.values.forEach { dependsOn(it.task) }
    }
}
