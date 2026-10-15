# app-productores-RA

Aplicación Flutter offline-first para registro de productores de cacao. Permite autenticación local cifrada, gestión de fincas con códigos únicos, formarios dinámicos desde plantillas JSON y almacenamiento local de respuestas sin conexión a internet.

---

## Arquitectura

El proyecto sigue una arquitectura por capas con separación de responsabilidades. Cada archivo contiene una sola clase (principio SOLID de Single Responsibility).

```
lib/
├── main.dart                        # Punto de entrada, inicialización de servicios
├── models/
│   ├── form_response.dart           # Modelo Hive para respuestas guardadas
│   └── finca.dart                   # Modelo Hive para fincas registradas
├── services/
│   ├── auth_service.dart            # Autenticación offline con storage cifrado
│   ├── database_service.dart        # Persistencia local con Hive
│   ├── finca_service.dart           # Lógica de fincas: códigos, prefijos, números
│   └── template_service.dart        # Carga y parseo de plantillas JSON
├── templates/
│   ├── ficha_agricultor.dart        # Plantilla: Ficha del agricultor
│   ├── registro_cosecha.dart        # Plantilla: Registro manual de cosecha
│   ├── registro_agroquimicos.dart   # Plantilla: Registro de agroquímicos
│   └── registro_fertilizantes.dart  # Plantilla: Registro de fertilizantes
├── screens/
│   ├── login_screen.dart            # Pantalla de autenticación
│   ├── finca_home_screen.dart       # Menú principal: Registrar / Editar Finca
│   ├── registrar_finca_screen.dart  # Formulario de registro de finca
│   ├── editar_finca_screen.dart     # Lista de fincas registradas
│   ├── finca_formularios_screen.dart # Formularios disponibles para una finca
│   └── form_screen.dart             # Renderizado dinámico de formulario
└── widgets/
    └── numero_selector.dart         # Selector de números (PopupMenuButton)
```

### Capas

| Capa | Responsabilidad |
|---|---|
| **models** | Definición de esquemas de datos persistentes (HiveObject) |
| **services** | Lógica de negocio: autenticación, base de datos, fincas, plantillas |
| **templates** | Definiciones JSON de formularios, un archivo por formulario |
| **screens** | UI y manejo de estado con `setState` |
| **widgets** | Componentes reutilizables independientes |

---

## Tecnologías

| Paquete | Uso |
|---|---|
| `flutter_secure_storage` | Almacenamiento cifrado de credenciales de autenticación |
| `hive` + `hive_flutter` | Base de datos local NoSQL, soporte multiplataforma (móvil, web, desktop) |
| `flutter_form_builder` | Renderizado dinámico y validación de campos de formulario |
| `intl` | Formato de fechas localizado |
| `crypto` | Hashing SHA-256 de contraseñas |
| `uuid` | Generación de IDs únicos |
| `path_provider` | Directorio de documentos de la app |

---

## Funcionalidades

### Autenticación Offline
- Al iniciar la app, se crea un usuario por defecto (`admin` / `password123`) si no existe ninguno
- Las contraseñas se almacenan hasheadas con SHA-256, nunca en texto plano
- Validación contra `flutter_secure_storage` con feedback visual de error
- Ícono para mostrar/ocultar contraseña

### Gestión de Fincas

**Registrar Finca:**
- Selector de cantóon: Babahoyo, Naranjal, La Troncal
- Selector de prefijos según el cantóon:
  - Babahoyo: BAB, BABS, BABN
  - Naranjal: NJL, NJL1, NJL2
  - La Troncal: TCL, TCLA, TCLC
- Selector de número disponible: números liberados por fincas inactivas se reutilizan primero, luego se asigna el siguiente consecutivo
- Código mostrado claramente antes de guardar (ej: `BAB-002`)
- Finca se guarda con estado "Activa"

**Editar Finca:**
- Lista vertical de todas las fincas registradas
- Indicador visual de estado Activa/Inactiva
- Cada finca muestra sus formularios disponibles con alertas de color:
  - Rojo: 100% vacío
  - Amarillo: parcialmente completado
  - Verde: 100% completo
- Los formularios conservan los valores después de guardar

### Formularios Dinámicos

| Formulario | Descripción |
|---|---|
| **Ficha del agricultor** | Datos personales del productor |
| **Registro manual de cosecha** | Cosechas: producto, cantidad, calidad |
| **Registro de agroquímicos** | Pesticidas, herbicidas, rodenticidas |
| **Registro de fertilizantes** | Fertilizantes orgánicos e inorgánicos |

Cada formulario define campos de tipos: texto, número, fecha, dropdown y switch. Se renderizan dinámicamente según la plantilla JSON.

### Almacenamiento Local
- Las respuestas se guardan en Hive, asociadas a la finca y al formulario
- Cada registro incluye: templateId compuesto, respuestas, timestamp
- Al editar un formulario existente, se actualiza el registro en lugar de crear uno nuevo
- Se retorna siempre el registro más reciente por finca + formulario

---

## Ejecución

```bash
# Instalar dependencias
flutter pub get

# Generar código (adaptadores Hive)
dart run build_runner build --delete-conflicting-outputs

# Ejecutar en Android/iOS
flutter run

# Ejecutar en Chrome
flutter run -d chrome
```

---

## Plataformas Soportadas

| Plataforma | Estado |
|---|---|
| Android | Funcional |
| iOS | Funcional |
| Web (Chrome) | Funcional |
| Desktop | No probado |
