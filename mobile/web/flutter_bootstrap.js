{{flutter_js}}
{{flutter_build_config}}

// Default to skwasm to avoid CanvasKit WebGL context churn on hot restart.
// Optional override via ?renderer=canvaskit or ?renderer=skwasm.
const _search = new URLSearchParams(window.location.search);
const _renderer = _search.get('renderer');

const _loadOptions = {
	config: { renderer: 'skwasm' },
};

if (_renderer === 'canvaskit' || _renderer === 'skwasm') {
	_loadOptions.config = { renderer: _renderer };
}

_flutter.loader
	.load(_loadOptions)
	.catch(() => {
		// Final fallback: load with auto-detected renderer and default config.
		_flutter.loader.load();
	});
