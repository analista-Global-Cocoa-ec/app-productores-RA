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
│   ├── finca.dart                   # Modelo Hive para fincas registradas
│   └── usuario.dart                 # Usuario autenticado y perfiles
├── services/
│   ├── auth_service.dart            # Autenticación offline con usuarios y perfiles
│   ├── database_service.dart        # Persistencia local con Hive y metadatos de sync
│   ├── firestore_service.dart       # Inicialización y acceso a Firestore
│   ├── sync_service.dart            # Sincronización bidireccional y resolución de conflictos
│   ├── sync_utils.dart              # IDs deterministas, hashes y sanitización
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
| `firebase_core` | Inicialización de Firebase en Android y Web |
| `cloud_firestore` | Sincronización de respuestas con Firestore |
| `connectivity_plus` | Detección de recuperación de conexión a internet |
| `flutter_form_builder` | Renderizado dinámico y validación de campos de formulario |
| `intl` | Formato de fechas localizado |
| `crypto` | Hashing SHA-256 de contraseñas |
| `uuid` | Generación de IDs únicos |
| `path_provider` | Directorio de documentos de la app |

---

## Funcionalidades

### Autenticación Offline

La app crea automáticamente dos usuarios si aún no existen:

| Usuario | Contraseña | Perfil |
|---|---|---|
| `admin` | `password123` | Administrador |
| `tecnico` | `tecnico123` | Tecnico |

- **Ambos perfiles tienen acceso por ahora a las mismas fincas, formularios y a la colección `formularios-fincas`.**
- El perfil del usuario autenticado se muestra en el menú principal y se puede consultar desde `AuthService.instance.esAdministrador` / `esTecnico`, para futuras restricciones de acciones exclusivas del Administrador:
  ```dart
  if (AuthService.instance.esAdministrador) {
    // Mostrar o habilitar una acción exclusiva del Administrador.
  }
  ```
- El menú principal incluye un botón para **cerrar sesión** y cambiar de usuario.
- Las contraseñas se almacenan hasheadas con SHA-256, nunca en texto plano.
- Los usuarios se guardan en `flutter_secure_storage`; si la app tenía el usuario único anterior, sus credenciales se migran automáticamente al perfil Administrador.
- Validación con feedback visual de error e ícono para mostrar/ocultar contraseña.

> Estas credenciales son valores por defecto de desarrollo. Para producción deben cambiarse y combinarse con Firebase Anonymous Auth (ver más abajo).

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
- Cada registro incluye: templateId compuesto, respuestas, timestamp y metadatos de sincronización
- Al editar un formulario existente, se actualiza el registro en lugar de crear uno nuevo
- Se retorna siempre el registro más reciente por finca + formulario

### Sincronización con Firestore

La app es **local-first**: Hive sigue siendo la fuente de verdad y Firestore es la capa de nube. Si no hay conexión o la plataforma no tiene Firebase configurado, todo sigue funcionando localmente.

**Cuándo se sincroniza:**
- Al pulsar **Guardar** en un formulario: primero se guarda en Hive y luego se intenta subir a Firestore sin bloquear la UI.
- Al iniciar la app: se suben los registros locales pendientes y se descargan los cambios hechos en la nube.
- Al recuperar la conexión a internet (`connectivity_plus`): se ejecuta una sincronización completa y se muestra un aviso global con el resultado, sin importar en qué pantalla esté el usuario.
- Manualmente con el botón de nube (`cloud_sync_outlined`) en la pantalla de formularios de una finca.

Las pantallas de **Actualizar Finca** y de formularios se refrescan automáticamente cuando termina una sincronización, para mostrar las fincas o respuestas descargadas sin necesidad de salir y volver a entrar.

**Cómo se identifican los documentos:**
- ID determinista: `{fincaCodigo}_{templateId}` (ej. `BAB-002_registro_cosecha`).
- La barra `/` se reemplaza por `-` para que sea un ID válido.

