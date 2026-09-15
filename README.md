# DriveRD VR

Simulador de conducción defensiva en realidad virtual ambientado en Santo Domingo, República Dominicana. Es material educativo para Meta Quest 2/3, no un juego de carreras: el jugador empieza con **1000 puntos** y su trabajo es defenderlos.

- Motor: Godot 4.7.2 (GDScript, renderer de compatibilidad)
- XR: OpenXR + plugin Godot OpenXR Vendors 5.1.0 (Meta)
- Paquete Android: `do.driverd.vr`, solo arm64-v8a

---

## 1. Arquitectura

Toda la geometría (ciudad, carros, cabina, personas) se genera por código con primitivas y color por vértice, así que el proyecto no trae modelos 3D, texturas ni audio de terceros.

| Script | Responsabilidad |
|---|---|
| `scripts/main.gd` | Orquestador y máquina de estados: carga → menú → manejando ⇄ pausa → resumen. Conecta tráfico, puntuación, tablero y confort. |
| `scripts/player_vehicle.gd` | Modelo de manejo cinemático: pedales con recorrido, freno de ~8 m/s², dirección tipo bicicleta con límite de agarre lateral (el giro pierde respuesta con la velocidad). Solo guiñada, la cabina nunca se inclina. |
| `scripts/cabin.gd` | Cabina completa: tablero, volante, palanca, puertas, pilares, techo, capó, espejos. Una sola cámara trasera alimenta el retrovisor y los dos laterales. |
| `scripts/dashboard_display.gd` | Cuadro de instrumentos dibujado en una textura: velocímetro, tacómetro, indicador de DEFENSA, puntos, avenida, luces de alerta y avisos. |
| `scripts/xr_rig.gd` | OpenXR, mandos, volante virtual, recentrado, puntero de menús y modo escritorio de respaldo. |
| `scripts/road_manager.gd` + `segment_builder.gd` | Avenida infinita por tramos reciclados (ver abajo). |
| `scripts/traffic_manager.gd` + `traffic_agent.gd` | Motoconchos, guaguas, carros, peatones y tráfico en sentido contrario; medición de rebases, puntos ciegos y frenado anticipado. |
| `scripts/drive_score.gd` | Todas las reglas de puntuación como constantes, estadísticas y resumen. |
| `scripts/comfort_vignette.gd` + `shaders/vignette.gdshader` | Viñeta dinámica y fundidos a negro. |
| `scripts/performance_governor.gd` | Baja calidad antes que perder cuadros. |
| `scripts/menu_ui.gd`, `ui_panel_3d.gd`, `flag_rect.gd` | Panel flotante con menú, ayuda, pausa y resumen. |
| `scripts/audio_kit.gd` | Motor, motos, avisos y choque, sintetizados por código. |
| `scripts/autopilot.gd` | Solo para pruebas: maneja sin visor (modo prudente o agresivo). |

### Avenida infinita con memoria constante
- Al cargar se generan **3 variantes por avenida** (12 mallas). Cada tramo de 50 m es **una sola malla** para la parte estática y otra superficie para las banderas, que ondean por shader. Eso da pocos draw calls.
- En juego existen solo **13 nodos de tramo**. Cuando uno queda atrás se recicla delante con la malla que le toca; mientras se maneja no se crea ni se destruye geometría.
- Cada 600 m cambia la avenida (Independencia → 27 de Febrero → John F. Kennedy → Máximo Gómez), con un pórtico que muestra su nombre.
- Cada 500 m todo el mundo se desplaza hacia atrás (*rebase* de origen) para que las coordenadas no crezcan y no haya temblores de precisión en VR tras varios kilómetros.

### Confort en VR
- **72 fps como piso**: `performance_governor.gd` mide el tiempo real de frame y, si se pasa del presupuesto, baja en este orden: frecuencia de los espejos, distancia de dibujo con niebla, densidad de tráfico. Si hay margen durante 25 s, intenta subir un nivel. Además se usa foveated rendering dinámico de OpenXR y 72 Hz en el visor.
- **Viñeta dinámica**: oscurece la periferia según la aceleración, el frenado y la velocidad de giro. Se calcula por ángulo respecto al eje de cada ojo, así queda centrada en ambos. Tiene tres intensidades en el menú.
- **Cabina fija**: es hija del carro y ocupa toda la periferia. No hay sacudidas, cabeceo, balanceo ni temblor de cámara, y el horizonte no se inclina en curvas.
- **Choques sin tirón visual**: la pantalla se funde a negro antes de detener el carro.
- **Recentrado** con B o Y en cualquier momento. También responde al recentrado del sistema de Quest.

---

## 2. Correr el proyecto en el editor

```bash
godot --path . -e
```

Pulsa F5. Sin visor conectado, el juego arranca en **modo simulador de escritorio**:

| Tecla | Acción |
|---|---|
| W / ↑ | Acelerar |
| S / ↓ / Espacio | Frenar |
| A D / ← → | Dirigir |
| Clic derecho + ratón | Mirar alrededor |
| Clic izquierdo / Enter | Pulsar botón del menú |
| R | Recentrar |
| Esc / M | Pausa |

