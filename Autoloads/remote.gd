class_name RemoteConfigController
extends RefCounted

## REST client for Firebase Remote Config.
##
## Firebase does not publish a public gRPC API for Remote Config (unlike
## Firestore). The mobile/web SDKs talk to two REST services:
##   1. Firebase Installations  -> issues an install ID + auth token
##   2. Remote Config `fetch`   -> returns the config entries for that install
##
## This client mirrors that flow using HTTPRequest, matching the pattern
## used by FirebaseAuthRestClient / FirestoreRestClient in this plugin.
##
## PLATFORM GROUPING: this project registers a single Web app in Firebase
## and reuses its App ID/API key for Android and iOS builds. Firebase's
## built-in "platform" condition in the console relies on registering
## distinct Android/iOS apps, so it will NOT distinguish Android from iOS
## here (everything looks like "Web"). Instead this client sends a custom
## signal, "platform" (values: "android", "ios", "web"), on every
## fetch. Use a custom-signal condition in the console —
## platform == 'android' / == 'ios' — to group parameter values by
## platform without registering separate Firebase apps.

const INSTALLATIONS_URL := "https://firebaseinstallations.googleapis.com/v1/projects/%s/installations"
const FETCH_URL := "https://firebaseremoteconfig.googleapis.com/v1/projects/%s/namespaces/firebase:fetch"
const SDK_VERSION := "godot-remote-config/1.0.0"
const PLATFORM_SIGNAL_KEY := "platform"

var _project_id: String
var _api_key: String
var _app_id: String # single Web App ID, shared across Android/iOS/desktop
var _owner: Node

func _init(project_id: String, api_key: String, app_id: String, owner: Node) -> void:
	_project_id = project_id
	_api_key = api_key
	_app_id = app_id
	_owner = owner


## Maps the running OS to the custom signal value used for platform-based
## targeting in the console (platform == 'android' / 'ios' / 'web').
func _resolve_platform() -> String:
	match OS.get_name():
		"Android":
			return "android"
		"iOS":
			return "ios"
		"Web":
			return "web"
		_:
			return "desktop" # editor / desktop testing


## Registers a new Firebase Installation and returns its id + auth token.
## { ok: bool, fid: String, auth_token: String, token_expires_unix: int, error }
func create_installation() -> Dictionary:
	var fid := _generate_fid()
	var body := JSON.stringify({
		"fid": fid,
		"appId": _app_id,
		"authVersion": "FIS_v2",
		"sdkVersion": SDK_VERSION,
	})
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"x-goog-api-key: %s" % _api_key,
	])
	var url := INSTALLATIONS_URL % _project_id
	var result := await _request(url, HTTPClient.METHOD_POST, headers, body)
	if not result.ok:
		return {"ok": false, "error": result.error, "code": result.get("code", -1)}

	var data: Dictionary = result.data
	var auth_token: Dictionary = data.get("authToken", {})
	return {
		"ok": true,
		"fid": str(data.get("fid", fid)),
		"auth_token": str(auth_token.get("token", "")),
		"token_expires_unix": _unix_from_expires_in(str(auth_token.get("expiresIn", "0s"))),
	}


## Fetches remote config values for an existing installation. Includes the
## platform custom signal so console conditions can group values by
## Android/iOS/web/desktop despite sharing one Web App ID.
## Returns { ok: bool, entries: Dictionary, state: String, error }
func fetch_config(installation_id: String, installation_auth_token: String, cache_expiration_seconds := 0) -> Dictionary:
	var body := JSON.stringify({
		"appId": _app_id,
		"appInstanceId": installation_id,
		"appInstanceIdToken": installation_auth_token,
		"sdkVersion": SDK_VERSION,
		"customSignals": {
			PLATFORM_SIGNAL_KEY: _resolve_platform(),
		},
	})
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"x-goog-api-key: %s" % _api_key,
	])
	var url := (FETCH_URL % _project_id) + "?key=" + _api_key
	var result := await _request(url, HTTPClient.METHOD_POST, headers, body)
	if not result.ok:
		return {"ok": false, "error": result.error, "code": result.get("code", -1)}

	var data: Dictionary = result.data
	var raw_entries: Dictionary = data.get("entries", {})
	return {
		"ok": true,
		"entries": raw_entries,
		"state": str(data.get("state", "UPDATE")),
	}


func _request(url: String, method: int, headers: PackedStringArray, body: String) -> Dictionary:
	if _owner == null or not is_instance_valid(_owner):
		return {"ok": false, "error": "owner_node_freed"}
	var http := HTTPRequest.new()
	_owner.add_child(http)
	var err := http.request(url, headers, method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "request_start_failed:%d" % err}

	var response: Array = await http.request_completed
	http.queue_free()

	var response_code: int = response[1]
	var raw_body: PackedByteArray = response[3]
	var text := raw_body.get_string_from_utf8()
	var parsed = JSON.parse_string(text)

	if response_code < 200 or response_code >= 300:
		return {"ok": false, "error": (parsed if parsed != null else text), "code": response_code}
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"ok": false, "error": "invalid_json_response", "code": response_code}
	return {"ok": true, "data": parsed, "code": response_code}


## Generates a Firebase Installations-compliant FID: 22-char base64url
## string encoding 17 bytes, where the first 4 bits are fixed to 0111
## (the "random FID" type marker), per the Installations spec.
func _generate_fid() -> String:
	var bytes := PackedByteArray()
	bytes.resize(17)
	for i in range(17):
		bytes[i] = randi() % 256
	bytes[0] = (bytes[0] & 0x0F) | 0x70 # top nibble -> 0111
	var b64 := Marshalls.raw_to_base64(bytes)
	b64 = b64.replace("+", "-").replace("/", "_").replace("=", "")
	return b64.substr(0, 22)


func _unix_from_expires_in(expires_in: String) -> int:
	var seconds := expires_in.rstrip("s").to_int()
	return int(Time.get_unix_time_from_system()) + seconds
