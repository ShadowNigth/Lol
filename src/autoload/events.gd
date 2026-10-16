extends Node
## Bus de eventos global. Desacopla sistemas (HUD, audio, misiones...).

@warning_ignore_start("unused_signal")
signal notify(text: String, kind: String)                    # mensajes en pantalla
signal player_damaged(amount: float, source_position: Vector3)
signal player_died
signal player_stats_changed
signal enemy_killed(enemy: Node, enemy_id: String)
signal target_changed(target: Node)                          # enemigo apuntado (barra superior)
signal interaction_hint(text: String)                        # "" oculta el aviso
signal world_ready
signal game_saved(slot: String)
signal game_loaded(slot: String)
signal location_entered(name: String)
signal law_changed(bounty: int)                              # recompensa por tu cabeza (ver Law)
@warning_ignore_restore("unused_signal")
