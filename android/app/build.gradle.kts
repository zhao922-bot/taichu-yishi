import java.io.File
import java.util.Properties

val configuredKeyPropertiesPath = System.getenv("TAICHU_RELEASE_KEY_PROPERTIES")
val releaseKeyPropertiesFile = configuredKeyPropertiesPath
    ?.takeIf { it.isNotBlank() }
    ?.let { rootProject.file(it) }
    ?: rootProject.file("key.properties")
val releaseKeyProperties = Properties()
if (releaseKeyPropertiesFile.exists()) {
    releaseKeyPropertiesFile.inputStream().use { releaseKeyProperties.load(it) }
}
val hasReleaseSigning = releaseKeyPropertiesFile.exists()
if (!hasReleaseSigning && gradle.startParameter.taskNames.any {
        it.contains("Release", ignoreCase = true)
    }) {
    throw GradleException(
        "正式发布需要 TAICHU_RELEASE_KEY_PROPERTIES 指向签名配置（或 android/key.properties）和正式 keystore；为避免生成不可安装的未签名包，已停止 Release 构建。"
    )
}

val configuredStoreFile = (releaseKeyProperties["storeFile"] as String?)
    ?.takeIf { it.isNotBlank() }
    ?.let(::File)
val resolvedStoreFile = when {
    configuredStoreFile == null -> null
    configuredStoreFile.isAbsolute -> configuredStoreFile
    file(configuredStoreFile.path).exists() -> file(configuredStoreFile.path)
    else -> releaseKeyPropertiesFile.parentFile.resolve(configuredStoreFile.path)
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.taichuyishi.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.taichuyishi.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                keyAlias = releaseKeyProperties["keyAlias"] as String
                keyPassword = releaseKeyProperties["keyPassword"] as String
                storeFile = resolvedStoreFile
                    ?: throw GradleException("签名配置缺少 storeFile。")
                storePassword = releaseKeyProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
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
