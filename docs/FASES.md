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
- `tools/dev/check_scripts.tscn`: carga y compila todos los scripts/escenas/recursos/shaders, también los de las herramientas (104 en la
  versión actual) → 0 errores.
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

- **Bandidos humanos** (los Cuervos): modelo voxel humano ampliado con capucha con visera, embozo
  de tela, cabeza rapada, gorro de hierro con nasal, jubón de cuero tachonado con hombreras,
  brazales, carcaj con plumas y cuello de piel; cuatro tipos con su propia arma y aspecto
  (salteador con espada y escudo, matón con hacha, arquera, y el jefe Garra con maza, escudo de
  hierro, peto y capa) y cara/colores distintos por individuo. Usan el rig humanoide con todas sus
  animaciones (alerta, dos ataques, disparo, bloqueo, golpe, aturdimiento, muerte), sangre al
  recibir golpes y voces sintetizadas (grito de alarma de dos sílabas, quejidos, estertor y un
  silbido despreocupado cuando están tranquilos).
- Animaciones nuevas del rig humanoide: **prisionera** (cabizbaja, muñecas atadas, cambia el peso de
  pierna y levanta la vista) y **alegría** (brazos en alto y saltito al verse libre).
- Bloques de **lona** (cubo, remate y faldón en escalera) con textura procedural de tejido y
  remiendo; modelos de hoguera, jaula con puerta articulada, petate y tronco-asiento.

- **Armadura visible según el equipo** (`CharacterModels.look_with_gear`): el equipo de un PNJ (las
  mismas piezas que el jugador: `helm_iron`, `armor_chain`, `gauntlets_iron`, `greaves_iron`,
  `boots_iron`, guantes y calzas de cuero...) se traduce en rasgos del modelo de micro-vóxeles:
  bacinete con nasal, carrilleras y cresta; cota de malla en hileras de dos tonos con almófar,
  hombreras y faldar; sobreveste con los colores del señor y su emblema bordado (la torre de
  Peñalba) y cinto encima; guanteletes con manopla acampanada; grebas con rodillera; escarpes.
  El arma de la mano y el escudo del brazo salen de los mismos datos (antes había casos especiales en
  el código para el herrero y el guardia). Los guardias genéricos varían cara, pelo y barba según su
  identificador.
- Animaciones nuevas: **desmayo** (se le doblan las rodillas y cae de costado; el estado no vuelve
  solo a la locomoción) y **levantarse** (se incorpora, apoya una rodilla y se pone en pie).
- Bloque **IRON_BARS** (barrotes) con forma propia en el mallador: barrotes finos verticales con dos
  pletinas, orientados según los vecinos, con colisión. Modelos nuevos: trono, muñeco de
  entrenamiento, puerta enrejada y estandarte azul de Peñalba.

**Falta**
- Más criaturas (arañas).
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

- **Cerraduras y ganzúas**: cofres y jaulas pueden tener cerradura de cinco niveles (muy sencilla a
  muy difícil). Se abren con su llave o forzándolas: la probabilidad es 45 % + 1,5 % por punto de
  la habilidad *Ganzúas* sobre la dificultad, más agilidad y suerte (entre 3 % y 95 %); al fallar,
  la ganzúa se rompe la mitad de las veces. Acertar entrena mucho la habilidad y fallar, poco. El
  aviso en pantalla muestra la dificultad, la probabilidad y las ganzúas que quedan; el estado de
  cada cerradura se guarda. La mitad de los cofres de tesoro de las mazmorras y todos los de las
  salas secretas están cerrados. El Explorador empieza con 5 ganzúas; se compran en la herrería y
  las llevan encima muchos bandidos.

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

**Encargos generados**: cada asentamiento (Hojarrubia, Robledal y la posada) tiene un **tablón de
anuncios** que ofrece un encargo distinto cada 3 días de juego, determinista según la semilla, el
lugar y el periodo: cazar N lobos, destruir N esqueletos, abatir N salteadores de los Cuervos o
entregar N pieles/colmillos/polvo de hueso; se cobra en el propio tablón (oro y reputación con la facción del lugar). La definición se
guarda con la partida y se valida al cargar. La autoprueba acepta el encargo de Robledal, comprueba
que su definición sobrevive a un guardado JSON, lo cumple y lo cobra (oro 26 → 92, reputación +3).