Con un runtime OpenXR activo en la PC (Meta Quest Link, SteamVR o Meta XR Simulator), el mismo proyecto arranca en VR.

### Controles en el visor
- **Mandos**: gatillo derecho acelera, gatillo izquierdo frena, joystick izquierdo dirige.
- **Volante virtual**: agarra el aro con los botones de agarre de ambos mandos y gíralo físicamente (hasta ±135°, con autocentrado al soltar). Los gatillos siguen siendo acelerador y freno.
- **Menú**: apunta y aprieta el gatillo, o usa el joystick arriba/abajo y el botón A.

### Pruebas automáticas
```bash
# Física, reglas de puntuación, reciclaje de tramos, memoria y recorridos completos
godot --headless --path . -s tests/test_game.gd

# Recorrido en ventana con piloto automático, métricas y capturas
godot --path . -- --autopilot --duration=75 --quit --perf --shots=tests/out/shots

# Conductor agresivo (verifica penalizaciones)
godot --path . -- --autopilot --aggressive --duration=90 --quit
```
Cada recorrido guarda su resumen y la lista de eventos en `user://resumenes/recorrido_*.json`.

---

## 3. Reconstruir el APK desde cero

### Requisitos
- Godot 4.7.2 y sus export templates 4.7.2 (tienen que ser la misma versión)
- Java 17 (Temurin)
- Android SDK: `platform-tools`, `platforms;android-34`, `platforms;android-36`, `build-tools;34.0.0`, `build-tools;36.1.0`, `ndk;29.0.14206865`
  - Godot 4.7.2 compila con compileSdk 36, build-tools 36.1.0 y NDK 29; las versiones 34 se incluyen por compatibilidad.
- Plugin OpenXR Vendors 5.1.0 en `addons/godotopenxrvendors/` (ya viene en el repositorio)

`sh tools/verify_env.sh` comprueba todo lo anterior.

### Configuración del editor (por archivo)
En `editor_settings-4.7.tres`:
```
export/android/android_sdk_path = "<ruta al SDK>"
export/android/java_sdk_path = "<ruta al JDK 17>"
export/android/debug_keystore = "<ruta>/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
```
El keystore de debug estándar se crea con:
```bash
keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android -keystore debug.keystore -storepass android -dname "CN=Android Debug,O=Android,C=US" -validity 9999 -deststoretype pkcs12
```

### Export de debug
```bash
godot --headless --path . --install-android-build-template --export-debug "Meta Quest" build/driverd-vr-debug.apk
aapt dump badging build/driverd-vr-debug.apk | head -30
```
El preset `Meta Quest` (`export_presets.cfg`) usa build Gradle, XR mode OpenXR, plugin de Meta activado, soporte Quest 2/3/Pro, solo arm64, modo inmersivo y ningún permiso extra.

### Export de release (firmado)
Las credenciales **nunca** se escriben en el repositorio. Godot las lee de variables de entorno:
```bash
export GODOT_ANDROID_KEYSTORE_RELEASE_PATH=/ruta/driverd-release.keystore
export GODOT_ANDROID_KEYSTORE_RELEASE_USER=driverd
export GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=...   # la escribe quien firma, en su terminal
godot --headless --path . --export-release "Meta Quest" build/driverd-vr-release.apk
```

---

## 4. Decisiones de diseño desde la seguridad vial

Esta sección sustenta el proyecto ante el jurado: qué enseña cada mecánica y qué mide cada número.

### Por qué el motoconcho es la mecánica central
En la vía urbana dominicana la motocicleta es el vehículo más expuesto y el más presente en el tráfico cotidiano, y el motoconcho (moto de transporte de pasajeros) define buena parte de cómo se maneja en la ciudad. El conductor de carro no puede controlar al motoconcho, pero **sí puede controlar el espacio que le deja**. Por eso el juego no castiga que la moto se meta; castiga cómo reacciona el conductor:

- Las motos cambian de trayectoria cada **0.7–2 s** sin señalizar, se meten entre carriles y entre vehículos, y aparecen **por el punto ciego derecho**.
- Cuando el jugador rebasa una moto, el juego mide la **separación lateral real, de borde a borde**, mientras van lado a lado:
  - **Más de 1.6 m y menos de 85 km/h**: suma puntos y muestra la distancia lograda ("Rebase seguro: 2.1 m").
  - **1.6 m o menos**: resta puntos ("¡Pasaste pegao!").
  - Con espacio pero a 85 km/h o más: no suma, y avisa que ibas muy rápido.
- Como la moto va a veces sobre la raya entre carriles, en muchos casos **la única forma de dejarle 1.6 m es no rebasar todavía**. Esa es justamente la lección: si no cabe con espacio, se espera.
- El tablero enciende **MOTO LADO** y un testigo naranja en el espejo cuando hay una moto en el punto ciego. El sonido de cada moto es posicional, así que se oye llegar por detrás. Esto entrena el hábito de mirar espejos antes de moverse de carril.
- Una moto nunca se estrella sola contra el jugador. Si hay choque, es porque el jugador se le cerró o la alcanzó por detrás.

