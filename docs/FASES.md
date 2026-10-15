# Informe por fases

Este documento recoge, fase a fase, **qué está implementado y funcionando**, **qué pruebas se
hicieron** y **qué falta**. Solo se marca como hecho lo que funciona en el juego (no basta con que
exista una interfaz o una animación).

Entorno de desarrollo y pruebas: Debian 12 x86_64 en contenedor, **sin GPU** (sin OpenGL). Godot
4.7.2 compilado desde el código fuente oficial (editor y plantilla release). Las pruebas visuales se
hicieron con un binario de pruebas propio que renderiza con Vulkan (renderizador *Mobile*) sobre
SwiftShader (CPU), porque el renderizador *Compatibility* (OpenGL 3.3) que usa el juego no puede
ejecutarse sin GPU en este entorno. La lógica (física, IA, guardado, etc.) es la misma en ambos.

---

## Fase 1 — Prototipo jugable · **COMPLETADA**

**Implementado**
- Proyecto Godot 4.7 (GDScript tipado, renderizador Compatibility, Jolt Physics), ejecutable nativo
  Linux x86_64 exportado y probado.
- Zona medieval voxel detallada: aldea de Hojarrubia (posada de dos plantas con barra, mesas y camas;
  casas con entramado de madera, ventanas con marco, chimeneas con humo; tejados de teja y de paja;
  herrería con fragua, yunque y armero; torre con escalera de caracol y almenas; muralla con puerta y
  adarve; pozo; puestos de mercado; huerto; farolas), ruinas de capilla y cementerio.
- Jugador en primera persona con **brazos visibles** (esqueleto con piel e IK de dos huesos) y
  **espada 3D**; animaciones de reposo con respiración, ataques (tres tajos distintos + estocada),
  impacto recibido, bloqueo, golpe en bloqueo, desenvainar y recuperación con fundidos.
- **Enemigo 3D**: guerrero esqueleto con reposo, caminar, correr, alerta, dos ataques, bloqueo con
  escudo, reacción a golpes, aturdimiento y muerte (AnimationTree con máquina de estados).
- Detección **real** de impactos: rayos que barren el arco de cada ataque durante su ventana activa;
  los ataques enemigos comprueban distancia, ángulo y línea de visión en el instante del golpe.
- Salud del jugador y del enemigo; HUD (barras, brújula, punto de mira, enemigo apuntado, avisos).
- Iluminación con sol y sombras, antorchas con parpadeo, niebla, cielo; sonido de impacto y demás
  efectos sintetizados.
- Menú principal (con diorama 3D animado), controles documentados, todo sin conexión.

**Pruebas**
- `tools/dev/check_scripts.tscn`: carga y compila los 83 scripts/escenas/recursos/shaders → 0 errores.
- Autoprueba de juego (`--self-test` / `tools/dev/smoke_test.tscn`), superada en el editor **y con el
  binario exportado**: el mundo carga (~2 s), el jugador aparece sobre el suelo, camina y salta, un
  esqueleto lo detecta, combate (el jugador recibe daño, el esqueleto bloquea), el esqueleto muere,
  se saquea, se guarda y se carga (posición exacta y enemigo muerto persistentes).
- Revisión visual con capturas automáticas (aldea, interiores, noche, ruinas, poses de animación).
- Fallos encontrados y corregidos gracias a las pruebas: brazos inestables a pocos FPS, enemigo que
  aparecía dentro de una lápida y caía bajo el terreno, rebotes del arma contra paredes en espacios
  estrechos, combate que bloqueaba al enemigo en un aturdimiento continuo (añadido aguante postural).

## Fase 2 — Calidad visual y animaciones · **MAYORMENTE HECHA**

**Implementado**
- Cuatro armas cuerpo a cuerpo (espada, hacha, maza, daga) con modelos y **animaciones propias** de
  primera persona (las de hacha y maza más lentas y pesadas, la daga con estocadas rápidas), ataques
  direccionales según el movimiento, escudo con capa de animación independiente (bloqueo con escudo).
- **Arco** con tensado, mantenimiento, disparo y cuerda dinámica; **flechas físicas** con gravedad
  que se clavan en el escenario; munición en el inventario.