**Búsqueda de una persona desaparecida — «La hija de Bram»**: Bram (Robledal) no sabe nada de su hija
Lina. Etapas: preguntar a Ulrico en la posada (su respuesta indica la dirección y distancia reales
del campamento y lo **descubre en el mapa**), encontrar el campamento de los Cuervos (objetivo
«llegar a» un lugar exterior), liberar a Lina (llave del jefe o ganzúas: objetivo de **bandera de
historia**), hablar con ella y volver con Bram (150 de oro, queso, poción y +25 de reputación con
Robledal). Al quedar libre, Lina celebra, sale del campamento por su propio pie y desde entonces
aparece en Robledal (aparición condicionada por banderas). Si la liberas sin la misión, vuelve a
casa igualmente (+10 de reputación) y la misión salta a la última etapa.

**Sistema de misiones ampliado**: banderas de historia persistentes (`GameState.set_flag`, se guardan
en la partida; las partidas antiguas siguen cargando), etapas con texto propio del PNJ al cumplirlas
(con marcadores como `{dir:lugar}`), efectos al completar una etapa, objetivos «esperar bandera»,
condiciones `requires_flag` / `requires_not_flag` / `skip_if_flag`, saludos que cambian según la
historia y entidades que solo aparecen con (o sin) una bandera.

**Pruebas (bandidos y misión de Lina)**, en la autoprueba con la semilla de prueba: combate real
contra un salteador (modelo humano construido, bloquea con el escudo, muere en 6 golpes y se
registra su botín); la misión se acepta, preguntar a Ulrico resuelve el texto («a unos 160 m al
sudeste de aquí») y descubre el campamento en el mapa (antes estaba oculto); al llegar a la puerta
el lugar se reconoce y la misión avanza; están los cinco bandidos (2 salteadores, matón, arquera en
la plataforma de la torre a 4,0 m y el jefe), la hoguera encendida, la jaula con Lina dentro y el
arcón cerrado; 8 intentos de ganzúa contra el arcón (3 % de probabilidad con la habilidad inicial)
fallan y las ganzúas rotas se descuentan exactamente; con habilidad alta la jaula se fuerza al
primer intento, se activa la bandera, la habilidad se entrena y la misión pasa a «Habla con Lina»;
el jefe lleva la llave y la nota, la llave abre el arcón (+156 de oro); el diálogo real con Lina la
rescata, ella sale del campamento y aparece después en Robledal; hablar con Bram completa la misión
(+150 de oro, reputación +25) y las banderas viajan en la partida guardada. Superada también con
el binario exportado (`--self-test`).

**Ley y orden** (`src/law/law.gd`):
- **Delitos con testigos**: agresión (40 de multa, −10 de reputación), agresión a la guardia (80),
  agresión grave —dejar inconsciente— (150), asesinato de un guardia (500), robo (25 + el doble de lo
  robado), allanamiento —forzar una cerradura ajena— (15) y resistencia a la autoridad (50). Solo
  cuentan si alguien lo ve: PNJ despiertos, visibles y con línea de visión (18 m; en los robos 10 m y
  mirando hacia ti; agachado te ven a menos distancia) o la propia víctima. Sin testigos no hay delito.
- **Recompensa** en la partida guardada (`law`: recompensa, día de resistencia, días de calabozo; las
  partidas antiguas cargan con todo a cero) y aviso en el HUD bajo la brújula.
- **Aldeanos**: si les pegas gritan pidiendo ayuda y huyen; al quedarse sin salud caen
  **inconscientes** 30 s (los PNJ con nombre nunca mueren) y se levantan. Los testigos de un robo
  gritan «¡Al ladrón!» y los gritos atraen a los guardias en 30 m.
- **Guardias** (Rolf, Aldric y la guardia del castillo): si te ven con deudas te dan el alto
  («¡Alto en nombre de la Marca!»), te persiguen y abren el **diálogo de detención** (no se puede
  cerrar con Esc): **pagar la multa**, **ir al calabozo** (un día por cada 100 monedas, máximo 14: el
  tiempo pasa, despiertas a las 8:00 en la celda de Peñalba con la reja abierta, curado, pero dos
  habilidades pierden lo avanzado) o **resistirte**. Hablar con un guardia teniendo deudas es
  entregarse. Atacar a un guardia o resistirse hace que **toda la guardia te ataque a la vista hasta
  el día siguiente**.
