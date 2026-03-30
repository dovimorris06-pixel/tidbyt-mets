load("render.star", "render")
load("http.star", "http")
load("cache.star", "cache")
load("time.star", "time")

TEAM_COLORS = {
    "LAA": "#BA0021",
    "ARI": "#A71930",
    "BAL": "#DF4601",
    "BOS": "#BD3039",
    "CHC": "#0E3386",
    "CIN": "#C6011F",
    "CLE": "#00385D",
    "COL": "#8B5CF6",
    "DET": "#6699CC",
    "HOU": "#EB6E1F",
    "KC":  "#004687",
    "LAD": "#005A9C",
    "WSH": "#AB0003",
    "NYM": "#FF5910",
    "OAK": "#007A5E",
    "PIT": "#FDB827",
    "SD":  "#8B7355",
    "SEA": "#0C2C56",
    "SF":  "#FD5A1E",
    "STL": "#C41E3A",
    "TB":  "#8FBCE6",
    "TEX": "#003278",
    "TOR": "#134A8E",
    "MIN": "#D31145",
    "PHI": "#E81828",
    "ATL": "#CE1141",
    "CWS": "#AAAAAA",
    "MIA": "#00A3E0",
    "NYY": "#6699CC",
    "MIL": "#FFC52F",
}

COLOR_WHITE  = "#FFFFFF"
COLOR_YELLOW = "#FFD700"
COLOR_GRAY   = "#888888"
COLOR_DIM    = "#444444"
COLOR_BLACK  = "#000000"
COLOR_CYAN   = "#00FFFF"
COLOR_GREEN  = "#00FF00"
COLOR_RED    = "#FF4444"

MLB_ALL_GAMES_URL = "https://statsapi.mlb.com/api/v1/schedule?sportId=1&date=%s&hydrate=team,linescore,person,probablePitcher"
MLB_LIVE_URL      = "https://statsapi.mlb.com/api/v1.1/game/%s/feed/live"

FRAMES_PER_GAME = 100

def get_today():
    now = time.now().in_location("America/New_York")
    return now.format("2006-01-02")

def truncate(s, n):
    if len(s) > n:
        return s[:n]
    return s

def safe_get(d, *keys):
    cur = d
    for k in keys:
        if cur == None:
            return None
        if type(cur) == "dict":
            cur = cur.get(k)
        elif type(cur) == "list":
            if type(k) == "int" and k < len(cur):
                cur = cur[k]
            else:
                return None
        else:
            return None
    return cur

def last_name(full):
    if full == None or full == "":
        return ""
    parts = full.split(" ")
    if len(parts) > 1:
        return parts[-1]
    return full

def format_time(utc):
    if utc == "" or utc == None:
        return "TBD"
    t = time.parse_time(utc)
    return t.in_location("America/New_York").format("3:04 PM")

def team_color(abbr):
    c = TEAM_COLORS.get(abbr)
    return c if c != None else COLOR_WHITE

def make_dot(filled, color_on):
    return render.Box(width=3, height=3, color=color_on if filled else COLOR_DIM)

def dot_row(values, color_on):
    children = []
    for i, v in enumerate(values):
        if i > 0:
            children.append(render.Box(width=1, height=3, color=COLOR_BLACK))
        children.append(make_dot(v == 1, color_on))
    return render.Row(children=children)

def fetch_all_game_pks():
    cache_key = "mlb_scoreboard_pks"
    cached = cache.get(cache_key)
    if cached != None:
        return cached.split("|")
    today = get_today()
    resp = http.get(MLB_ALL_GAMES_URL % today, ttl_seconds=60)
    if resp.status_code != 200:
        return []
    data = resp.json()
    dates = safe_get(data, "dates")
    if dates == None or len(dates) == 0:
        return []
    games = safe_get(dates, 0, "games")
    if games == None or len(games) == 0:
        return []
    pks = []
    for game in games:
        pk = str(safe_get(game, "gamePk"))
        if pk != "None" and pk != "":
            pks.append(pk)
    if len(pks) > 0:
        cache.set(cache_key, "|".join(pks), ttl_seconds=60)
    return pks

def fetch_live(game_pk):
    resp = http.get(MLB_LIVE_URL % game_pk, ttl_seconds=15)
    if resp.status_code != 200:
        return None
    return resp.json()

def parse_game(data):
    g = {}
    g["status"] = safe_get(data, "gameData", "status", "abstractGameCode") or "P"
    g["detailed"] = safe_get(data, "gameData", "status", "detailedState") or ""
    g["is_delayed"] = "Delay" in g["detailed"] or "Suspended" in g["detailed"]
    g["away_abbr"] = safe_get(data, "gameData", "teams", "away", "abbreviation") or "AWY"
    g["home_abbr"] = safe_get(data, "gameData", "teams", "home", "abbreviation") or "HME"
    g["away_color"] = team_color(g["away_abbr"])
    g["home_color"] = team_color(g["home_abbr"])
    g["game_time"] = format_time(safe_get(data, "gameData", "datetime", "dateTime") or "")
    away_prob = safe_get(data, "gameData", "probablePitchers", "away", "fullName") or ""
    home_prob = safe_get(data, "gameData", "probablePitchers", "home", "fullName") or ""
    g["away_prob"] = truncate(last_name(away_prob), 9)
    g["home_prob"] = truncate(last_name(home_prob), 9)
    ls = safe_get(data, "liveData", "linescore") or {}
    g["away_score"] = safe_get(ls, "teams", "away", "runs") or 0
    g["home_score"] = safe_get(ls, "teams", "home", "runs") or 0
    g["inning"]      = safe_get(ls, "currentInning") or 0
    g["inning_half"] = safe_get(ls, "inningHalf") or "Top"
    g["outs"]        = safe_get(ls, "outs") or 0
    offense = safe_get(ls, "offense") or {}
    g["base1"] = 1 if offense.get("first")  != None else 0
    g["base2"] = 1 if offense.get("second") != None else 0
    g["base3"] = 1 if offense.get("third")  != None else 0
    decisions = safe_get(data, "liveData", "decisions") or {}
    g["win_p"]  = last_name(safe_get(decisions, "winner", "fullName") or "")
    g["loss_p"] = last_name(safe_get(decisions, "loser",  "fullName") or "")
    return g

