# Ticom-for-Android

## Descripción
Ticom es una aplicación de gestión de tickets de transporte público desarrollada para Android. La aplicación permite a los usuarios procesar, organizar y gestionar tickets de entrada y salida utilizando reconocimiento óptico de caracteres (OCR) y un calendario integrado.

## Características Principales

### 📱 Funcionalidades Core
- **Procesamiento de Tickets**: Utiliza ML Kit Text Recognition para extraer información automáticamente de imágenes de tickets
- **Gestión de Entrada/Salida**: Organización automática de tickets por tipo (entrada/salida)
- **Calendario Integrado**: Visualización de tickets por fecha con indicadores visuales
- **Configuración de Días Laborables**: Define qué días requieren tickets para recibir notificaciones
- **Sistema de Notificaciones**: Alertas automáticas para tickets faltantes en días de clase
- **Personalización de Colores**: Interfaz totalmente personalizable con gradientes customizables

### 🎨 Interfaz de Usuario
- **Jetpack Compose**: UI moderna y reactiva
- **Material Design 3**: Diseño consistente con las últimas guías de Material
- **Gradientes Personalizables**: Colores de fondo y botones totalmente customizables
- **Animaciones Fluidas**: Transiciones suaves y feedback háptico
- **Modo Oscuro**: Soporte completo para temas claros y oscuros

### 🔧 Tecnologías Utilizadas
- **Kotlin**: Lenguaje de programación principal
- **Jetpack Compose**: Framework de UI moderna
- **ML Kit Text Recognition**: OCR para procesamiento de tickets
- **Room Database**: Base de datos local (preparado para futuras versiones)
- **SharedPreferences**: Almacenamiento de configuraciones
- **Coroutines**: Programación asíncrona
- **Material Design 3**: Sistema de diseño

## 📁 Estructura del Proyecto

```
codigo_android/
├── app/
│   ├── src/main/
│   │   ├── java/com/ticom/android/
│   │   │   ├── data/           # Capa de datos
│   │   │   │   ├── TicketManager.kt      # Gestor principal de tickets
│   │   │   │   ├── TicketAnalyzer.kt     # Procesamiento OCR
│   │   │   │   ├── TicketProcessor.kt    # Procesamiento concurrente
│   │   │   │   └── TicketStorage.kt      # Almacenamiento JSON
│   │   │   ├── models/         # Modelos de datos
│   │   │   │   ├── Ticket.kt             # Modelo principal de ticket
│   │   │   │   └── UserGuideStep.kt      # Pasos de guía de usuario
│   │   │   ├── ui/             # Interfaz de usuario
│   │   │   │   ├── theme/                # Tema y colores
│   │   │   │   ├── components/           # Componentes reutilizables
│   │   │   │   ├── screens/              # Pantallas principales
│   │   │   │   └── ContentView.kt        # Vista principal
│   │   │   ├── utils/          # Utilidades
│   │   │   │   ├── Extensions.kt         # Extensiones de Kotlin
│   │   │   │   └── ErrorLogger.kt        # Sistema de logging
│   │   │   └── MainActivity.kt           # Actividad principal
│   │   ├── res/                # Recursos
│   │   │   ├── drawable/       # Imágenes y gráficos
│   │   │   ├── values/         # Strings, colores, temas
│   │   │   └── xml/            # Configuraciones XML
│   │   └── AndroidManifest.xml # Manifiesto de la aplicación
│   ├── build.gradle.kts        # Configuración del módulo
│   └── proguard-rules.pro      # Reglas de ofuscación
├── build.gradle.kts            # Configuración del proyecto
├── settings.gradle.kts         # Configuración de Gradle
└── .gitignore                  # Archivos ignorados por Git
```

## 🚀 Instalación y Configuración

### Requisitos Previos
- Android Studio Hedgehog | 2023.1.1 o superior
- Android SDK API 24 (Android 7.0) o superior
- JDK 8 o superior

### Pasos de Instalación

1. **Clonar el repositorio**:
   ```bash
   git clone https://github.com/Eddym06/Ticom-for-Android.git
   cd Ticom-for-Android
   ```

2. **Abrir en Android Studio**:
   - Abre Android Studio
   - Selecciona "Open an existing project"
   - Navega a la carpeta `codigo_android`
   - Selecciona la carpeta y abre el proyecto

