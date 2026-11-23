extends Node2D

# Ludo Warriors — Godot 4.x, local hot-seat multiplayer (2–4 players)
const CELL: float = 42.0
const ORIGIN: Vector2 = Vector2(45.0, 42.0)
const BOARD_SIZE: float = CELL * 15.0
const COLORS: Array[Color] = [Color("#e53935"), Color("#16a765"), Color("#f4c542"), Color("#2878df")]
const NAMES: Array[String] = ["RED", "GREEN", "YELLOW", "BLUE"]
const TRACK: Array[Vector2i] = [
    Vector2i(1,6), Vector2i(2,6), Vector2i(3,6), Vector2i(4,6), Vector2i(5,6),
    Vector2i(6,5), Vector2i(6,4), Vector2i(6,3), Vector2i(6,2), Vector2i(6,1), Vector2i(6,0),
    Vector2i(7,0), Vector2i(8,0),
    Vector2i(8,1), Vector2i(8,2), Vector2i(8,3), Vector2i(8,4), Vector2i(8,5),
    Vector2i(9,6), Vector2i(10,6), Vector2i(11,6), Vector2i(12,6), Vector2i(13,6), Vector2i(14,6),
    Vector2i(14,7), Vector2i(14,8),
    Vector2i(13,8), Vector2i(12,8), Vector2i(11,8), Vector2i(10,8), Vector2i(9,8),
    Vector2i(8,9), Vector2i(8,10), Vector2i(8,11), Vector2i(8,12), Vector2i(8,13), Vector2i(8,14),
    Vector2i(7,14), Vector2i(6,14),
    Vector2i(6,13), Vector2i(6,12), Vector2i(6,11), Vector2i(6,10), Vector2i(6,9),
    Vector2i(5,8), Vector2i(4,8), Vector2i(3,8), Vector2i(2,8), Vector2i(1,8), Vector2i(0,8),
    Vector2i(0,7), Vector2i(0,6)
]
# Each player's first square on the common clockwise track.
const START_INDEX: Array[int] = [0, 13, 26, 39]
const SAFE_INDEX: Array[int] = [0, 8, 13, 21, 26, 34, 39, 47]
const LANES: Array = [
    [Vector2i(1,7), Vector2i(2,7), Vector2i(3,7), Vector2i(4,7), Vector2i(5,7), Vector2i(6,7)],
    [Vector2i(7,1), Vector2i(7,2), Vector2i(7,3), Vector2i(7,4), Vector2i(7,5), Vector2i(7,6)],
    [Vector2i(13,7), Vector2i(12,7), Vector2i(11,7), Vector2i(10,7), Vector2i(9,7), Vector2i(8,7)],
    [Vector2i(7,13), Vector2i(7,12), Vector2i(7,11), Vector2i(7,10), Vector2i(7,9), Vector2i(7,8)]
]
const YARD_SPOTS: Array = [
    [Vector2(2,2), Vector2(4,2), Vector2(2,4), Vector2(4,4)],
    [Vector2(11,2), Vector2(13,2), Vector2(11,4), Vector2(13,4)],
    [Vector2(11,11), Vector2(13,11), Vector2(11,13), Vector2(13,13)],
    [Vector2(2,11), Vector2(4,11), Vector2(2,13), Vector2(4,13)]
]

var pieces: Array = [] # -1 yard, 0..50 track, 51..56 home lane, 57 finished
var player_turn: int = 0
var active_players: int = 4
var dice: int = 0
var rolled: bool = false
var rolling: bool = false
var animating: bool = false
var winner: int = -1
var consecutive_sixes: int = 0
var message: String = "Roll the dice to begin"
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var roll_rect: Rect2 = Rect2(275, 735, 190, 64)
var reset_rect: Rect2 = Rect2(520, 738, 150, 56)
var players_rect: Rect2 = Rect2(45, 738, 205, 56)
var animating_token: Vector2i = Vector2i(-1, -1)
var anim_position: Vector2 = Vector2.ZERO
var token_hit_positions: Dictionary = {}
var hit_effects: Array = []
var screen_shake: float = 0.0
var capture_banner: String = ""
var capture_banner_time: float = 0.0
var hit_audio: AudioStreamPlayer
var dice_audio: AudioStreamPlayer
var music_audio: AudioStreamPlayer
var music_on: bool = true

