# Atribuciones

| Recurso | Fuente | Licencia | Uso en el proyecto |
|---|---|---|---|
| Godot Engine 4.7.2 | https://godotengine.org (compilado desde el código fuente oficial, etiqueta `4.7.2-stable`) | MIT | Motor del juego y plantilla de exportación |

Todo el contenido artístico del juego es **original y se genera por código** dentro de este repositorio:

- Texturas de bloques pixel-art (16×16): `src/world/voxel/texture_factory.gd`.
- Modelos voxel de personajes, criaturas, armas y mobiliario: `src/models/`.
- Animaciones esqueléticas (enemigos) y de primera persona (brazos/armas): `src/animation/`.
- Efectos de sonido sintetizados (ruido, osciladores y filtros): `src/audio/sfx_synth.gd`.
- Cielo, agua, llamas y viñeta: shaders en `shaders/`.

No se utilizan recursos de terceros (modelos, texturas, música, sonidos ni fuentes adicionales); la fuente de texto es la integrada por defecto en Godot.
