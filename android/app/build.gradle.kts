import java.io.FileInputStream
import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    // Kotlin arrives through AGP's built-in support (android.builtInKotlin=true),
    // which is what the CameraX and ML Kit plugins expect on AGP 9.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasKeystore = keystorePropertiesFile.exists()
if (hasKeystore) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// An app bundle exists for one reason: uploading to Play. Signing one with the
// debug key produces an artefact that builds, installs and is rejected only at
// the end of the upload — so refuse to build it at all. An APK keeps the debug
// fallback, because a locally signed release APK is genuinely useful.
if (!hasKeystore) {
    gradle.taskGraph.whenReady {
        if (allTasks.any { it.name.startsWith("bundle") && it.name.contains("Release") }) {
            throw GradleException(
                "android/key.properties is missing: the bundle would be signed with the " +
                    "debug key and Play would reject it. Create the file with storeFile, " +
                    "storePassword, keyAlias and keyPassword (see README), or build an APK " +
                    "instead. Note that a git worktree does not inherit it: it is untracked.",
            )
        }
    }
}

android {
    namespace = "com.khovakrishnapilato.pixelpaper"
    // 36 is required by google_mlkit_document_scanner 0.6.x.
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget.set(JvmTarget.JVM_17)
        }
    }

    defaultConfig {
        applicationId = "com.khovakrishnapilato.pixelpaper"
        // CameraX needs 23+, ML Kit document scanner 21+; Flutter's floor is 24.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("release") {
            // Without key.properties the release build falls back to the debug
            // key so `flutter build apk --release` still works locally.
            signingConfig = if (hasKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