func _ready() -> void:
    rng.randomize()
    hit_audio = AudioStreamPlayer.new()
    dice_audio = AudioStreamPlayer.new()
    music_audio = AudioStreamPlayer.new()
    add_child(hit_audio)
    add_child(dice_audio)
    add_child(music_audio)
    hit_audio.stream = load("res://assets/capture.wav")
    dice_audio.stream = load("res://assets/dice.wav")
    music_audio.stream = load("res://assets/arcade_music.wav")
    music_audio.volume_db = -17.0
    music_audio.finished.connect(_restart_music)
    if music_on:
        music_audio.play()
    _reset_game()

func _restart_music() -> void:
    if music_on and music_audio != null:
        music_audio.play()

func _process(delta: float) -> void:
    if rolling:
        dice = rng.randi_range(1, 6)
        queue_redraw()
    for effect in hit_effects:
        effect["life"] = float(effect["life"]) - delta
        effect["pos"] = Vector2(effect["pos"]) + Vector2(0, -18.0 * delta)
        var velocities: Array = effect["velocities"]
        var bits: Array = effect["bits"]
        for j in range(bits.size()):
            bits[j] = Vector2(bits[j]) + Vector2(velocities[j]) * delta
            velocities[j] = Vector2(velocities[j]) * 0.94 + Vector2(0, 28.0 * delta)
        effect["bits"] = bits
        effect["velocities"] = velocities
    screen_shake = move_toward(screen_shake, 0.0, 35.0 * delta)
    capture_banner_time = maxf(0.0, capture_banner_time - delta)
    for i in range(hit_effects.size() - 1, -1, -1):
        if float(hit_effects[i]["life"]) <= 0.0:
            hit_effects.remove_at(i)
    if not hit_effects.is_empty():
        queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(Vector2.ZERO, Vector2(720, 820)), Color("#f4f1e9"))
    if screen_shake > 0.0:
        draw_set_transform(Vector2(rng.randf_range(-screen_shake, screen_shake), rng.randf_range(-screen_shake, screen_shake)))
    _draw_board()
    _draw_pieces()
    _draw_hit_effects()
    _draw_hud()
    draw_set_transform(Vector2.ZERO)
    if capture_banner_time > 0.0:
        var alpha: float = minf(1.0, capture_banner_time * 2.0)
        draw_string(ThemeDB.fallback_font, Vector2(205, 280), capture_banner, HORIZONTAL_ALIGNMENT_CENTER, 310, 34, Color(1.0, 0.12, 0.12, alpha))

func _cell_rect(c: Vector2i) -> Rect2:
    return Rect2(ORIGIN + Vector2(c) * CELL, Vector2(CELL, CELL))

func _cell_center(c: Vector2i) -> Vector2:
    return _cell_rect(c).get_center()

