# app-productores-RA

Aplicación Flutter offline-first para registro de productores de cacao. Permite autenticación local cifrada, carga de formularios dinámicos desde plantillas JSON y almacenamiento local de respuestas sin conexión a internet.

---

## Arquitectura

El proyecto sigue una arquitectura por capas con separación de responsabilidades:

```
lib/
├── main.dart                    # Punto de entrada, inicialización de servicios
├── models/
│   └── form_response.dart       # Modelo Hive para respuestas de formularios
├── services/
│   ├── auth_service.dart        # Autenticación offline con storage cifrado
│   ├── database_service.dart    # Persistencia local con Hive
│   └── template_service.dart    # Carga y parseo de plantillas JSON
├── templates/
│   └── agricultor_template.dart # Plantilla hardcodeada "Ficha del Agricultor"
├── screens/
│   ├── login_screen.dart        # Pantalla de autenticación
│   └── form_screen.dart         # Renderizado dinámico de formulario
└── widgets/
```

### Capas

| Capa | Responsabilidad |
|---|---|
| **models** | Definición de esquemas de datos persistentes (HiveObject) |
| **services** | Lógica de negocio: autenticación, base de datos, plantillas |
| **screens** | UI y manejo de estado con `setState` |
| **templates** | Constantes JSON que simulan respuestas de servidor |

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

### Formulario Dinámico: "Ficha del Agricultor"
- Plantilla JSON hardcodeada con 7 campos de diferentes tipos:
  - Texto corto (nombre del agricultor)
  - Numero (cédula, hectáreas)
  - Fecha (fecha de registro)
  - Dropdown (estado de la finca, variedad de cacao)
  - Switch (asistencia técnica urgente)
- Renderizado automático según el `type` de cada campo
- Validación de campos obligatorios
- Al guardar: serialización a JSON, persistencia en Hive con timestamp

### Almacenamiento Local
- Las respuestas se guardan en una caja Hive (`form_responses`)
- Cada registro incluye: ID autoincremental, templateId, respuestas, timestamp
- Confirmación visual mediante SnackBar

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