**Esquema del documento en `formularios-fincas`:**

| Campo | Tipo | Descripción |
|---|---|---|
| `fincaCodigo` | string | Código único de la finca (ej. `BAB-002`) |
| `nombreAgricultor` | string | Nombre del productor |
| `canton` | string | Cantón de la finca |
| `templateId` | string | ID base de la plantilla (ej. `registro_cosecha`) |
| `templateTitulo` | string | Título legible del formulario |
| `respuestas` | map | Respuestas del formulario |
| `hashRespuestas` | string | SHA-256 canónico de `respuestas` |
| `actualizadoEn` | timestamp | Marca del servidor (`FieldValue.serverTimestamp()`) |
| `actualizadoLocalEn` | string (ISO-8601) | Marca del dispositivo, usada para conflictos |
| `versionEsquema` | number | Versión del esquema (actualmente `1`) |
| `origen` | string | `app-productores-RA` |

**Resolución de conflictos:**
- Si el hash local y el remoto coinciden, no se escribe nada.
- Si difieren, gana el registro con `timestamp` más reciente (local vs. `actualizadoLocalEn` remoto). Es una política *last-write-wins* por formulario completo.
- Si las fechas son iguales, se prioriza el registro local que aún no estaba sincronizado.
- Si un documento remoto referencia una finca que no existe localmente, se crea una finca placeholder para no perder la respuesta.

**Documento dummy:**
Firestore elimina una colección cuando se borra su último documento. Para evitarlo se puede mantener un documento como `{ "saludo": "Hola mundo" }`. La app lo **ignora** porque no cumple el esquema (`fincaCodigo`, `templateId` y `respuestas` son obligatorios).

---

## Configuración de Firebase / Firestore

1. Tener instalado el CLI de Firebase y haber iniciado sesión:
   ```bash
   npm install -g firebase-tools
   firebase login
   ```
2. Instalar el CLI de FlutterFire:
   ```bash
   dart pub global activate flutterfire_cli
   ```
   > Si el comando `flutterfire` no se reconoce, agrega el directorio de binarios globales de Dart al `PATH`:
   > en Windows suele ser `%LOCALAPPDATA%\Pub\Cache\bin` y en macOS/Linux `~/.pub-cache/bin`.
3. El proyecto ya está vinculado a `app-productores-ra` mediante FlutterFire:
   - `lib/firebase_options.dart` (Android y Web)
   - `android/app/google-services.json`
   - `firebase.json`

   Si necesitas regenerar la configuración:
   ```bash
   flutterfire configure --project=app-productores-ra
   ```
4. Publicar las reglas de Firestore:
   ```bash
   firebase deploy --only firestore:rules
   ```
   El archivo `.firebaserc` ya apunta al proyecto `app-productores-ra`.
5. Verificar que la colección `formularios-fincas` exista en la consola de Firebase.

### ⚠️ Reglas abiertas (solo desarrollo)

`firestore.rules` permite actualmente lectura y escritura **sin autenticación** únicamente en `formularios-fincas`. Esto es aceptable mientras se prueba, pero **no debe usarse en producción**: cualquiera con la configuración de la app podría leer o modificar los datos.

### Recomendación: Firebase Anonymous Auth

Antes de publicar, se recomienda:

1. Habilitar **Authentication → Sign-in method → Anonymous** en la consola de Firebase.
2. Inicializar sesión anónima al arrancar la app (por ejemplo en `SyncService.initialize()`):
   ```dart
   import 'package:firebase_auth/firebase_auth.dart';

   if (FirebaseAuth.instance.currentUser == null) {
     await FirebaseAuth.instance.signInAnonymously();
   }
   ```
   Agregar la dependencia con `flutter pub add firebase_auth`.
3. Endurecer `firestore.rules` para exigir usuario autenticado:
   ```javascript
   match /formularios-fincas/{docId} {
     allow read, write: if request.auth != null;
   }
   ```