- **Guardias que pelean**: el PNJ se oculta y un `Enemy` con su mismo aspecto, armadura, arma, escudo y
  nombre ocupa su lugar (datos `town_guard`: bloquea con escudo, avisa a los suyos). Vuelve a ser PNJ
  cuando se salda la deuda o cuando, sin verte, regresa a su puesto. Un guardia genérico abatido es
  un asesinato si alguien lo ve, deja botín y no vuelve hasta pasados 3 días; los guardias con nombre
  caen inconscientes. Las flechas perdidas de los bandidos no enfrentan a los guardias contigo.
- **Robos**: los cofres de casas, posadas y del castillo tienen dueño («Robar del cofre») y los
  armeros del castillo son de la guardia. Con mala reputación (≤ −25) la gente se niega a hablar
  contigo y no comercia.

**Escolta** (nuevo objetivo `escort`): el hermano Anselmo, sanador del castillo, pide que le acompañes
a Robledal. Al aceptar te sigue (deja de pertenecer al chunk donde apareció), anda o corre según la
distancia, se reúne contigo si se queda atrás más de 30 m, atascado o en otro nivel, y vuelve a
aparecer a tu lado al cargar la partida o al salir de una mazmorra. Al llegar a Robledal se queda allí
(y desde entonces aparece en Robledal y ya no en el castillo); hablar con la alcaldesa Elena completa
la misión. Nueva misión de **matar** del capitán Aldric (salteadores en los caminos) y nuevas tiendas
(armería del castillo, sanador).

**Pruebas (ley y escolta)**, en la autoprueba: robo en el cuartel con la puerta cerrada → sin delito;
robo del armero del patio con un guardia mirando → recompensa 265 y reputación con la guardia −10;
el guardia persigue al jugador y le da el alto a 1,6 m; pagar la multa salda la deuda (265 monedas);
agresión al hermano Anselmo → recompensa 40, huye, reputación con Peñalba −10 y 6 guardias alertados;
entregarse → un día de calabozo (día 1 → 2, 8:00, en la celda, reja abierta); atacar a un guardia →
resistencia, el guardia pasa a ser un enemigo con su modelo, armas y escudo; abatido, queda registrado
(no vuelve en 3 días) y deja botín; el capitán Aldric cae inconsciente en vez de morir; al saldar la
deuda ningún guardia sigue hostil; la ley sobrevive al guardado (y las partidas antiguas cargan);
la escolta: Anselmo sigue al jugador, se reúne con él en Robledal, la misión avanza, Elena la
completa (+120 de oro) y Anselmo se queda en Robledal.

**Falta**: perdón de delitos por reputación o sobornos y tribunales; guardias en las demás aldeas
(ahora solo Rolf en Hojarrubia y la guardia del castillo).

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
- **Puentes**: donde un camino cruza agua se construye un tablero de madera sobre el nivel del agua,
  con barandilla en los bordes, pilares de tronco hasta el lecho y rampa de media losa en la orilla
  (se sube sin saltar). La autoprueba recorre todos los caminos: 36 columnas sobre agua, 36 con puente.
- **Tablones de anuncios** con encargos generados (ver fase 5).
- **Campamento de los Cuervos** (bandidos): se planifica el último y con su propio generador (no
  altera el resto de la región), en el bosque entre la posada y Robledal, unido por un sendero al
  camino más cercano y con la entrada orientada hacia él. Empalizada circular de troncos aguzados con
  puerta flanqueada por antorchas y una **brecha trasera** para entrar a escondidas; dos tiendas de
  lona y la del jefe con gallardete; **torre de vigía** con escalera, barandilla y tejadillo; hoguera
  con llamas, luz, humo y crepitar; troncos para sentarse, leña, paja, barriles y mercancía robada;
  la **jaula** con Lina y el **arcón del jefe** (cerradura difícil). Lo defienden cinco bandidos que
  se avisan entre sí (solo a los de su especie: un lobo ya no despierta a un bandido), con guardia
  en la puerta, ronda interior, matón junto al fuego, arquera en la torre y el jefe ante su tienda.
- **Emboscadas en los caminos**: en algunos chunks por los que pasa un camino, lejos de aldeas y
  lugares con nombre, una pareja de bandidos (salteador con arquera o matón) acecha a un lado del
  camino, mirando hacia él; deterministas por semilla y chunk, reaparecen a los 5 días. La
  autoprueba recorre los 56 chunks de la red de caminos y comprueba que todos los emboscados están
  junto a un camino y fuera de los poblados (semilla de prueba: una pareja).