func _draw_board() -> void:
    # Four coloured home quarters.
    var yards: Array[Rect2] = [
        Rect2(ORIGIN, Vector2(CELL * 6, CELL * 6)),
        Rect2(ORIGIN + Vector2(CELL * 9, 0), Vector2(CELL * 6, CELL * 6)),
        Rect2(ORIGIN + Vector2(CELL * 9, CELL * 9), Vector2(CELL * 6, CELL * 6)),
        Rect2(ORIGIN + Vector2(0, CELL * 9), Vector2(CELL * 6, CELL * 6))
    ]
    for p in range(4):
        draw_rect(yards[p], COLORS[p])
        var inner: Rect2 = yards[p].grow(-CELL * 0.78)
        draw_rect(inner, Color("#fffdf8"))
        draw_rect(inner, COLORS[p].darkened(0.12), false, 2.0)
        for spot in YARD_SPOTS[p]:
            var c: Vector2 = ORIGIN + (spot + Vector2(0.5, 0.5)) * CELL
            draw_circle(c, 15.0, COLORS[p].lightened(0.30))
            draw_circle(c, 15.0, Color.WHITE, false, 2.0)

    # Common 52-square track.
    for i in range(TRACK.size()):
        var r: Rect2 = _cell_rect(TRACK[i])
        draw_rect(r, Color.WHITE)
        draw_rect(r, Color("#aab0b8"), false, 1.0)
        if i in SAFE_INDEX:
            draw_circle(r.get_center(), 10.0, Color("#f5c542"))
            draw_string(ThemeDB.fallback_font, r.position + Vector2(13, 29), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("#725100"))
    for p in range(4):
        draw_rect(_cell_rect(TRACK[START_INDEX[p]]), COLORS[p].lightened(0.30))
        for c in LANES[p]:
            draw_rect(_cell_rect(c), COLORS[p].lightened(0.38))
            draw_rect(_cell_rect(c), Color.WHITE, false, 1.0)

    # Four-colour finish triangle.
    var tl: Vector2 = ORIGIN + Vector2(6, 6) * CELL
    var tr: Vector2 = tl + Vector2(3 * CELL, 0)
    var br: Vector2 = tl + Vector2(3 * CELL, 3 * CELL)
    var bl: Vector2 = tl + Vector2(0, 3 * CELL)
    var mid: Vector2 = (tl + br) * 0.5
    draw_colored_polygon(PackedVector2Array([tl, tr, mid]), COLORS[0])
    draw_colored_polygon(PackedVector2Array([tr, br, mid]), COLORS[1])
    draw_colored_polygon(PackedVector2Array([br, bl, mid]), COLORS[2])
    draw_colored_polygon(PackedVector2Array([bl, tl, mid]), COLORS[3])
    draw_circle(mid, 6.0, Color.WHITE)

func _piece_position(p: int, t: int) -> Vector2:
    var progress: int = int(pieces[p][t])
    if progress == -1:
        return ORIGIN + (YARD_SPOTS[p][t] + Vector2(0.5, 0.5)) * CELL
    if progress == 57:
        return ORIGIN + Vector2(7.5, 7.5) * CELL
    if progress <= 50:
        var global_index: int = (START_INDEX[p] + progress) % 52
        return _cell_center(TRACK[global_index])
    return _cell_center(LANES[p][progress - 51])

func _stack_offset(p: int, t: int) -> Vector2:
    var base: Vector2 = _piece_position(p, t)
    var group: Array[Vector2i] = []
    for op in range(4):
        for ot in range(4):
            if op == p and ot == t:
                continue
            if _piece_position(op, ot).distance_to(base) < 1.0:
                group.append(Vector2i(op, ot))
    var rank: int = 0
    for id in group:
        if id.x < p or (id.x == p and id.y < t):
            rank += 1
    var offsets: Array[Vector2] = [Vector2(-8,-8), Vector2(8,-8), Vector2(-8,8), Vector2(8,8)]
    return offsets[mini(rank, 3)] if not group.is_empty() else Vector2.ZERO

func _draw_pieces() -> void:
    token_hit_positions.clear()
    for p in range(4):
        for t in range(4):
            var pos: Vector2 = _piece_position(p, t) + _stack_offset(p, t)
            if animating_token == Vector2i(p, t):
                pos = anim_position
            token_hit_positions[Vector2i(p, t)] = pos
            if rolled and p == player_turn and _can_move(p, t):
                var pulse: float = 2.0 * sin(Time.get_ticks_msec() / 170.0)
                draw_circle(pos, 21.0 + pulse, Color(1, 1, 1, 0.9), false, 3.0)
            # Glossy, dimensional arcade pawn with pedestal and highlights.
            draw_circle(pos + Vector2(0, 10), 10.0, Color(0, 0, 0, 0.22))
            draw_circle(pos + Vector2(0, 7), 11.5, COLORS[p].darkened(0.48))
            draw_circle(pos + Vector2(0, 5), 9.0, COLORS[p].lightened(0.05))
            draw_colored_polygon(PackedVector2Array([
                pos + Vector2(-9, 5), pos + Vector2(-7, -5), pos + Vector2(0, -14),
                pos + Vector2(7, -5), pos + Vector2(9, 5), pos + Vector2(5, 12), pos + Vector2(-5, 12)
            ]), COLORS[p].darkened(0.10))
            draw_circle(pos + Vector2(0, -10), 8.5, COLORS[p].lightened(0.22))
            draw_arc(pos + Vector2(0, -10), 8.5, -2.7, 0.7, 18, COLORS[p].darkened(0.38), 1.5)
            draw_circle(pos + Vector2(-2.8, -13), 2.5, Color(1, 1, 1, 0.78))
            draw_circle(pos + Vector2(0, -10), 8.5, COLORS[p].darkened(0.25), false, 1.4)

