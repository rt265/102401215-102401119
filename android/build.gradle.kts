allprojects {
    repositories {
        // 只声明官方源，仓库保持可在任何机器 / CI 上直接使用。
        // 本机走国内镜像时由用户级 init 脚本（~/.gradle/init.d）在这些源之前插入，
        // 见 docs/agents/local-gradle-config.md。
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
