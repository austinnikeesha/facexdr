// Top-level build file where you can add configuration options common to all sub-projects/modules.

plugins {
    id("org.gradle.groovy") version "8.7.3" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

tasks.register("clean", Delete::class) {
    delete(rootProject.buildDir)
}