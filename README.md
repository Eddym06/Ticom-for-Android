<div align="center">
  <h1>🎟️ Ticom</h1>
  <p><b>Gestión Inteligente de Tickets con Visión OCR</b></p>
  <p>
    <img src="https://img.shields.io/badge/iOS-16.0+-black?style=for-the-badge&logo=apple" alt="iOS 16.0+" />
    <img src="https://img.shields.io/badge/Android-Available-3DDC84?style=for-the-badge&logo=android" alt="Android" />
    <img src="https://img.shields.io/badge/SwiftUI-Blue?style=for-the-badge&logo=swift" alt="SwiftUI" />
  </p>
</div>

---

Ticom es una solución multiplataforma (**iOS** y **Android**) que automatiza el registro, clasificación y control de tickets mediante el escaneo de imágenes. Especialmente diseñada para entornos de alto tráfico (accesos a instalaciones, estacionamientos y eventos).

## 📱 Multiplataforma

Este repositorio contiene el ecosistema completo de la aplicación:
- 🍏 **`Codigos Apple/`**: Aplicación nativa en **SwiftUI** con **Apple Vision Framework** para el motor OCR.
- 🤖 **`Codigos Android/`**: Versión nativa habilitada y optimizada para el entorno de Android.

Ambas plataformas garantizan una experiencia de usuario fluida, diseño nativo e integración con las notificaciones de los respectivos sistemas.

---

## ✨ Características Principales

### 🧠 Escaneo Inteligente (OCR)
- **Extracción de datos:** Captura códigos únicos y fechas mediante expresiones regulares avanzadas.
- **Detección automática:** Identifica el tipo de ticket (Entrada/Salida) analizando combinaciones de texto y color de los bordes.
- **Preprocesamiento:** Ajuste adaptativo de nitidez, contraste y umbralización para potenciar el análisis visual.

### 📋 Gestión de Tickets y UI Interactiva
- **Interfaz amigable:** Tarjetas visuales, filtros por estado (Todos, Entrada, Salida).
- **Calendario dinámico:** Integrado con marcas visuales (puntos verdes para entrada, azules para salidas).
- **Esquema de colores:** Totalmente personalizable directamente desde la aplicación.

### 🔔 Recordatorios y Notificaciones
- Configuración de días laborables / de actividad.
- Alertas inteligentes programables cuando falta escanear un ticket de entrada o salida.
- Selección personalizada de la hora de alarma e intensidad (1-5 repeticiones).

---

## 🗂️ Estructura del Ecosistema

```graphql
Ticom-for-Android/
├── Codigos Apple/       # Proyecto iOS (Swift, SwiftUI, Vision, FSCalendar)
├── Codigos Android/     # Proyecto Android (Versión móvil)
```

### Arquitectura Core iOS (`Codigos Apple/`)
- **`TicketAnalyzer`**: Lógica de OCR y filtros `CIFilter` con fallbacks de precisión.
- **`TicketManager`**: Gestor de estado `ObservableObject` para interactuar con la UI.
- **`TicketStorage`**: Codificación nativa a JSON local.
- **`ContentView`**: Navegación y estructura de la app.

---

## 🛠️ Tecnologías Implementadas

| Sistema / Framework | Uso principal |
|---|---|
| **SwiftUI** (iOS) | Interfaz de usuario declarativa. |
| **Vision Framework** | Reconocimiento Óptico de Caracteres (OCR). |
| **Generador de IA / CIFilter** | Limpieza y mejora en condiciones de mala iluminación. |
| **Google AdMob** | Plataforma de anuncios para monetización. |

---

## 🚀 Guía Rápida

1. **Abre tu plataforma preferida** desde el directorio raíz (`Codigos Apple` para iOS Xcode o `Codigos Android` para Android Studio).
2. **Sigue el tutorial in-app**. Encontrarás una guía interactiva con tooltips que explica cada parte de la pantalla una vez la compiles.
3. Permite la **autorización de notificaciones** para recibir alertas puntuales sobre la ausencia de un escaneo diario.

---
<div align="center">
  <p>Hecho con ❤️ para la gestión moderna y digital. Queda prohibida su distribución sin autorización (Uso Privado).</p>
</div>
