## Participant — one soldier in the match (the local player now; bots and network peers later).
## Owned by MatchManager. Plain data so it can be replicated or shown on a scoreboard.

class_name Participant
extends RefCounted

var id: int = 0
var display_name: String = ""
var team: int = Teams.NONE
var kit_id: int = 0
var actor: Node3D = null  ## The body in the world (PlayerController now, bots later)
var is_local: bool = false
var is_bot: bool = false

var alive: bool = true
var death_time: float = -INF  ## MatchManager clock time of the last death

var kills: int = 0
var deaths: int = 0
var score: int = 0
