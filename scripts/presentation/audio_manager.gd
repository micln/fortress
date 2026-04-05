class_name AudioManager
extends Node

## 音频管理器
## 
## 职责：背景音乐、音效播放、程序化音频生成
## 调用场景：主场景初始化后，通过信号和直接调用控制音频播放

signal bgm_finished

var _audio_ready: bool = false
var _music_stream: AudioStreamWAV
var _select_sfx_stream: AudioStreamWAV
var _transfer_sfx_stream: AudioStreamWAV
var _attack_sfx_stream: AudioStreamWAV
var _capture_sfx_stream: AudioStreamWAV
var _error_sfx_stream: AudioStreamWAV
var _victory_sfx_stream: AudioStreamWAV
var _defeat_sfx_stream: AudioStreamWAV

var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer


## 初始化音频管理器，传入场景中的音频播放器节点。
##
## 调用场景：主场景 _ready() 时。
## 主要逻辑：保存播放器引用，生成程序化音频流，连接 BGM 结束信号。
func setup(bgm_player: AudioStreamPlayer, sfx_player: AudioStreamPlayer) -> void:
	_bgm_player = bgm_player
	_sfx_player = sfx_player
	_bgm_player.finished.connect(_on_bgm_finished)


## 初始化程序化音频，生成所有音效和背景音乐。
##
## 调用场景：setup 之后，游戏开始前（桌面端）或用户首次交互后（Web 端）。
## 主要逻辑：生成所有音频流。Web 平台由于 autoplay 限制，应在用户点击"开始游戏"后再调用。
func initialize_audio() -> void:
	if _audio_ready:
		return  # 已经初始化过，避免重复

	_music_stream = _create_melody_stream([262.0, 330.0, 392.0, 330.0, 440.0, 392.0, 330.0, 294.0], 0.22, 0.16)
	_select_sfx_stream = _create_tone_stream(784.0, 0.09, 0.22)
	_transfer_sfx_stream = _create_two_tone_stream(523.0, 659.0, 0.08, 0.18)
	_attack_sfx_stream = _create_two_tone_stream(392.0, 294.0, 0.07, 0.2)
	_capture_sfx_stream = _create_two_tone_stream(659.0, 988.0, 0.09, 0.22)
	_error_sfx_stream = _create_tone_stream(220.0, 0.11, 0.18)
	_victory_sfx_stream = _create_melody_stream([523.0, 659.0, 784.0, 1046.0], 0.12, 0.24)
	_defeat_sfx_stream = _create_melody_stream([392.0, 330.0, 262.0], 0.18, 0.2)
	_audio_ready = true


## 在背景音乐未播放时启动循环旋律。
##
## 调用场景：开始游戏、重开后重新进入对局。
## 主要逻辑：避免重复调用 play() 打断正在播放的音乐。
func play_bgm_if_needed() -> void:
	if not _audio_ready or _bgm_player.playing:
		return
	_bgm_player.stream = _music_stream
	_bgm_player.play()


## 停止背景音乐播放。
##
## 调用场景：游戏暂停或结束时。
func stop_bgm() -> void:
	if _bgm_player.playing:
		_bgm_player.stop()


## 背景音乐播放结束后自动续播。
##
## 调用场景：AudioStreamPlayer.finished 信号触发时。
## 主要逻辑：发出信号供主场景判断是否需要继续播放。
func _on_bgm_finished() -> void:
	bgm_finished.emit()


## 播放一段短音效流。
##
## 调用场景：所有用户操作与关键战斗反馈。
## 主要逻辑：把生成好的 WAV 流挂到 SFX 播放器上并立即播放；若音频未初始化则直接跳过。
func play_sfx(stream: AudioStreamWAV) -> void:
	if not _audio_ready or stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.play()