func _draw_hit_effects() -> void:
    # Cartoon arcade-style red impact splashes (non-realistic, non-graphic).
    for effect in hit_effects:
        var life: float = float(effect["life"])
        var alpha: float = clampf(life / 0.72, 0.0, 1.0)
        var pos: Vector2 = effect["pos"]
        var radius: float = 7.0 + (1.0 - alpha) * 15.0
        draw_circle(pos, radius, Color(0.88, 0.04, 0.08, alpha * 0.75))
        for bit in effect["bits"]:
            var point: Vector2 = pos + bit
            draw_circle(point, maxf(1.5, 4.0 * alpha), Color(0.72, 0.02, 0.05, alpha))
        draw_arc(pos, radius + 5.0, 0.0, TAU, 24, Color(1.0, 0.25, 0.2, alpha), 2.0)

func _draw_die(value: int, center: Vector2) -> void:
    # Bevelled pseudo-3D dice (native 2D rendering, no external 3D assets).
    draw_rect(Rect2(center - Vector2(24, 22), Vector2(54, 54)), Color(0, 0, 0, 0.28))
    draw_rect(Rect2(center - Vector2(29, 29), Vector2(58, 58)), Color("#aab4c2"))
    draw_rect(Rect2(center - Vector2(27, 29), Vector2(54, 54)), Color("#ffffff"))
    draw_line(center + Vector2(-25, -25), center + Vector2(24, -25), Color.WHITE, 3.0)
    draw_line(center + Vector2(-25, -25), center + Vector2(-25, 24), Color.WHITE, 3.0)
    draw_rect(Rect2(center - Vector2(27, 27), Vector2(54, 54)), Color("#273449"), false, 2.0)
    var dots: Array[Array] = [[], [Vector2(0,0)], [Vector2(-12,-12),Vector2(12,12)], [Vector2(-12,-12),Vector2(0,0),Vector2(12,12)], [Vector2(-12,-12),Vector2(12,-12),Vector2(-12,12),Vector2(12,12)], [Vector2(-12,-12),Vector2(12,-12),Vector2(0,0),Vector2(-12,12),Vector2(12,12)], [Vector2(-12,-12),Vector2(12,-12),Vector2(-12,0),Vector2(12,0),Vector2(-12,12),Vector2(12,12)]]
    for dot in dots[value]:
        draw_circle(center + dot, 4.2, Color("#202b3d"))

func _draw_hud() -> void:
    draw_rect(Rect2(0, 700, 720, 120), Color("#202b3d"))
    draw_string(ThemeDB.fallback_font, Vector2(24, 729), NAMES[player_turn] + " PLAYER'S TURN", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, COLORS[player_turn].lightened(0.3))
    draw_string(ThemeDB.fallback_font, Vector2(500, 729), "OFFLINE  •  MUSIC " + ("ON" if music_on else "OFF"), HORIZONTAL_ALIGNMENT_LEFT, 190, 14, Color("#dce7f5"))
    draw_string(ThemeDB.fallback_font, Vector2(24, 762), message, HORIZONTAL_ALIGNMENT_LEFT, 220, 14, Color.WHITE)
    draw_rect(players_rect, Color("#42536c"))
    draw_rect(players_rect, Color.WHITE, false, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(61, 773), "PLAYERS: " + str(active_players), HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)
    draw_rect(roll_rect, Color("#f2b632"))
    draw_rect(roll_rect, Color.WHITE, false, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(319, 775), "ROLL DICE", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("#252525"))
    _draw_die(dice, Vector2(493, 767))
    draw_rect(reset_rect, Color("#42536c"))
    draw_rect(reset_rect, Color.WHITE, false, 2.0)
    draw_string(ThemeDB.fallback_font, Vector2(548, 773), "RESET", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color.WHITE)
    if winner >= 0:
        draw_rect(Rect2(105, 300, 510, 155), Color("#172033"))
        draw_rect(Rect2(105, 300, 510, 155), Color("#f2b632"), false, 4.0)
        draw_string(ThemeDB.fallback_font, Vector2(190, 365), NAMES[winner] + " WINS!", HORIZONTAL_ALIGNMENT_LEFT, -1, 42, COLORS[winner])
        draw_string(ThemeDB.fallback_font, Vector2(190, 410), "Press RESET to play again", HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color.WHITE)

