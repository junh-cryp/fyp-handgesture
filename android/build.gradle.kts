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

// Global namespace fix for modern AGP 8.x
subprojects {
    afterEvaluate {
        val extension = extensions.findByName("android")
        if (extension != null) {
            val getNamespaceMethod = extension.javaClass.methods.find { it.name == "getNamespace" }
            val setNamespaceMethod = extension.javaClass.methods.find { it.name == "setNamespace" }
            
            if (getNamespaceMethod != null && setNamespaceMethod != null) {
                val currentNamespace = getNamespaceMethod.invoke(extension)
                if (currentNamespace == null) {
                    val newNamespace = "com.fyp.handgesture.${project.name.replace("-", "_").replace(":", "_")}"
                    setNamespaceMethod.invoke(extension, newNamespace)
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