3. **Sincronización de Gradle**:
   - Android Studio sincronizará automáticamente las dependencias
   - Si no, ejecuta manualmente "Sync Project with Gradle Files"

4. **Configurar emulador o dispositivo**:
   - Configura un emulador con API 24+ o conecta un dispositivo físico
   - Habilita "Depuración USB" en el dispositivo físico

5. **Compilar y ejecutar**:
   - Presiona el botón "Run" (▶️) en Android Studio
   - O ejecuta desde la línea de comandos:
     ```bash
     ./gradlew assembleDebug
     ```

## 📱 Uso de la Aplicación

### Primera Configuración
1. **Permisos**: La aplicación solicitará permisos para:
   - Acceso a almacenamiento (para cargar imágenes de tickets)
   - Notificaciones (para alertas de tickets faltantes)

2. **Días de Clase**: Configura qué días de la semana usas transporte público

3. **Notificaciones**: Establece la hora para recibir recordatorios

### Funcionalidades Principales

#### 📸 Subir Tickets
- Presiona "Subir Ticket" para seleccionar imágenes
- La aplicación procesará automáticamente la información usando OCR
- Los tickets se clasificarán como "entrada" o "salida"

#### 📅 Calendario
- Visualiza todos tus tickets organizados por fecha
- Los días con tickets aparecen marcados
- Toca cualquier fecha para ver los tickets de ese día

#### 🎯 Tickets de Hoy
- Botones "Entrada" y "Salida" muestran tickets del día actual
- Si no hay tickets, te permite subirlos directamente

#### ⚙️ Configuraciones
- **Notificaciones**: Configura hora y frecuencia de alertas
- **Colores**: Personaliza la apariencia de la aplicación
- **Días de Clase**: Modifica los días laborables

## 🔧 Dependencias Principales

```kotlin
// UI y Compose
implementation("androidx.compose.ui:ui")
implementation("androidx.compose.material3:material3")
implementation("androidx.navigation:navigation-compose")

// Procesamiento de imágenes y ML
implementation("com.google.mlkit:text-recognition")
implementation("io.coil-kt:coil-compose")

// Persistencia y datos
implementation("org.jetbrains.kotlinx:kotlinx-serialization-json")
implementation("androidx.datastore:datastore-preferences")

// Utilitarios
implementation("org.jetbrains.kotlinx:kotlinx-datetime")
implementation("androidx.work:work-runtime-ktx")
```

## 🔄 Migración desde iOS

Esta aplicación es una versión Android completamente funcional de la aplicación iOS original. Las principales equivalencias incluyen:

| iOS (Swift) | Android (Kotlin) |
|-------------|------------------|
| SwiftUI | Jetpack Compose |
| Vision Framework | ML Kit Text Recognition |
| UserDefaults | SharedPreferences |
| Core Data | Room Database (preparado) |
| FSCalendar | Compose Calendar (implementación personalizada) |
| @Published | mutableStateOf |
| NavigationView | Navigation Compose |

## 🐛 Solución de Problemas

### Problemas Comunes

1. **Error de compilación con ML Kit**:
   ```bash
   # Asegúrate de tener Google Play Services actualizado
   # Verifica que el dispositivo tenga suficiente espacio
   ```

2. **Permisos denegados**:
   - Ve a Configuración > Aplicaciones > Ticom > Permisos
   - Habilita almacenamiento y notificaciones

3. **OCR no funciona correctamente**:
   - Asegúrate de que las imágenes tengan buena calidad
   - Verifica que haya buena iluminación
   - El texto debe estar claramente visible

### Logs y Depuración
La aplicación incluye un sistema de logging comprehensivo accesible desde la configuración.

## 🤝 Contribuciones

Las contribuciones son bienvenidas. Por favor:

1. Fork el repositorio
2. Crea una rama feature (`git checkout -b feature/nueva-funcionalidad`)
3. Commit tus cambios (`git commit -am 'Agregar nueva funcionalidad'`)
4. Push a la rama (`git push origin feature/nueva-funcionalidad`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver el archivo `LICENSE` para más detalles.

## 📞 Soporte

Para reportar problemas o solicitar funcionalidades:
- Abre un issue en GitHub
- Contacta al desarrollador

---

**Versión**: 1.0.0  
**Compatibilidad**: Android 7.0 (API 24) o superior  
**Última actualización**: 2024