- **Magia**: bola de fuego (daño de área y quemadura), rayo de escarcha (ralentiza) y curación, con
  coste de magia, gesto de la mano y partículas. Estados alterados: quemadura, escarcha, veneno.
- Arquero esqueleto con IA a distancia (mantiene la distancia, apunta con predicción, dispara).
- Modelos voxel de personajes (esqueletos, aldeanos con pelo, barba, delantal, armadura, capa),
  jefe con corona y peto; mobiliario detallado; partículas de chispas, hueso, sangre, polvo y fuego.
- Ciclo de día y noche, nubes voxel, estrellas, viñeta de daño, balanceo de cámara y retroceso.

**Falta**
- Animaciones de personajes para más criaturas (lobos, arañas...) y modelos de armadura equipable.
- Volumetría/AO de pantalla no disponibles en el renderizador Compatibility (se usa AO por vértice).

## Fase 3 — Región procedural · **HECHA (región inicial)**

**Implementado**
- Terreno procedural con semilla reproducible: continentes, colinas, montañas, ríos; biomas (bosque
  templado, abedular, llanura, taiga, montaña nevada, pantano, desierto, tierras rocosas, costa).
- Carga y descarga por **chunks** en hilos de trabajo alrededor del jugador (nunca todo el mundo en
  memoria); vegetación y rocas deterministas; caminos y zonas niveladas para las construcciones.
- **Mazmorra conectada** (cripta de Velmar) bajo la capilla: salas en cuadrícula unidas por árbol de
  expansión con bucles, sala del jefe (la más profunda), tesoros en callejones sin salida, sala
  secreta tras una pared falsa examinable, puerta cerrada cuya llave está garantizadamente antes de la
  puerta, reja abierta con palanca, trampas de pinchos visibles, braseros, sarcófagos, telarañas,
  **verificación de conectividad** y rutas A* para los enemigos; entrada y regreso al exterior.
- Semilla guardada en la partida.

**Pruebas**: la autoprueba entra en la mazmorra, comprueba la verificación, la ruta hasta el jefe,
la presencia del jefe y el regreso al exterior junto a la entrada.

**Falta**: más asentamientos procedurales y mazmorras repartidas por la región (fase 6).

## Fase 4 — Sistemas RPG y guardado · **HECHA (base completa)**

**Implementado**: atributos con efectos reales (daño, salud, aguante, velocidad, críticos, precios),
16 habilidades que mejoran con el uso y suben de nivel, salud/aguante/magia con regeneración, clases
iniciales, inventario con peso (sobrecarga ralentiza), usar/equipar/soltar (persistente y sin
duplicados), oro, comercio con precios según habilidad, personalidad y reputación, tablas de botín,
ficha de personaje, guardado/carga versionado, validado y atómico con copia de seguridad.

**Falta**: armaduras y ropa equipables por ranuras (cabeza, torso, manos...) con resistencias.

## Fase 5 — PNJ, misiones y facciones · **HECHA (aldea inicial)**

**Implementado**: 5 PNJ con nombre, función, modelo propio, horario (trabajo, casa por la noche,
patrulla con farol), animaciones de hablar/trabajar/saludar; diálogos con saludos según reputación,
rumores, ofertas y seguimiento de misiones; 4 misiones de tipos distintos (matar, explorar,
recuperar, entregar) con etapas, estado persistente y recompensas (oro, objetos, reputación);
2 facciones con reputación que afecta a saludos, disponibilidad de misiones y precios; diario.

**Falta**: más misiones generadas, guardias que reaccionen a delitos, PNJ en otros asentamientos.

## Fase 6 — Expansión del mundo · **PENDIENTE**
Más asentamientos (pueblos, castillos, posadas de camino), mazmorras por región, nuevas criaturas,
cuevas y puentes.

## Fase 7 — Pulido y distribución · **PARCIAL**

**Implementado**: exportación reproducible (`scripts/export_linux.sh`), paquete `.tar.xz` con
lanzador, instalador de usuario y entrada de menú (`scripts/package_linux.sh`), script de AppImage
(requiere `appimagetool`), binario compatible con glibc ≥ 2.35, autoprueba integrada, README con
instalación, controles y solución de problemas.

**Falta / no verificado**: pruebas en hardware real con GPU y en Arch, Ubuntu y Mint; generación del
AppImage (no había `appimagetool` en el entorno); medición de rendimiento real.