- **Revisión visual del campamento** (capturas automáticas, conjuntos `camp` y `bandits` de
  `tools/dev/capture.gd`): reveló cuatro fallos que la autoprueba no podía ver y que se
  corrigieron: (1) los bandidos de ronda saltaban sobre las estacas de las tiendas y acababan
  **encaramados a la lona** — se quitaron las estacas, se rehízo la ronda por terreno despejado y
  los enemigos ya no saltan sobre lona; (2) la arquera aparecía **sobre el tejadillo** de la torre —
  la colocación de actores ahora sondea por debajo de cualquier techo; (3) la textura de lona
  parecía **arenisca** — ahora es lino claro con costuras, pliegues y remiendos ocasionales; (4) las
  puntas de la empalizada se unían como una **barandilla** (las vallas se conectan con los bloques
  vecinos) — ahora alternan troncos altos con punta y bajos sin ella. También se aligeró la escalera
  de la torre (peldaños sobre postes) y se suavizó la inclinación de cabeza de la prisionera.
- **Lugares ocultos**: el campamento no aparece en el mapa (ni su marcador ni sus construcciones)
  hasta que alguien te habla de él o lo encuentras; los lugares con identificador cuentan para los
  objetivos «llegar a» al entrar en ellos.

**Pruebas** (autoprueba, semilla de prueba): 6 lugares colocados en tierra firme (posada a ~200 m al
oeste, Robledal a ~280 m al sur, túmulo a ~370 m al sudeste, cubil a ~260 m al noroeste); el túmulo y
la cueva generan 25 salas y superan la verificación de conectividad; 6 lobos generados en los 81
chunks alrededor del cubil (81 chunks en ~1,3 s); combate real contra un lobo (muere en 3 golpes;
según la ejecución huye herido y vuelve; cuenta para la misión y deja botín); viaje a la posada y a Robledal con sus 4 PNJ
presentes y apoyados en el suelo; entrada en la cueva (lobos y alfa cargados) y salida al exterior.

**Revisión visual** (capturas automáticas con el binario de pruebas Vulkan/SwiftShader): lobo en
reposo, paso, galope, alerta, mordisco, salto, golpe, aturdimiento y muerte; pelajes pardo, blanco
y alfa; posada del Lobo Gris y aldea de Robledal; tablón de anuncios; mapa regional con marcadores y
leyenda; inventario con el panel de equipo; escudos de madera y de hierro en primera persona. A raíz
de la revisión se oscureció el pelaje gris (se veía casi blanco al sol) y se amplió la lista de equipo
para que se vean las 6 ranuras sin desplazarse.

**Castillo de Peñalba** (`src/world/gen/castle_builder.gd`), planificado con su propio generador
después del resto de la región (no altera las demás posiciones): sobre un alto a unos 230 m al
nordeste de Hojarrubia (se buscan emplazamientos secos y llanos y se prefieren los altos), con la
puerta orientada hacia el camino que lo une a la red de caminos. Recinto de 39 × 39 bloques:
- **Murallas** de tres bloques de grosor con **adarve**, parapeto almenado y antorchas en el lado
  exterior y matacán corrido; **tres escaleras** de piedra suben del patio al adarve.
- **Cuatro torres** de esquina de 7 × 7 con muro de dos bloques, puertas al adarve, saeteras y una
  **escalera de caracol** que esquiva las puertas y sube a la azotea almenada.
- **Torre-puerta** con paso abovedado (jambas y dovelas talladas), **rastrillo alzado**, sala de
  guardia a la altura del adarve, estandartes y faroles.
- **Torre del homenaje**: salón del trono con alfombra, columnas, estrado con escalones, **trono** de
  los Peñalba, braseros, estandartes, mesa y arcón cerrado; escalera a la **cámara de la señora**
  (cama, arcón noble, estudio, librerías) y otra a la **azotea** con barandilla y almenas.
- **Calabozo**: puesto del carcelero y dos celdas con **rejas de hierro** y **puertas enrejadas** con
  cerradura (llave del calabozo o ganzúas; forzarlas con testigos es allanamiento).
- Edificios del patio con los constructores existentes, girados con el recinto: **cuartel** con
  literas, armero y arcón; **armería** con fragua; pozo y farolas. Campo de entrenamiento con
  **muñecos de paja**, huerto con cerca, carro, barriles y tablón de anuncios.