def game_card(g):
    away_c = g["away_color"]
    home_c = g["home_color"]
    status = g["status"]

    if status == "P":
        score_row = render.Row(children=[
            render.Text(content=g["away_abbr"], color=away_c, font="CG-pixel-3x5-mono"),
            render.Text(content=" @ ", color=COLOR_WHITE, font="CG-pixel-3x5-mono"),
            render.Text(content=g["home_abbr"], color=home_c, font="CG-pixel-3x5-mono"),
        ])
    else:
        score_row = render.Row(children=[
            render.Text(content=g["away_abbr"], color=away_c, font="CG-pixel-3x5-mono"),
            render.Text(content=" %s  " % str(g["away_score"]), color=COLOR_WHITE, font="CG-pixel-3x5-mono"),
            render.Text(content=g["home_abbr"], color=home_c, font="CG-pixel-3x5-mono"),
            render.Text(content=" %s" % str(g["home_score"]), color=COLOR_WHITE, font="CG-pixel-3x5-mono"),
        ])

    if status == "P":
        status_row = render.Text(content=g["game_time"], color=COLOR_YELLOW, font="CG-pixel-3x5-mono")
    elif status == "F":
        status_row = render.Text(content="FINAL", color=COLOR_YELLOW, font="CG-pixel-3x5-mono")
    else:
        arrow = "v" if g["inning_half"] == "Bottom" else "^"
        dly = "DLY " if g["is_delayed"] else ""
        status_row = render.Text(content="%s%s %s" % (dly, arrow, str(g["inning"])), color=COLOR_CYAN, font="CG-pixel-3x5-mono")

    if status == "P":
        if g["away_prob"] != "" or g["home_prob"] != "":
            detail_row = render.Text(content="SP: %s/%s" % (truncate(g["away_prob"],7), truncate(g["home_prob"],7)), color=COLOR_GRAY, font="CG-pixel-3x5-mono")
        else:
            detail_row = render.Text(content="Preview", color=COLOR_GRAY, font="CG-pixel-3x5-mono")
    elif status == "F":
        if g["win_p"] != "":
            detail_row = render.Text(content="W:%s L:%s" % (truncate(g["win_p"],6), truncate(g["loss_p"],6)), color=COLOR_GRAY, font="CG-pixel-3x5-mono")
        else:
            detail_row = render.Text(content="Final", color=COLOR_GRAY, font="CG-pixel-3x5-mono")
    else:
        outs_vals = [1 if i < g["outs"] else 0 for i in range(3)]
        detail_row = render.Row(children=[
            dot_row(outs_vals, COLOR_WHITE),
            render.Box(width=5, height=3, color=COLOR_BLACK),
            make_dot(g["base1"] == 1, away_c),
            render.Box(width=1, height=3, color=COLOR_BLACK),
            make_dot(g["base2"] == 1, COLOR_YELLOW),
            render.Box(width=1, height=3, color=COLOR_BLACK),
            make_dot(g["base3"] == 1, home_c),
        ])

    return render.Column(
        expanded=True, main_align="start", cross_align="start",
        children=[
            score_row,
            render.Box(height=2),
            status_row,
            render.Box(height=2),
            detail_row,
        ],
    )

def main(config):
    game_pks = fetch_all_game_pks()
    if len(game_pks) == 0:
        return render.Root(
            child=render.Column(
                expanded=True, main_align="center", cross_align="center",
                children=[
                    render.Text(content="MLB", color=COLOR_WHITE, font="6x13"),
                    render.Box(height=2),
                    render.Text(content="No games today", color=COLOR_GRAY, font="CG-pixel-3x5-mono"),
                ],
            ),
        )

    game_list = []
    for pk in game_pks[:10]:
        data = fetch_live(pk)
        if data == None:
            continue
        g = parse_game(data)
        game_list.append(g)

    if len(game_list) == 0:
        return render.Root(
            child=render.Column(
                expanded=True, main_align="center", cross_align="center",
                children=[
                    render.Text(content="MLB", color=COLOR_WHITE, font="6x13"),
                    render.Box(height=2),
                    render.Text(content="No data available", color=COLOR_GRAY, font="CG-pixel-3x5-mono"),
                ],
            ),
        )

    live_games  = [g for g in game_list if g["status"] == "L" or g["status"] == "I"]
    pre_games   = [g for g in game_list if g["status"] == "P"]
    final_games = [g for g in game_list if g["status"] == "F"]
    sorted_games = live_games + pre_games + final_games

    frames = []
    for g in sorted_games:
        card = game_card(g)
        for _ in range(FRAMES_PER_GAME):
            frames.append(card)

    return render.Root(
        delay=50,
        child=render.Animation(children=frames),
    )