### Qué enseña cada riesgo
| Riesgo | Comportamiento | Lección |
|---|---|---|
| **Guaguas** | Frenan sin aviso para recoger pasajeros; la luz de freno se enciende apenas 0.45–0.8 s antes y se orillan a medio carril. | Distancia de seguimiento: con menos de 1 s de separación no hay tiempo de reaccionar. Se premia frenar antes de que la guagua te obligue. |
| **Peatones** | Salen de entre carros estacionados, fuera del paso peatonal, cuando el carro está a 3–5 s. | Velocidad compatible con lo que no se ve. Se premia ceder el paso; atropellar es la penalización más alta. |
| **Sentido contrario** | Tráfico real en los carriles opuestos. | Rebasar invadiendo el carril contrario convierte un adelantamiento en un choque frontal. |
| **Velocidad** | El giro pierde respuesta y la distancia de frenado crece con la velocidad (física del carro). | La velocidad no solo es multa: quita margen para esquivar y para frenar. |

### Qué mide cada categoría de la puntuación
Todos los valores están en `scripts/drive_score.gd`.

**Suma**
| Conducta | Puntos | Qué indica |
|---|---|---|
| Rebase a un motoconcho con más de 1.6 m y bajo 85 km/h | +25 | Respeto al usuario vulnerable |
| Cada 20 s continuos bajo 80 km/h (en movimiento y sin otra conducta de riesgo) | +5 | Velocidad sostenida prudente |
| Frenar mientras el tiempo a colisión con el de adelante aún es mayor de 2.5 s | +15 | Anticipación en vez de reacción |
| Ceder el paso a un peatón | +20 | Prioridad al peatón |
| Completar un tramo de 600 m | +50 | Constancia |

**Resta**
| Conducta | Puntos | Qué indica |
|---|---|---|
| Exceso de velocidad sobre 90 km/h | −5 por segundo | Exposición sostenida |
| Rebase pegao a un motoconcho (≤ 1.6 m) | −40 | Riesgo directo al motorista |
| Invadir el carril contrario | −10 al entrar, −8 por segundo | Riesgo de choque frontal |
| Salirse de la calzada | −15 al salir, −8 por segundo | Pérdida de control |
| Chocar con un vehículo o la acera | −150 | Siniestro |
| Atropellar a un peatón | −300 | Siniestro con víctima vulnerable |

Un choque solo se le cuenta al jugador si él lo provocó: si está detenido, o si lo chocan por detrás, no pierde puntos.

**Indicador DEFENSA (0–100 %)**: no son puntos. Sube despacio con conducción prudente y cae rápido con cualquier riesgo. Da una lectura inmediata de "cómo voy" sin quitar la vista de la vía.

**Resumen final (cifras citables)**: kilómetros recorridos, rebases seguros y pegaos a motoconchos, menor separación medida con una moto, velocidad máxima, **segundos acumulados en conducta de riesgo** (exceso de velocidad, contravía, fuera de calzada o seguir a menos de 1 s del de adelante), choques, peatones a los que se cedió el paso y frenadas anticipadas. Todo se guarda también en JSON para tabular resultados de varias personas.

> Los umbrales de 80 y 90 km/h son parámetros de diseño del ejercicio. Para representar una vía específica, ajústalos en `drive_score.gd` al límite señalizado de esa vía.

---

## 5. Estado de las pruebas (honesto)

- **Automatizadas (headless)**: física del carro, cada regla de puntuación, reciclaje de tramos con cantidad de nodos constante durante más de 6 km, rebase de coordenadas, tráfico acotado y recorrido de 4 tramos. Resultado: 29/29.
- **En ventana, modo simulador de escritorio** (Intel UHD, renderer de compatibilidad): recorridos completos con piloto automático y capturas; menú, tablero, espejos, puntos ciegos y resumen verificados visualmente.
- **Pendiente**: prueba en un Quest físico o con el Meta XR Simulator. El simulador requiere cuenta de desarrollador de Meta, así que no se pudo instalar en este entorno. En el visor falta confirmar la sensación de escala, el volante virtual con mandos reales y los 72 fps en el hardware del Quest 2.

## 6. Créditos y referencias
- Todo el código fue escrito para este proyecto; no se copió código de otros proyectos.
- Documentación consultada: manual de Godot (OpenXR, `XRController3D`, `SubViewport`, export a Android) y la documentación del plugin Godot OpenXR Vendors. La técnica de proyectar una interfaz 2D en un plano 3D y enviarle eventos de ratón sigue la idea del demo oficial "GUI in 3D" de Godot, con implementación propia.
- El plugin `addons/godotopenxrvendors` es de GodotVR y conserva sus licencias (incluidas en la carpeta).