- Gente: **Isolda de Peñalba** junto al trono, el **capitán Aldric** (multas y encargos) ante el
  calabozo, el **armero Garin** (tienda), el **hermano Anselmo** en el huerto y cinco guardias (dos en
  la puerta, uno de ronda por el adarve, uno por el patio y otro ante el homenaje).
- Lugar con nombre en el HUD, marcador azul en el mapa y nueva facción «Casa de Peñalba».

**Pruebas (castillo)**: en la autoprueba se comprueban bloque a bloque el paso de la puerta, la
muralla, el adarve, las almenas, las puertas de las torres, el caracol, la escalera al adarve, las
rejas, el salón y la azotea; 2 puertas enrejadas, el trono, 3 muñecos, 10 estandartes azules y el
tablón; Isolda, Aldric, Garin, Anselmo y 5 guardias, con yelmo, malla, guanteletes, grebas, escarpes,
sobreveste, espada y escudo en sus modelos.

**Revisión visual del castillo** (capturas automáticas: puerta, esquina, patio, adarve, salón del
trono, capitán, calabozo, noche, guardia inconsciente y diálogo de detención). A raíz de ella: (1) en
la semilla de prueba el castillo queda en un cerro y los árboles crecían pegados a los muros, con una
explanada mínima — la zona nivelada pasa a 63 × 63 bloques con un margen de transición de 24 y queda
reservada (sin árboles); (2) la puerta del calabozo daba a un callejón de dos bloques entre el
homenaje y el calabozo — ahora está en su fachada norte, hacia el patio, con el capitán al lado y un
camino empedrado a lo largo del homenaje; (3) la alfombra de la cámara de la señora se veía como una
mancha roja en el techo del salón del trono (el suelo de la planta es el techo de la de abajo) — se
quitó; (4) los barrotes usaban la textura clara del bloque de hierro y parecían blancos — nueva
textura de hierro forjado oscuro con puntos de óxido.

**Falta**: ciudades amuralladas grandes, más tipos de mazmorra y una red de lugares que se extienda
indefinidamente más allá de la región inicial.

## Fase 7 — Pulido y distribución · **PARCIAL**

**Implementado**: exportación reproducible (`scripts/export_linux.sh`), paquete `.tar.xz` con
lanzador, instalador de usuario y entrada de menú (`scripts/package_linux.sh`), script de AppImage
(requiere `appimagetool`), binario compatible con glibc ≥ 2.35, autoprueba integrada, README con
instalación, controles y solución de problemas.

**Pruebas del paquete (esta entrega)**: plantilla release recompilada (dependencias: solo `libc`,
`libm` y el cargador; símbolos hasta GLIBC_2.35); exportación y paquete de ~20 MB; suma SHA-256
verificada junto al archivo (se corrigió que el `.sha256` incluyera la ruta `dist/`); autoprueba
completa con `./vaelmoor.sh --headless -- --self-test` desde el paquete descomprimido; `install.sh`
en un `HOME` vacío (binario, `.pck`, lanzador en `~/.local/bin`, entrada de menú e icono), autoprueba
del juego instalado ejecutado desde otra carpeta (las partidas van a `~/.local/share/vaelmoor/`) y
`install.sh --uninstall` (elimina el juego y conserva las partidas). Es decir: descargar, instalar,
jugar, guardar, salir y cargar funcionan, aunque solo se han probado sin gráficos (`--headless`).
El paquete probado se incluye en `release/` (~20 MB, con su `.sha256`; repetidas todas estas pruebas con la versión que añade el castillo, la ley y la escolta).

En la verificación final se detectó que Godot importaba las capturas de `docs/screenshots/` y las
metía en el `.pck` (de 0,6 MB a 3,5 MB): ahora `docs/.gdignore` excluye esa carpeta del proyecto y el
preset de exportación excluye también `docs/*` y `release/*`. El paquete lleva las capturas como
archivos sueltos para que el README se vea completo. También se corrigió un error de proyectiles
cuyo tirador ya había sido eliminado (cientos de avisos *previously freed instance* en la
autoprueba, sin consecuencias en el juego pero ruidosos en el registro).

**Falta / no verificado**: pruebas en hardware real con GPU (renderizado OpenGL y rendimiento) y en
Arch, Ubuntu y Mint; AppImage (no hay `appimagetool`, `mksquashfs` ni el *runtime* de AppImage en el
entorno, y sus binarios solo se distribuyen por un servidor bloqueado; el script
`scripts/make_appimage.sh` está listo para quien tenga la herramienta).