4. Opcional: vincular la cuenta anónima con un usuario real más adelante (`linkWithCredential`) para conservar los datos.

---

## Ejecución

```bash
# Instalar dependencias
flutter pub get

# Generar código (adaptadores Hive)
dart run build_runner build --delete-conflicting-outputs

# Ejecutar en Android
flutter run -d <dispositivo_android>

# Ejecutar en Chrome
flutter run -d chrome
```

> La sincronización con Firestore está configurada solo para **Android** y **Web**.
> En iOS/desktop la app funciona en modo local (Hive), ya que `firebase_options.dart`
> no incluye configuración para esas plataformas.

---

## Solución de problemas

### Android: `Package ndk not found. Package 28.2.13676358 not found.`

Este error aparece al ejecutar `flutter run` cuando Flutter requiere el **NDK 28.2.13676358**
(valor de `flutter.ndkVersion` en `android/app/build.gradle.kts`) y no está instalado en el
equipo. Flutter intenta instalarlo automáticamente con `sdkmanager`, pero las versiones nuevas
de los `cmdline-tools` (Android CLI) ya no aceptan la sintaxis antigua `ndk;28.2.13676358`,
por eso la instalación falla.

La solución es instalar el NDK manualmente con una de estas dos opciones:

#### Opción 1: Desde Android Studio

1. Abrir **Android Studio**.
2. Ir a **More Actions → SDK Manager** (o **Settings → Languages & Frameworks → Android SDK**).
3. En la pestaña **SDK Tools**, marcar **Show Package Details**.
4. Expandir **NDK (Side by side)** y seleccionar la versión **28.2.13676358**.
5. Pulsar **Apply**, aceptar las licencias y esperar la descarga.
6. Volver al proyecto y ejecutar:
   ```bash
   flutter clean
   flutter run
   ```

#### Opción 2: Desde la terminal

**Windows (PowerShell):**

Con los `cmdline-tools` nuevos (Android CLI), la sintaxis usa `/`:
```powershell
& "$env:LOCALAPPDATA\Android\sdk\cmdline-tools\latest\bin\android.exe" sdk install 'ndk/28.2.13676358'
```

Si aún tienes los `cmdline-tools` antiguos (con `sdkmanager`), usa:
```powershell
& "$env:LOCALAPPDATA\Android\sdk\cmdline-tools\latest\bin\sdkmanager.bat" "ndk;28.2.13676358"
```

**macOS / Linux:**

```bash
# cmdline-tools nuevos (Android CLI)
"$ANDROID_HOME/cmdline-tools/latest/bin/android" sdk install 'ndk/28.2.13676358'

# cmdline-tools antiguos (sdkmanager)
"$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" "ndk;28.2.13676358"
```

Si el SDK está en otra ruta, reemplaza `$env:LOCALAPPDATA\Android\sdk` o `$ANDROID_HOME`
por la ruta correspondiente.

#### Verificar la instalación

Windows (PowerShell):
```powershell
Test-Path "$env:LOCALAPPDATA\Android\sdk\ndk\28.2.13676358"
```

macOS / Linux:
```bash
ls "$ANDROID_HOME/ndk/28.2.13676358"
```

Debe devolver `True` o listar el contenido del directorio. Luego ejecutar:
```bash
flutter clean
flutter run
```

> **Alternativa:** si ya tienes otro NDK instalado, puedes fijar esa versión explícitamente en
> `android/app/build.gradle.kts`:
> ```kotlin
> ndkVersion = "27.0.12077973"
> ```
> No se recomienda quitar la línea `ndkVersion`, ya que algunos plugins con código nativo la
> necesitan.

---

## Plataformas Soportadas

| Plataforma | Estado |
|---|---|
| Android | Funcional (local + Firestore) |
| Web (Chrome) | Funcional (local + Firestore) |
| iOS | Local (sin Firestore configurado) |
| Desktop | Local (sin Firestore configurado) |