func _can_move(p: int, t: int) -> bool:
    var progress: int = int(pieces[p][t])
    if progress == 57:
        return false
    if progress == -1:
        return dice == 6
    if progress + dice > 57:
        return false
    # A pair of opposing pawns is a blockade: you cannot land on or pass it.
    if progress <= 50:
        var end_progress: int = mini(progress + dice, 50)
        for step in range(progress + 1, end_progress + 1):
            var idx: int = (START_INDEX[p] + step) % 52
            var pawns_on_square: int = 0
            for op in range(active_players):
                for ot in range(4):
                    if op == p and ot == t:
                        continue
                    var other_progress: int = int(pieces[op][ot])
                    if other_progress >= 0 and other_progress <= 50 and (START_INDEX[op] + other_progress) % 52 == idx:
                        pawns_on_square += 1
            if pawns_on_square >= 2:
                return false
    return true

func _on_roll() -> void:
    if rolled or rolling or animating or winner >= 0:
        return
    rolling = true
    if dice_audio != null:
        dice_audio.play()
    for i in range(10):
        dice = rng.randi_range(1, 6)
        queue_redraw()
        await get_tree().create_timer(0.055).timeout
    rolling = false
    dice = rng.randi_range(1, 6)
    if dice == 6:
        consecutive_sixes += 1
        if consecutive_sixes == 3:
            consecutive_sixes = 0
            rolled = false
            message = "Three sixes! Turn forfeited."
            _next_player()
            queue_redraw()
            return
    else:
        consecutive_sixes = 0
    var any_move: bool = false
    for t in range(4):
        if _can_move(player_turn, t):
            any_move = true
    if any_move:
        rolled = true
        message = "Rolled " + str(dice) + " — tap a glowing pawn"
    else:
        rolled = false
        if dice == 6:
            # A six grants another roll even when every pawn is blocked or still in the yard.
            # Keep the consecutive-six counter so the three-sixes rule remains correct.
            message = "No legal move, but six! Roll again."
        else:
            message = "No legal move — next player"
            _next_player()
    queue_redraw()

func _move_piece(p: int, t: int) -> void:
    if not rolled or animating or not _can_move(p, t):
        return
    animating = true
    rolled = false
    var old_progress: int = int(pieces[p][t])
    var target_progress: int = 0 if old_progress == -1 else old_progress + dice
    animating_token = Vector2i(p, t)
    anim_position = _piece_position(p, t) + _stack_offset(p, t)
    if old_progress == -1:
        var entry: Vector2 = _cell_center(TRACK[START_INDEX[p]])
        await _tween_token_to(entry, 0.18)
        pieces[p][t] = 0
    else:
        for step in range(old_progress + 1, target_progress + 1):
            var target: Vector2
            if step <= 50:
                target = _cell_center(TRACK[(START_INDEX[p] + step) % 52])
            elif step <= 56:
                target = _cell_center(LANES[p][step - 51])
            else:
                target = ORIGIN + Vector2(7.5, 7.5) * CELL
            await _tween_token_to(target, 0.11)
            pieces[p][t] = step
    animating_token = Vector2i(-1, -1)
    animating = false
    _capture_opponents(p, t)
    var all_finished: bool = true
    for value in pieces[p]:
        if int(value) != 57:
            all_finished = false
    if all_finished:
        winner = p
        message = NAMES[p] + " wins the match!"
    elif dice == 6:
        message = "Six! Roll again."
    else:
        consecutive_sixes = 0
        _next_player()
        message = NAMES[player_turn] + " player's turn"
    queue_redraw()

