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

// isar_flutter_libs 3.1.0+1 predates AGP 8: it declares no `namespace` and compiles against
// SDK 30, where androidx resources fail to link (`android:attr/lStar not found`). Give legacy
// plugins a namespace derived from their group and lift their compileSdk to at least 36.
val minPluginCompileSdk = 36
subprojects {
    plugins.withId("com.android.library") {
        val android = extensions.getByName("android") as com.android.build.gradle.LibraryExtension
        if (android.namespace == null) {
            android.namespace = project.group.toString()
        }
        // finalizeDsl runs after the plugin's build script and before AGP locks the DSL
        // (afterEvaluate is too late: "It is too late to set compileSdk")
        extensions.configure<com.android.build.api.variant.LibraryAndroidComponentsExtension>("androidComponents") {
            finalizeDsl { ext ->
                if ((ext.compileSdk ?: 0) < minPluginCompileSdk) {
                    ext.compileSdk = minPluginCompileSdk
                }
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
