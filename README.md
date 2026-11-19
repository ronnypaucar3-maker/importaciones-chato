# Importaciones Chato

Sistema de inventario multiplataforma para Importaciones Chato, Chincha.
El proyecto está enfocado en Android y navegador web.

## Alcance implementado

- Inicio de sesión y recuperación de contraseña con Firebase Authentication.
- El perfil activo en `users/{uid}` determina las vistas de Administrador,
  Gerente, Caja y Pasillo.
- Catálogo en tiempo real con búsqueda, categorías, precios y stock mínimo.
  Los costos se guardan aparte en `productCosts/{productId}` y solo Gerencia
  puede consultarlos.
- Entradas, salidas y ajustes de existencias con historial inmutable en
  `stockMovements`.
- Caja con carrito, medios de pago, registro de ventas y descuento transaccional
  del stock en `sales`.
- Recepción de compras para Gerencia, incluyendo proveedor, comprobante, costo,
  unidades y el movimiento de inventario correspondiente en `purchases`.
- Resumen con productos activos, alertas de stock bajo, ventas del día y valor
  de inventario al costo. No hay cuentas ni indicadores de demostración.
- Campana e historial para Administrador y Gerente. Mientras la app está
  abierta, muestra notificaciones locales de productos registrados, entradas
  de stock y cruces a stock bajo; ese modo no requiere Cloud Functions.
- El Administrador puede crear cuentas de Caja y Pasillo y activar o desactivar
  esas cuentas desde la aplicación.
- Las cuentas se crean en una instancia secundaria de Firebase Authentication
  para no cerrar la sesión del Administrador. El perfil y su evento de auditoría
  se escriben en un mismo lote de Firestore.
- `firestore.rules` aplica permisos por rol, protege los campos de costo y los
  cambios de inventario, y bloquea la edición de ventas, compras y auditoría.

## Permisos por rol

| Rol | Acceso |
| --- | --- |
| Administrador | Resumen, catálogo, existencias, compras, caja, reportes y usuarios operativos |
| Gerente | Resumen, catálogo, existencias, compras, caja y reportes; sin gestión de cuentas |
| Caja | Caja/ventas, consulta de productos y su historial |
| Pasillo | Consulta de productos, registro de movimientos y su historial |

Las ventas, sus movimientos de stock y las recepciones se guardan en
transacciones de Firestore. Una venta se rechaza si el stock ya no alcanza.
Caja y Pasillo no tienen acceso de lectura a los costos de compra.

## Configuración de Firebase requerida

El proyecto Firebase confirmado es `importaciones-chato`. En Firebase Console:

1. En **Authentication → Proveedores nativos**, habilita **Correo electrónico /
   contraseña**.
2. Registra una app **Web** y una app **Android**. Para Android, el identificador
   de paquete actual es `com.example.flutter_application_1`.
3. Copia de la configuración de las apps el API key, el ID de aplicación web,
   el ID de aplicación Android y el número de proyecto (sender ID). Son valores
   de configuración del SDK cliente; no compartas contraseñas ni claves
   privadas.
4. Para **Android**, `android/app/google-services.json` ya incluye la
   configuración de la app Android existente; se carga automáticamente al
   ejecutar la aplicación. Para **web**, registra una app Web y configura sus
   valores al ejecutar Flutter usando `--dart-define`:

```shell
flutter run -d chrome `
  --dart-define=FIREBASE_PROJECT_ID=importaciones-chato `
  --dart-define=FIREBASE_API_KEY=API_KEY `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=SENDER_ID `
  --dart-define=FIREBASE_WEB_APP_ID=WEB_APP_ID `
  --dart-define=FIREBASE_ANDROID_APP_ID=ANDROID_APP_ID
```

En PowerShell, el acento grave al final de línea continúa el comando. Para
compilar Android, usa las mismas opciones:

```shell
flutter build apk --debug `
  --dart-define=FIREBASE_PROJECT_ID=importaciones-chato `
  --dart-define=FIREBASE_API_KEY=API_KEY `
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=SENDER_ID `
  --dart-define=FIREBASE_WEB_APP_ID=WEB_APP_ID `
  --dart-define=FIREBASE_ANDROID_APP_ID=ANDROID_APP_ID
```

Si aún no se registró la app Web, el inicio de sesión web muestra un aviso de
configuración pendiente y no intenta simular una autenticación. Android usa su
archivo nativo de Firebase y no requiere esos argumentos.

## Reglas, índices y notificaciones

Las reglas de Firestore no se instalan junto con el APK. Deben publicarse en
Firebase Console → proyecto `importaciones-chato` → **Firestore Database →
Rules**. Las reglas limitan los dispositivos y el historial remoto de
notificaciones a la cuenta Administradora o Gerente correspondiente. Luego abre
**Indexes**, crea o espera el índice compuesto de
`stockMovements(actorUid ASC, occurredAt DESC)` indicado en
`firestore.indexes.json`. Hasta publicar las reglas, las lecturas y escrituras
de productos, ventas, movimientos y usuarios pueden responder
`PERMISSION_DENIED`.

El modo gratuito escucha cambios recientes de Firestore mientras la app está
abierta y muestra las notificaciones localmente en el teléfono. No avisa cuando
la app está cerrada o el sistema la detiene. El historial de esos avisos se
guarda localmente en el dispositivo.

Los avisos push con la app cerrada son una opción distinta: requieren un proceso
de servidor que vigile cambios y los envíe mediante Firebase Cloud Messaging.
El código de Cloud Functions está en `functions/`; publicarlo requiere el plan
Blaze y habilitar facturación. No es necesario para los avisos locales gratuitos.

```shell
firebase deploy --only functions
```

Los avisos de producto incluyen el precio de venta; no exponen el costo de
compra. Firebase Admin SDK necesita Node.js 22 para desplegar las funciones.

## Primera cuenta Administrador

No hay registro público ni selección de rol. Para crear la primera cuenta:

1. En Authentication, crea el usuario inicial con correo y contraseña.
2. Copia su UID y crea manualmente en Firestore el documento
   `users/{UID}` con los campos:

```text
displayName: nombre real
email: correo de la cuenta
role: Administrador
active: true
```

3. Publica las reglas e índices actualizados desde la sección Rules / Indexes de
   Firestore, o con Firebase CLI después de iniciar sesión en el proyecto:

```shell
firebase deploy --only firestore
```

El Administrador inicial podrá crear usuarios de Caja y Pasillo desde el módulo
**Usuarios y permisos**. El rol Gerente se provisiona por separado y el
Administrador no puede asignarlo ni elevarse permisos. Los roles deben
escribirse exactamente como `Administrador`, `Gerente`, `Caja` o `Pasillo`.

Al comenzar en una base sin datos, crea al menos un producto desde **Productos**
antes de registrar ventas o compras. El stock inicial del producto también se
registra como movimiento de inventario.

## Ejecutar y verificar

```shell
flutter pub get
flutter analyze
flutter test
```

Para publicar la web, compila con los valores Firebase de arriba y despliega
Hosting con Firebase CLI:

```shell
flutter build web
firebase deploy --only hosting
```
