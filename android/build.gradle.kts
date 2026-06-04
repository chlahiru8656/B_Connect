allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

// Strip deprecated 'package' attribute from subprojects' AndroidManifest.xml files to satisfy AGP 8.0+
subprojects {
    val manifestFile = file("src/main/AndroidManifest.xml")
    if (manifestFile.exists()) {
        try {
            var content = manifestFile.readText()
            if (content.contains("package=")) {
                content = content.replace(Regex("""package="[^"]*""""), "")
                manifestFile.writeText(content)
            }
        } catch (e: Exception) {
            logger.warn("Could not sanitize manifest for subproject ${project.name}: ${e.message}")
        }
    }
}

subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android != null && android is com.android.build.gradle.BaseExtension) {
            if (android.namespace.isNullOrEmpty()) {
                android.namespace = project.group.toString()
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