func _tween_token_to(target: Vector2, duration: float) -> void:
    var tween: Tween = create_tween()
    tween.set_trans(Tween.TRANS_QUAD)
    tween.set_ease(Tween.EASE_OUT)
    tween.tween_method(_set_anim_position, anim_position, target, duration)
    await tween.finished
    anim_position = target

func _set_anim_position(value: Vector2) -> void:
    anim_position = value
    queue_redraw()

func _capture_opponents(p: int, t: int) -> void:
    var progress: int = int(pieces[p][t])
    if progress < 0 or progress > 50:
        return
    var global_index: int = (START_INDEX[p] + progress) % 52
    if global_index in SAFE_INDEX:
        return
    var targets: Array[Vector2i] = []
    for other_player in range(active_players):
        if other_player == p:
            continue
        for other_token in range(4):
            var other_progress: int = int(pieces[other_player][other_token])
            if other_progress >= 0 and other_progress <= 50:
                var other_index: int = (START_INDEX[other_player] + other_progress) % 52
                if other_index == global_index:
                    targets.append(Vector2i(other_player, other_token))
    # A pair of opposing pawns is a blockade and cannot be captured.
    if targets.size() == 1:
        var victim: Vector2i = targets[0]
        var impact: Vector2 = _piece_position(victim.x, victim.y)
        var bits: Array[Vector2] = []
        var velocities: Array[Vector2] = []
        for n in range(18):
            var angle: float = TAU * float(n) / 18.0 + rng.randf_range(-0.18, 0.18)
            var distance: float = rng.randf_range(3.0, 12.0)
            bits.append(Vector2(cos(angle), sin(angle)) * distance)
            velocities.append(Vector2(cos(angle), sin(angle)) * rng.randf_range(65.0, 145.0))
        hit_effects.append({"pos": impact, "bits": bits, "velocities": velocities, "life": 0.9})
        screen_shake = 7.0
        capture_banner = "MAAR DIYA!  KNOCKOUT!"
        capture_banner_time = 1.5
        if hit_audio != null:
            hit_audio.play()
        pieces[victim.x][victim.y] = -1
        message = "SMASH! Opponent pawn sent home!"

func _next_player() -> void:
    # A fresh player's turn always starts a new consecutive-six counter.
    consecutive_sixes = 0
    player_turn = (player_turn + 1) % active_players

func _reset_game() -> void:
    active_players = clampi(active_players, 2, 4)
    pieces.clear()
    for p in range(4):
        pieces.append([-1, -1, -1, -1])
    player_turn = 0
    dice = 0
    rolled = false
    rolling = false
    animating = false
    winner = -1
    consecutive_sixes = 0
    animating_token = Vector2i(-1, -1)
    hit_effects.clear()
    screen_shake = 0.0
    capture_banner_time = 0.0
    message = "Roll the dice to begin"
    queue_redraw()

func _handle_tap(pos: Vector2) -> void:
    if pos.y >= 700.0 and pos.y < 735.0 and pos.x >= 500.0 and pos.x < 710.0:
        music_on = not music_on
        if music_audio != null:
            if music_on and not music_audio.playing:
                music_audio.play()
            elif not music_on:
                music_audio.stop()
        queue_redraw()
        return
    if reset_rect.has_point(pos):
        _reset_game()
        return
    if players_rect.has_point(pos) and not rolled and not animating:
        active_players += 1
        if active_players > 4:
            active_players = 2
        _reset_game()
        message = "Local pass-and-play: " + str(active_players) + " players"
        return
    if roll_rect.has_point(pos):
        _on_roll()
        return
    if rolled and winner < 0 and not animating:
        var best_token: int = -1
        var best_distance: float = 99999.0
        for t in range(4):
            if not _can_move(player_turn, t):
                continue
            var token_pos: Vector2 = token_hit_positions.get(Vector2i(player_turn, t), _piece_position(player_turn, t))
            var distance: float = token_pos.distance_to(pos)
            if distance < best_distance and distance <= 29.0:
                best_distance = distance
                best_token = t
        if best_token >= 0:
            _move_piece(player_turn, best_token)

func _input(event: InputEvent) -> void:
    if event is InputEventScreenTouch and event.pressed:
        _handle_tap(event.position)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _handle_tap(event.position)
