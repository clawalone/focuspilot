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
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Fix for "Namespace not specified" error in AGP 8.0+
// Fix for "Namespace not specified" error in AGP 8.0+ and force compileSdk
subprojects {
    project.pluginManager.withPlugin("com.android.library") {
        val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
        if (android.namespace == null) {
            android.namespace = project.group.toString()
        }
        android.compileSdkVersion(36)
    }
}
