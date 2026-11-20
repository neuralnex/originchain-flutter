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
// solana_mobile_client 0.1.2 pins compileSdk 31, but its AndroidX
// dependencies require API 34+. Keep its library compile SDK aligned with the
// app without raising targetSdk or changing runtime behavior.
subprojects {
    val subproject = this
    subproject.afterEvaluate {
        if (subproject.name == "solana_mobile_client") {
            val androidExtension = subproject.extensions.findByName("android")
                ?: throw GradleException("solana_mobile_client Android extension was not found")
            val compileSdkSetter = androidExtension.javaClass.methods.firstOrNull { method ->
                method.name == "setCompileSdkVersion" &&
                    method.parameterTypes.size == 1 &&
                    method.parameterTypes[0] == Int::class.javaPrimitiveType
            } ?: throw GradleException("Could not set solana_mobile_client compileSdk")
            compileSdkSetter.invoke(androidExtension, 35)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
