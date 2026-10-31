extends Node
## v0.9 in-game updater (autoload "Updater"). docs/UPDATER.md
## - check(): GET the PUBLIC GitHub releases list (no token; pre-releases included, drafts skipped). It picks the
##   highest version tag (vX.Y[.Z]-...) that is newer than this build's application/config/version and has an
##   asset for this platform (_Windows.exe / _Android.apk / _Linux.x86_64).
## - download(): fetches SHA256SUMS.txt, then the asset (follows the GitHub redirect), and verifies the size and
##   SHA-256. A mismatch deletes the file and stops.
## - apply():
##   - Windows: the new exe is downloaded next to the running one; a tiny .bat waits for the game to exit,
##     swaps the exe and relaunches it.
##   - Linux: the same with a .sh script.
##   - Android: OS.shell_open() on the APK. Godot's template hands it to the system installer through its
##     FileProvider (ACTION_VIEW); the REQUEST_INSTALL_PACKAGES permission is set in the export preset, and the
##     same signing key makes it update in place.
## No network, rate limits and HTTP errors only set state = "error" with a message. The game never blocks on it.

signal changed

const REPO := "xenodorian/mera-the-baby-giant"
const API := "https://api.github.com/repos/%s/releases?per_page=40"
const SUFFIX := {"Windows": "_Windows.exe", "Android": "_Android.apk", "Linux": "_Linux.x86_64"}
const SUMS := "SHA256SUMS.txt"

var state := "idle"     # idle | checking | uptodate | available | downloading | ready | installing | error | unsupported
var message := ""
var latest := {}        # tag, name, version [a,b,c], url (asset), asset, size, sums_url, page
var progress := 0.0     # 0..1 while downloading
var file_path := ""     # verified download (absolute path)
var api_url := ""       # override (tests: env MERA_UPDATE_API)
var platform := ""      # override (tests)
var auto_check := true  # check once on the title screen
var auto_checked := false
var _http: HTTPRequest
var _job := ""
var _expect_sha := ""


func _ready() -> void:
	if OS.has_environment("MERA_UPDATE_API"):
		api_url = OS.get_environment("MERA_UPDATE_API")
	_http = HTTPRequest.new()
	_http.timeout = 20.0
	_http.use_threads = true
	_http.max_redirects = 8
	add_child(_http)
	_http.request_completed.connect(_on_done)


func _process(_delta: float) -> void:
	if state == "downloading" and _job == "asset":
		var total := float(latest.get("size", 0))
		if total > 0.0:
			progress = clampf(float(_http.get_downloaded_bytes()) / total, 0.0, 1.0)


# ---------------------------------------------------------------- pure helpers (tested)
static func current_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "0.0.0"))


static func parse_version(tag: String) -> Array:
	var re := RegEx.create_from_string("^v?(\\d+)\\.(\\d+)(?:\\.(\\d+))?")
	var m := re.search(tag)
	if m == null:
		return []
	return [int(m.get_string(1)), int(m.get_string(2)), int(m.get_string(3)) if m.get_string(3) != "" else 0]


static func newer(a: Array, b: Array) -> bool:
	for i in 3:
		if int(a[i]) != int(b[i]):
			return int(a[i]) > int(b[i])
	return false


func platform_name() -> String:
	return platform if platform != "" else OS.get_name()


func supported() -> bool:
	return SUFFIX.has(platform_name())


## the newest release with an asset for this platform that is newer than `cur` ({} if none)
func pick_latest(releases: Array, cur: String) -> Dictionary:
	var best := {}
	var cv := parse_version(cur)
	var suf: String = SUFFIX.get(platform_name(), "")
	for r in releases:
		if typeof(r) != TYPE_DICTIONARY or bool(r.get("draft", false)):
			continue
		var v := parse_version(String(r.get("tag_name", "")))
		if v.is_empty() or not newer(v, cv) or (not best.is_empty() and not newer(v, best["version"])):
			continue
		var asset := {}
		var sums := ""
		for a in r.get("assets", []):
			var n := String(a.get("name", ""))
			if suf != "" and n.ends_with(suf):
				asset = a
			elif n == SUMS:
				sums = String(a.get("browser_download_url", ""))
		if asset.is_empty():
			continue
		best = {"tag": String(r["tag_name"]), "name": String(r.get("name", r["tag_name"])), "version": v,
			"url": String(asset.get("browser_download_url", "")), "asset": String(asset["name"]),
			"size": int(asset.get("size", 0)), "sums_url": sums, "page": String(r.get("html_url", ""))}
	return best


