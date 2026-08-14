plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseKeystorePath = System.getenv("MBNDL_KEYSTORE_PATH")
val releaseKeystorePassword = System.getenv("MBNDL_KEYSTORE_PASSWORD")
val releaseKeyAlias = System.getenv("MBNDL_KEY_ALIAS")
val releaseKeyPassword = System.getenv("MBNDL_KEY_PASSWORD")
val hasReleaseSigning = listOf(
    releaseKeystorePath,
    releaseKeystorePassword,
    releaseKeyAlias,
    releaseKeyPassword
).all { !it.isNullOrBlank() }

android {
    namespace = "com.mbn.dl"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mbn.dl"
        minSdk = 24
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName

    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            // youtubedl-android ships compressed runtimes disguised as .so so
            // Android extracts them. They are archives, not ELF binaries.
            keepDebugSymbols += setOf("**/libffmpeg.zip.so", "**/libaria2c.zip.so", "**/libpython.zip.so")
        }
        resources {
            excludes += setOf(
                "META-INF/LICENSE",
                "META-INF/LICENSE.txt",
                "META-INF/NOTICE",
                "META-INF/NOTICE.txt",
                "META-INF/DEPENDENCIES",
                "META-INF/*.kotlin_module",
                "META-INF/gradle/*",
                "META-INF/proguard/*",
                "META-INF/com.android.tools/**",
                "kotlin/**",
                "**.md",
                "**.txt",
                "**.properties"
            )
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(releaseKeystorePath!!)
                storePassword = releaseKeystorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            // CI releases use a persistent private key so future in-app APK
            // upgrades keep the same Android signing identity. Local release
            // builds fall back to the debug key when these variables are absent.
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Enable code shrinking, obfuscation, and optimization
            isMinifyEnabled = true
            isShrinkResources = true

            // ProGuard rules
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
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
    // yt-dlp for Android
    implementation("io.github.junkfood02.youtubedl-android:library:0.18.1")
    implementation("io.github.junkfood02.youtubedl-android:ffmpeg:0.18.1")
    implementation("io.github.junkfood02.youtubedl-android:aria2c:0.18.1")

    // Kotlin Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")
}
