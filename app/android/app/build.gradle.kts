import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: android/key.properties (gitignored) names the keystore and its passwords.
val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties().apply {
    if (keyPropertiesFile.exists()) keyPropertiesFile.inputStream().use { load(it) }
}
val hasReleaseKey = keyPropertiesFile.exists()

fun releaseKey(name: String): String =
    keyProperties.getProperty(name)?.takeIf { it.isNotBlank() }
        ?: throw GradleException("${keyPropertiesFile.path} has no value for '$name'. See key.properties.example.")

android {
    namespace = "com.forreal.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs core library desugaring.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.forreal.app"
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Debug builds keep the default debug key. Release builds are signed only with the
        // keystore named in android/key.properties, which is never committed.
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(releaseKey("storeFile"))
                storePassword = releaseKey("storePassword")
                keyAlias = releaseKey("keyAlias")
                keyPassword = releaseKey("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Without key.properties there is no release signing config at all; the check
            // below stops the build instead of producing a debug-signed or unsigned release.
            signingConfig = if (hasReleaseKey) signingConfigs.getByName("release") else null
        }
    }
}

// A release build without the release keystore must fail, and say why.
gradle.taskGraph.whenReady {
    val buildsRelease = allTasks.any {
        it.project == project && Regex("^(assemble|bundle|package|install)(.*)Release$").matches(it.name)
    }
    if (buildsRelease && !hasReleaseKey) {
        throw GradleException(
            "Release signing is not set up: ${keyPropertiesFile.path} is missing. " +
                "Create a keystore and key.properties as described in app/README.md " +
                "(\"Release signing\"), or build a debug APK instead."
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    // Background processing of queued bank messages (CaptureWorker).
    implementation("androidx.work:work-runtime:2.10.5")
    implementation("androidx.concurrent:concurrent-futures:1.3.0")
    implementation("androidx.core:core-ktx:1.16.0")
    testImplementation("junit:junit:4.13.2")
}