static func parse_sums(text: String) -> Dictionary:
	var out := {}
	for line in text.split("\n"):
		var p := line.strip_edges().split(" ", false)
		if p.size() >= 2 and p[0].length() == 64:
			out[p[p.size() - 1].trim_prefix("*")] = p[0].to_lower()
	return out


static func version_text(v: Array) -> String:
	return "%d.%d.%d" % [v[0], v[1], v[2]] if v.size() == 3 else "?"


## Windows: wait for this process to exit, swap the exe, relaunch, delete the helper
static func windows_helper(pid: int, new_exe: String, exe: String) -> String:
	var n := new_exe.replace("/", "\\")
	var e := exe.replace("/", "\\")
	return "@echo off\r\n" \
		+ ":wait\r\n" \
		+ "tasklist /FI \"PID eq %d\" 2>NUL | find \"%d\" >NUL\r\n" % [pid, pid] \
		+ "if not errorlevel 1 (timeout /t 1 /nobreak >NUL & goto wait)\r\n" \
		+ "move /Y \"%s\" \"%s\" >NUL\r\n" % [n, e] \
		+ "if errorlevel 1 (copy /Y \"%s\" \"%s\" >NUL & del \"%s\")\r\n" % [n, e, n] \
		+ "start \"\" \"%s\"\r\n" % e \
		+ "(goto) 2>NUL & del \"%~f0\"\r\n"


static func posix_helper(pid: int, new_bin: String, bin: String) -> String:
	return "#!/bin/sh\n" \
		+ "while kill -0 %d 2>/dev/null; do sleep 0.3; done\n" % pid \
		+ "mv -f '%s' '%s' && chmod +x '%s'\n" % [new_bin, bin, bin] \
		+ "rm -f \"$0\"\n" \
		+ "exec '%s'\n" % bin


# ---------------------------------------------------------------- flow
func _state(s: String, msg: String = "") -> void:
	state = s
	message = msg
	changed.emit()


func check() -> void:
	if state in ["checking", "downloading", "installing"]:
		return
	if not supported():
		_state("unsupported", "Updates are only offered for the Windows, Linux and Android builds.")
		return
	_job = "check"
	_state("checking", "Checking for updates...")
	var url := api_url if api_url != "" else API % REPO
	var err := _http.request(url, ["User-Agent: MeraTheBabyGiant-Updater", "Accept: application/vnd.github+json"])
	if err != OK:
		_state("error", "Could not start the update check (error %d)." % err)


func download() -> void:
	if state != "available":
		return
	if String(latest.get("sums_url", "")) == "":
		_state("error", "This release has no SHA256SUMS.txt, so it can't be verified. Download it from the releases page.")
		return
	_job = "sums"
	_state("downloading", "Downloading checksums...")
	progress = 0.0
	var err := _http.request(String(latest["sums_url"]), ["User-Agent: MeraTheBabyGiant-Updater"])
	if err != OK:
		_state("error", "Download failed to start (error %d)." % err)


func _target_path() -> String:
	var asset := String(latest["asset"])
	if platform_name() in ["Windows", "Linux"] and not OS.has_feature("editor"):
		var dir := OS.get_executable_path().get_base_dir()
		var probe := dir.path_join(".mera_update_probe")
		var f := FileAccess.open(probe, FileAccess.WRITE)
		if f:
			f.close()
			DirAccess.remove_absolute(probe)
			return dir.path_join(asset + ".new")          # next to the running exe
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://update"))
	return ProjectSettings.globalize_path("user://update").path_join(asset)


