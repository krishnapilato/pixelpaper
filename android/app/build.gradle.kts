import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

fun loadProperties(name: String): Properties? =
    rootProject.file(name).takeIf { it.exists() }?.let { file ->
        Properties().apply { file.inputStream().use(::load) }
    }

val keystore: Properties? = loadProperties("key.properties")

val flutterSdk: File = loadProperties("local.properties")
    ?.getProperty("flutter.sdk")
    ?.let(::File)
    ?: error("flutter.sdk is not set in android/local.properties")

val flutterCommand: String = flutterSdk
    .resolve(if (System.getProperty("os.name").startsWith("Windows")) "bin/flutter.bat" else "bin/flutter")
    .path

// A bundle exists only to be uploaded to Play: refuse to sign one with the
// debug key. A release APK keeps the debug fallback for local testing.
if (keystore == null) {
    gradle.taskGraph.whenReady {
        val bundlesRelease = allTasks.any { it.name == "bundleRelease" }
        if (bundlesRelease) {
            throw GradleException(
                "android/key.properties is missing: the bundle would be signed with the debug key " +
                    "and Play would reject it. See README, \"Pubblicare su Google Play\".",
            )
        }
    }
}

/**
 * The Dart analyzer as part of the build: any error, warning, lint or unused
 * symbol fails it. Up to date while sources and analysis rules are unchanged.
 */
val analyzeDart by tasks.registering(Exec::class) {
    group = "verification"
    description = "Runs flutter analyze with infos and warnings treated as errors."

    val projectRoot = rootProject.projectDir.parentFile
    val marker = layout.buildDirectory.file("analyze-dart/passed")

    workingDir = projectRoot
    commandLine(flutterCommand, "analyze", "--no-pub", "--fatal-infos", "--fatal-warnings")

    inputs.files(
        fileTree(projectRoot.resolve("lib")),
        fileTree(projectRoot.resolve("test")),
        projectRoot.resolve("analysis_options.yaml"),
        projectRoot.resolve("pubspec.yaml"),
        projectRoot.resolve("pubspec.lock"),
    ).withPathSensitivity(PathSensitivity.RELATIVE)
    outputs.file(marker)

    doLast { marker.get().asFile.apply { parentFile.mkdirs() }.writeText("ok\n") }
}

tasks.named("preBuild") { dependsOn(analyzeDart) }

android {
    namespace = "com.khovakrishnapilato.pixelpaper"
    compileSdk = maxOf(flutter.compileSdkVersion, 37)
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_21
        targetCompatibility = JavaVersion.VERSION_21
    }

    kotlin {
        compilerOptions {
            jvmTarget = JvmTarget.JVM_21
            allWarningsAsErrors = true
        }
    }

    defaultConfig {
        applicationId = "com.khovakrishnapilato.pixelpaper"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        keystore?.let { props ->
            create("release") {
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
                storeFile = props.getProperty("storeFile")?.let(::file)
                storePassword = props.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    lint {
        abortOnError = true
        checkReleaseBuilds = true
    }
}

flutter {
    source = "../.."
}