## 通过 ID 播放预设音效。
##
## 调用场景：需要播放标准音效时，简化调用方代码。
## 支持的 sfx_id: "select", "transfer", "attack", "capture", "error", "victory", "defeat"
func play_sfx_by_id(sfx_id: String) -> void:
	match sfx_id:
		"select":
			play_sfx(_select_sfx_stream)
		"transfer":
			play_sfx(_transfer_sfx_stream)
		"attack":
			play_sfx(_attack_sfx_stream)
		"capture":
			play_sfx(_capture_sfx_stream)
		"error":
			play_sfx(_error_sfx_stream)
		"victory":
			play_sfx(_victory_sfx_stream)
		"defeat":
			play_sfx(_defeat_sfx_stream)


## 获取各类音效流，供外部直接播放或检查。
##
## 调用场景：需要直接访问音频流时。
func get_select_sfx() -> AudioStreamWAV:
	return _select_sfx_stream

func get_transfer_sfx() -> AudioStreamWAV:
	return _transfer_sfx_stream

func get_attack_sfx() -> AudioStreamWAV:
	return _attack_sfx_stream

func get_capture_sfx() -> AudioStreamWAV:
	return _capture_sfx_stream

func get_error_sfx() -> AudioStreamWAV:
	return _error_sfx_stream

func get_victory_sfx() -> AudioStreamWAV:
	return _victory_sfx_stream

func get_defeat_sfx() -> AudioStreamWAV:
	return _defeat_sfx_stream


## 生成单音短音效流。
##
## 调用场景：选择、错误等简单提示音创建时。
## 主要逻辑：把给定频率、时长和音量包装成一个只有单个音高的 WAV。
func _create_tone_stream(frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	return _create_melody_stream([frequency], duration, volume)


## 生成包含两个音高的短音效流。
##
## 调用场景：运兵、进攻、占城等需要更强识别度的提示音创建时。
## 主要逻辑：按顺序拼接两个音高，形成更明显的听觉差异。
func _create_two_tone_stream(first_frequency: float, second_frequency: float, duration: float, volume: float) -> AudioStreamWAV:
	return _create_melody_stream([first_frequency, second_frequency], duration, volume)


## 根据一组音高序列生成可播放的 WAV 音频流。
##
## 调用场景：背景音乐和各类音效初始化时。
## 主要逻辑：按音符序列采样正弦波，并对每个音符做淡入淡出，避免爆音和断点杂音。
func _create_melody_stream(frequencies: Array[float], note_duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate: int = 22050
	var pcm_data: PackedByteArray = PackedByteArray()

	for frequency: float in frequencies:
		var note_bytes: PackedByteArray = _append_note_bytes(frequency, note_duration, volume, sample_rate)
		pcm_data.append_array(note_bytes)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = pcm_data
	return stream


## 为单个音符生成一段 16 位 PCM 字节数据。
##
## 调用场景：旋律流构建时逐个音符调用。
## 主要逻辑：按采样率逐点生成正弦波，并在首尾加包络衰减，让短音频听感更柔和。
func _append_note_bytes(frequency: float, duration: float, volume: float, sample_rate: int) -> PackedByteArray:
	var total_samples: int = max(1, int(duration * sample_rate))
	var fade_samples: int = max(1, min(int(floor(float(total_samples) / 4.0)), int(sample_rate * 0.02)))
	var bytes: PackedByteArray = PackedByteArray()

	for sample_index: int in range(total_samples):
		var envelope: float = 1.0
		if sample_index < fade_samples:
			envelope = float(sample_index) / float(fade_samples)
		elif sample_index > total_samples - fade_samples:
			envelope = float(total_samples - sample_index) / float(fade_samples)

		var phase: float = TAU * frequency * float(sample_index) / float(sample_rate)
		var sample_value: float = sin(phase) * volume * clamp(envelope, 0.0, 1.0)
		var sample_int: int = int(clamp(sample_value, -1.0, 1.0) * 32767.0)
		var packed_sample: int = sample_int & 0xffff
		bytes.append(packed_sample & 0xff)
		bytes.append((packed_sample >> 8) & 0xff)

	return bytes