func _start_asset() -> void:
	_job = "asset"
	file_path = _target_path()
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
	_http.download_file = file_path
	_state("downloading", "Downloading %s..." % String(latest["asset"]))
	var err := _http.request(String(latest["url"]), ["User-Agent: MeraTheBabyGiant-Updater"])
	if err != OK:
		_http.download_file = ""
		_state("error", "Download failed to start (error %d)." % err)


func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var job := _job
	_job = ""
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		_http.download_file = ""
		var why := "no connection" if result in [HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CANT_RESOLVE, HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR, HTTPRequest.RESULT_TIMEOUT] else ("HTTP %d" % code if result == HTTPRequest.RESULT_SUCCESS else "error %d" % result)
		if job == "asset" and FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
		_state("error", ("Update check failed (%s)." if job == "check" else "Download failed (%s).") % why)
		return
	match job:
		"check":
			var data = JSON.parse_string(body.get_string_from_utf8())
			if typeof(data) != TYPE_ARRAY:
				_state("error", "Update check failed (unexpected reply).")
				return
			latest = pick_latest(data, current_version())
			if latest.is_empty():
				_state("uptodate", "You have the latest version (%s)." % current_version())
			else:
				_state("available", "Update available: v%s (%.1f MB)." % [version_text(latest["version"]), float(latest["size"]) / 1048576.0])
		"sums":
			var sums := parse_sums(body.get_string_from_utf8())
			_expect_sha = String(sums.get(String(latest["asset"]), ""))
			if _expect_sha == "":
				_state("error", "SHA256SUMS.txt has no entry for %s." % String(latest["asset"]))
				return
			_start_asset()
		"asset":
			_http.download_file = ""
			_verify()


func _verify() -> void:
	var size := 0
	var f := FileAccess.open(file_path, FileAccess.READ)
	if f:
		size = f.get_length()
		f.close()
	var sha := FileAccess.get_sha256(file_path).to_lower()
	if size != int(latest["size"]) or sha != _expect_sha:
		DirAccess.remove_absolute(file_path)
		_state("error", "The download did not verify (size %d / %d, checksum %s) and was deleted." % [size, int(latest["size"]), "ok" if sha == _expect_sha else "mismatch"])
		return
	progress = 1.0
	_state("ready", "v%s downloaded and verified." % version_text(latest["version"]))


## install: hands over to the helper / system installer. Returns false when it can't.
func apply() -> bool:
	if state != "ready":
		return false
	var p := platform_name()
	if p == "Android":
		_state("installing", "Opening the installer... (allow \"Install unknown apps\" for this game if Android asks)")
		var err := OS.shell_open(file_path)
		if err != OK:
			_state("error", "Could not open the installer (error %d). The APK is at %s." % [err, file_path])
			return false
		return true
	var exe := OS.get_executable_path()
	if OS.has_feature("editor") or file_path.get_base_dir() != exe.get_base_dir():
		_state("error", "Can't replace this copy of the game (no write access next to it). The new build is at %s." % file_path)
		return false
	var pid := OS.get_process_id()
	var helper: String
	var text: String
	if p == "Windows":
		helper = exe.get_base_dir().path_join("mera_update.bat")
		text = windows_helper(pid, file_path, exe)
	else:
		helper = exe.get_base_dir().path_join("mera_update.sh")
		text = posix_helper(pid, file_path, exe)
	var f := FileAccess.open(helper, FileAccess.WRITE)
	if f == null:
		_state("error", "Could not write the update helper next to the game.")
		return false
	f.store_string(text)
	f.close()
	var started := -1
	if p == "Windows":
		started = OS.create_process("cmd.exe", ["/c", helper.replace("/", "\\")])
	else:
		OS.execute("chmod", ["+x", helper])
		started = OS.create_process("/bin/sh", [helper])
	if started <= 0:
		_state("error", "Could not start the update helper.")
		return false
	_state("installing", "Restarting into v%s..." % version_text(latest["version"]))
	get_tree().quit()
	return true
