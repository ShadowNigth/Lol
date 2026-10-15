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

- **Lobos** (fase 6): rig cuadrúpedo propio de 21 huesos y modelo voxel con 4 pelajes (gris, pardo,
  blanco de nieve y alfa negro con cicatriz); animaciones esqueléticas de reposo (respiración, jadeo,
  cola), paso en diagonal, galope con flexión de columna, alerta con gruñido, mordisco, salto con
  mordisco, golpe recibido, aturdimiento y muerte de costado, con la misma máquina de estados con
  fundidos que los humanoides.
- **Armadura visible** en primera persona: mangas de tela, jubón de cuero con remaches, cota de malla,
  túnica con ribete; manos desnudas, guantes de cuero o guanteletes de láminas; escudo redondo de
  madera y escudo de cometa de hierro.

**Falta**
- Más criaturas (arañas, bandidos humanos) y armadura visible en el modelo del cuerpo de los PNJ
  según su equipo (ahora se define por su apariencia).
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

- **Equipo por ranuras** (cabeza, torso, manos, piernas, pies y escudo): 14 piezas de ropa, cuero,
  hierro y escudos, más el yelmo único del Señor de Velmar (jefe de la cripta). Valor de armadura = base × (0,7 + habilidad/200)
  con las habilidades *armadura ligera/pesada*, que suben al recibir golpes con ella puesta; la
  armadura reduce el daño físico (daño × 100 / (100 + armadura)) y **no** el mágico, que se reduce
  con resistencias (fuego, escarcha, veneno, rayo) de ciertas piezas; bonificaciones (p. ej. +15 de
  magia máxima); el escudo equipado determina el bloqueo (80 % madera, 90 % hierro). Equipar saca la
  pieza del inventario y devuelve la anterior (sin duplicados); el peso del equipo cuenta en la
  carga; equipo inicial por clase; se guarda en la partida (con validación) y se ve en los brazos.

**Pruebas (equipo)**: la autoprueba comprueba el equipo inicial del guerrero (armadura 18,9), equipar
un yelmo (18,9 → 25,3), que 20 de daño cortante quedan en 16 y 20 de fuego siguen en 20, cambiar la
cota por la túnica (+15 de magia, 10 % de resistencia al fuego, la cota vuelve al inventario),
quitar y volver a poner el escudo y que todo se conserva al guardar y cargar.

**Falta**: piezas encantadas y desgaste/reparación del equipo.

## Fase 5 — PNJ, misiones y facciones · **HECHA (aldea inicial)**

**Implementado**: 5 PNJ con nombre, función, modelo propio, horario (trabajo, casa por la noche,
patrulla con farol), animaciones de hablar/trabajar/saludar; diálogos con saludos según reputación,
rumores, ofertas y seguimiento de misiones; 4 misiones de tipos distintos (matar, explorar,
recuperar, entregar) con etapas, estado persistente y recompensas (oro, objetos, reputación);
2 facciones con reputación que afecta a saludos, disponibilidad de misiones y precios; diario.

Fase 6 añade 4 PNJ más (Ulrico, Edda, Elena, Bram) en la posada del camino y en Robledal, una
facción nueva (Parroquia de Robledal), dos tiendas y 3 misiones (dos de caza y una de investigación
en el túmulo); la segunda de caza solo se ofrece con reputación suficiente con Robledal.

**Falta**: misiones generadas proceduralmente, guardias que reaccionen a delitos.

## Fase 6 — Expansión del mundo · **HECHA (región ampliada)**

**Implementado**
- **Planificador regional con semilla** (`StructurePlanner._plan_region`): para cada lugar prueba 24
  emplazamientos candidatos cerca de una zona objetivo y elige el más llano y seco, sin pisar lo ya
  reservado; nivela el terreno con transición suave, registra el nombre del lugar (aparece al
  entrar) y lo une con **caminos con quiebros** a la red existente. Los identificadores son fijos
  (misiones y partidas los encuentran siempre); las posiciones cambian con la semilla.
- **Posada del Lobo Gris** (oeste): posada de dos plantas con barra, establo, pozo, puesto y faroles;
  posadero Ulrico (tienda y misión) y la cazadora Edda (tienda de flechas y cuero, misión).
- **Aldea de Robledal** (sur): plaza con pozo, cuatro casas con estilos y tejados variados orientadas
  hacia la plaza, huerto y faroles; alcaldesa Elena (misión) y granjero Bram, con casa para la noche.
- **Túmulo de los Reyes Grises**: montículo de tierra con corredor de piedra (dolmen), antorchas y
  círculo de piedras erguidas, guardado por esqueletos; mazmorra con ambientación de túmulo (muros
  musgosos y tierra, suelo de guijarros) y jefe propio, *El Rey Gris*.
- **Cubil de Colmillo Negro**: risco rocoso con túnel oscuro; mazmorra de **cueva** (roca y grava,
  techo irregular, sin sarcófagos ni telarañas) llena de lobos, con el lobo alfa como jefe.
- **Mazmorras definidas por datos** (`DungeonDB`): nombre, ambientación, llave de entrada, jefe,
  guardias, esbirros y botín; llaves generadas para cada mazmorra.
- **Lobos**: nueva criatura con IA propia — merodean, detectan con un campo de visión amplio y buen
  oído, **avisan a la manada**, persiguen al galope, muerden o **saltan** (impulso físico real del
  cuerpo, no solo animación), **huyen** heridos y vuelven a la carga. Manadas generadas por chunk según
  el bioma (más en bosques y taiga, lobos blancos en zonas frías), lejos de aldeas y caminos;
  reaparecen a los 3 días. Pieles y colmillos como botín; sonidos sintetizados (gruñido, gañido,
  mordisco) y aullidos lejanos por la noche. El arma del jugador barre también a la altura de la
  cintura para alcanzar criaturas bajas (detección real por rayos contra su colisión).
- **Mapa regional** (tecla M) a 4 m por píxel con marcadores de aldeas, posadas y mazmorras y una
  leyenda con la dirección y distancia de cada lugar.

**Pruebas** (autoprueba, semilla de prueba): 6 lugares colocados en tierra firme (posada a ~200 m al
oeste, Robledal a ~280 m al sur, túmulo a ~370 m al sudeste, cubil a ~260 m al noroeste); el túmulo y
la cueva generan 25 salas y superan la verificación de conectividad; 6 lobos generados en los 81
chunks alrededor del cubil (81 chunks en ~1,3 s); combate real contra un lobo (muere en 3 golpes,
huyó herido, cuenta para la misión y deja botín); viaje a la posada y a Robledal con sus 4 PNJ
presentes y apoyados en el suelo; entrada en la cueva (lobos y alfa cargados) y salida al exterior.

**Falta**: castillos y ciudades amuralladas, puentes sobre ríos (los caminos cruzan por vados),
más tipos de mazmorra y una red de lugares que se extienda indefinidamente más allá de la región.

## Fase 7 — Pulido y distribución · **PARCIAL**

**Implementado**: exportación reproducible (`scripts/export_linux.sh`), paquete `.tar.xz` con
lanzador, instalador de usuario y entrada de menú (`scripts/package_linux.sh`), script de AppImage
(requiere `appimagetool`), binario compatible con glibc ≥ 2.35, autoprueba integrada, README con
instalación, controles y solución de problemas.

**Falta / no verificado**: pruebas en hardware real con GPU y en Arch, Ubuntu y Mint; generación del
AppImage (no había `appimagetool` en el entorno); medición de rendimiento real.
