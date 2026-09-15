# Entrega · DriveRD VR v0.1.0

## Descarga directa

**APK (debug, Meta Quest 2/3):**
https://github.com/yefry08/DriveRD-VR/releases/download/v0.1.0/driverd-vr-debug.apk

Página del release: https://github.com/yefry08/DriveRD-VR/releases/tag/v0.1.0
Código fuente: https://github.com/yefry08/DriveRD-VR

> Es una versión **debug**, firmada con la clave de depuración estándar de Android. Sirve para instalarla por sideload en cualquier Quest con modo desarrollador. Cuando exista, la versión de distribución firmada se publicará en un release aparte.

---

## Requisitos del dispositivo
- Meta Quest 2, Quest 3 o Quest Pro (Quest 1 no es compatible)
- Modo desarrollador activado en la cuenta y en el visor
- Unos 100 MB libres
- Dos mandos Touch (el juego no usa seguimiento de manos)
- Se juega **sentado**, con espacio para mover los brazos si se usa el volante virtual

### Activar el modo desarrollador (una sola vez)
1. En la app **Meta Horizon** del teléfono, entra al visor vinculado → *Configuración del visor* → *Modo desarrollador* → activar. Meta puede pedir crear o verificar una cuenta de desarrollador gratuita.
2. Reinicia el visor.

---

## Instalación con SideQuest (recomendada, sin terminal)
1. Instala **SideQuest Advanced Installer** en tu computadora: https://sidequestvr.com/setup-howto
2. Conecta el Quest por cable USB‑C y ponte el visor: acepta **"Permitir depuración USB"** (marca *Permitir siempre desde esta computadora*).
3. En SideQuest, el indicador arriba a la izquierda debe estar en **verde**.
4. Descarga `driverd-vr-debug.apk` desde el enlace de arriba.
5. Arrastra el APK a la ventana de SideQuest, o usa el botón **"Install APK file from folder on computer"**.
6. En el visor: **Biblioteca → Aplicaciones → filtro "Orígenes desconocidos"** → **DriveRD VR**.

## Instalación por terminal (`adb`)
Con Android platform-tools instalados y el Quest conectado y autorizado:

```bash
adb devices
```
Debe aparecer el visor como `device` (si dice `unauthorized`, acepta el aviso dentro del visor).

```bash
adb install -r driverd-vr-debug.apk
```

Para abrirlo directamente desde la terminal:
```bash
adb shell monkey -p do.driverd.vr -c com.oculus.intent.category.VR 1
```

Para desinstalar:
```bash
adb uninstall do.driverd.vr
```

---

## Cómo se juega (resumen para quien lo prueba)
- **Gatillo derecho** acelera, **gatillo izquierdo** frena, **joystick izquierdo** dirige. En el menú se puede elegir el **volante virtual**: se agarra el aro con los botones laterales y se gira.
- **B o Y** recentran la vista; el **botón de menú** pausa.
- Se empieza con **1000 puntos**. Suman los rebases con más de 1.6 m a los motoconchos, ir bajo 80 km/h, frenar a tiempo, ceder el paso y completar tramos. Restan pasar de 90 km/h, rebasar pegao, la contravía, salirse de la calzada y chocar.
- La ruta corta recorre las avenidas Independencia, 27 de Febrero, John F. Kennedy y Máximo Gómez (2.4 km) y termina con un resumen de cifras.

---

## Párrafo para el correo

> **DriveRD VR** es un simulador de conducción defensiva en realidad virtual para Meta Quest, ambientado en avenidas de Santo Domingo como la Independencia, la 27 de Febrero, la John F. Kennedy y la Máximo Gómez. El conductor va sentado en una cabina completa y empieza con 1000 puntos que tiene que defender ante los riesgos reales de nuestra vía: motoconchos que se meten sin avisar y aparecen por el punto ciego, guaguas que frenan de golpe para recoger pasajeros, peatones que cruzan entre carros estacionados y tráfico en sentido contrario. La mecánica central mide en metros la separación con cada motoconcho al rebasarlo y premia dejar más de 1.6 m. Al final, el simulador entrega cifras concretas: kilómetros recorridos, rebases seguros, velocidad máxima y segundos acumulados en conducta de riesgo. No se gana llegando rápido: se gana manejando sin exponerse ni exponer a otros.
