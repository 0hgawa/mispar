import java.util.Properties

// A chave de assinatura, quando existe nesta maquina.
val assinatura = rootProject.file("key.properties").let { arquivo ->
    if (arquivo.exists()) {
        Properties().apply { arquivo.inputStream().use { load(it) } }
    } else {
        null
    }
}

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mispar.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.mispar.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (assinatura != null) {
                keyAlias = assinatura.getProperty("keyAlias")
                keyPassword = assinatura.getProperty("keyPassword")
                // `rootProject`: o `.jks` mora ao lado do `key.properties`,
                // em android/, e nao dentro do modulo app/.
                storeFile = rootProject.file(assinatura.getProperty("storeFile"))
                storePassword = assinatura.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            // Assina com a chave de verdade quando ela esta na maquina, e com a
            // de depuracao quando nao esta.
            //
            // O `key.properties` e o `.jks` ficam fora do git de proposito:
            // quem tem o arquivo pode publicar atualizacao do app no nome do
            // dono. Sem eles o projeto continua compilando — quem clona
            // consegue rodar, so nao consegue assinar.
            signingConfig = if (assinatura != null) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // O R8 tira o codigo que ninguem chama e encurta os nomes que
            // sobram. E o que separa o APK de trabalhar do APK de testar.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
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
