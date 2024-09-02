package flxswfsprite;

import flixel.util.FlxSignal.FlxTypedSignal;
import flixel.math.FlxRect;
import flixel.math.FlxPoint;
import flixel.util.FlxColor;
import openfl.geom.Matrix;
import openfl.display.Sprite;
import flixel.graphics.FlxGraphic;
import flixel.FlxG;
import openfl.Assets;
import openfl.display.MovieClip;
import flixel.FlxSprite;

using flixel.util.FlxSpriteUtil;
using flxswfsprite.MovieClipUtil;
using StringTools;

typedef SymbolData = {
	var name:String;
	var graphic:FlxGraphic;
	var movieClip:MovieClip;
	var activeRect:FlxRect;
	var loop:Bool;
	var fps:Float;
	var indices:Null<Array<Int>>;
}

class FlxSwfSprite extends #if flixel_addons flixel.addons.effects.FlxSkewedSprite #else flixel.FlxSprite #end {
	/**
	 * Will warn if theres an error
	 */
	public static var warn:Bool = true;

	/**
	 * The scale that the symbol is drawn at
	 */
	public var drawScale:Float = 1;

	/**
	 * Prevents any Movie Clips from playing at all
	 */
	public var stopMovieClips:Bool;

	// this is a wip at the moment its best to leave this on.
	/**
	 * Syncs all Movie Clips to the main timeline
	 * *note* Doesn't function well with indices
	 */
	public var syncMovieClips:Bool = true;

	/**
	 * Signal called when the current symbol completes its animation
	 */
	public var symbolAnimComplete:FlxTypedSignal<SymbolData->Void> = new FlxTypedSignal<SymbolData->Void>();
	/**
	 * Signal called when the current symbol changes its frame
	 */
	public var symbolAnimFrame:FlxTypedSignal<(SymbolData, Int) -> Void> = new FlxTypedSignal<(SymbolData, Int) -> Void>();

	/**
	 * Whether the symbol is playing. Can be set manually if you want
	 */
	public var playing:Bool;
	/**
	 * The current symbol frame. Can be set manually.
	 */
	public var symbolFrame(get, set):Int;
	/**
	 * If the current symbols animation is complete
	 */
	public var finished(get, null):Bool;

	/**
	 * The framerate of the current symbol. Can be set manually.
	 */
	public var fps:Float;
	
	var curFrame(get, null):Int;

	var _animFrame:Float;

	var _movieClipAnimFrame:Float;

	var library:String;

	/**
	 * A map that contains info about every added symbol
	 */
	var animationMap:Map<String, SymbolData> = [];
	var currentSymbol:SymbolData;

	var clipContainer:Sprite;
	var _clipSize:Sprite;

	var symbolMatrix = new Matrix();

	public function new(x = .0, y = .0, library:String) {
		super(x, y);

		this.library = library;

		clipContainer = new Sprite();
		clipContainer.visible = false;

		_clipSize = new Sprite();
		clipContainer.addChild(_clipSize);

		FlxG.addChildBelowMouse(clipContainer);
	}

	static final _az123:EReg = ~/^[a-z0-9_]+$/i;

	static function formatSymbolName(inp:String) {
		var out = '';

		for (i in 0...inp.length) {
			if (!inp.isSpace(i)) {
				var char = inp.charAt(i);
				if (!_az123.match(char.toLowerCase()))
					char = '_';
				out += char;
			}
		}

		return out;
	}

	function symbolError(symbol:String) {
		final error = 'Couldn\'t find symbol $symbol';

		trace(error);

		if (warn)
			FlxG.log.error(error);
	}

	/**
	 * Adds a symbol as an animation to the sprite
	 * @param symbol The name of the symbol from the library.
	 * @param name Optional name to refer to the animation by. Will be the symbol name if left null
	 * @param fps The fps of the animation
	 * @param loop Whether the animation should loop
	 * @param indices An optional list of frames that the symbol should 
	 * @param library If the symbol comes from a different library, specify here
	 */
	public function addSymbol(symbol:String, name:String = null, fps:Float = 24, loop:Bool = false, ?indices:Array<Int>, ?library:String) {
		library = library ?? this.library;

		final movieClip = Assets.getMovieClip('$library:${formatSymbolName(symbol)}');

		if (movieClip == null) {
			symbolError(symbol);
			return;
		}

		// dumb dumb dumb dumb dumb dumb
		final rect = FlxRect.get();

		while (movieClip.currentFrame < movieClip.totalFrames) {
			for (child in movieClip.getChildren()) {
				if (child.x != 0 && rect.x > child.x || rect.x == 0)
					rect.x = child.x;

				if (child.y != 0 && rect.y > child.y || rect.y == 0)
					rect.y = child.y;

				rect.width = Math.max(rect.width, child.x + child.width);
				rect.height = Math.max(rect.height, child.y + child.height);
			}

			movieClip.nextFrame();
		}

		movieClip.goto(0);

		rect.width = rect.width - rect.x;
		rect.height = rect.height - rect.y;

		rect.x *= drawScale;
		rect.y *= drawScale;

		rect.width *= drawScale * 1.5;
		rect.height *= drawScale * 1.5;

		clipContainer.addChild(movieClip);

		final symbolData:SymbolData = {
			name: name ?? symbol,
			graphic: FlxGraphic.fromRectangle(Math.ceil(rect.width), Math.ceil(rect.height), 0x00, true, '$this$library:$symbol:graphic'),
			movieClip: movieClip,
			loop: loop,
			fps: fps,
			indices: indices,
			activeRect: rect,
		}

		symbolData.graphic.persist = true;
		animationMap.set(symbolData.name, symbolData);
	}

	/**
	 * Play a symbol as an animation
	 * @param name The name of the symbol
	 * @param force If the animation is not complete and you try to play the same anim, it wont unless force is true
	 * @param frame The frame to start on
	 */
	public function playSymbol(name:String, force:Bool = false, frame:Int = 0) {
		if (!animationMap.exists(name)) {
			symbolError(name);
		} else {
			final nextSymbol = animationMap.get(name);
			if (currentSymbol != null && currentSymbol.name == nextSymbol.name && playing && !force)
				return;
			else
				currentSymbol = nextSymbol;
			playing = true;
			currentSymbol.movieClip.stopAllMovieClips();
			if (syncMovieClips)
				updateMovieClips(currentSymbol.movieClip, false);

			symbolFrame = frame;
			_animFrame = frame;
			_movieClipAnimFrame = 0;

			fps = currentSymbol.fps;
			frames = currentSymbol.graphic.imageFrame;
		}
	}

	function resetSymbolSize() {
		if (currentSymbol != null) {
			frameWidth = Math.ceil(currentSymbol.activeRect.width / 1.5);
			frameHeight = Math.ceil(currentSymbol.activeRect.height / 1.5);
		}
		_halfSize.set(0.5 * frameWidth, 0.5 * frameHeight);
		resetSize();
	}

	/**
	 * Returns if a symbol exists in the added animations.
	 * @param name The name of the symbol.
	 */
	public function symbolExists(name:String) {
		return animationMap.exists(name);
	}

	function updateMovieClips(movieClip:MovieClip, advance:Bool, ?skip:Bool) {
		if (!skip) {
			if (advance && !movieClip.isFinished())
				movieClip.nextFrame();
			else
				movieClip.goto(0);
		}
		for (child in movieClip.getChildren()) {
			if (Std.isOfType(child, MovieClip))
				updateMovieClips(cast child, advance);
		}
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (!stopMovieClips) {
			_movieClipAnimFrame += elapsed * fps;
	
			if (_movieClipAnimFrame >= 1) {
				_movieClipAnimFrame = 0;
				updateMovieClips(currentSymbol.movieClip, true, true);
			}
		}

		if (playing) {
			final currentFrame = curFrame;
			_animFrame += elapsed * fps;
			
			if (curFrame != currentFrame)
				symbolAnimFrame.dispatch(currentSymbol, curFrame);

			if (finished) {
				if (currentSymbol.loop)
					_animFrame = 0;
				else
					playing = false;

				symbolAnimComplete.dispatch(currentSymbol);
			}
			symbolFrame = (currentSymbol.indices != null && currentSymbol.indices.length > 0) ? currentSymbol.indices[curFrame] : curFrame;
		}
	}

	override function draw() {
		if (currentSymbol != null) {
			symbolMatrix.identity();

			symbolMatrix.scale(drawScale, drawScale);
			// symbolMatrix.translate(-currentSymbol.activeRect.x, -currentSymbol.activeRect.y);

			graphic.bitmap.draw(currentSymbol.movieClip, symbolMatrix, null, null, false);
		}

		super.draw();
	}

	override function destroy() {
		super.destroy();

		FlxG.removeChild(clipContainer);
		symbolMatrix = null;

		for (i in animationMap) {
			i.activeRect.put();
			i.activeRect = null;
			i.graphic = null;
			i.movieClip = null;
		}

		animationMap.clear();
		animationMap = null;
	}

	inline function get_symbolFrame() {
		return currentSymbol.movieClip.currentFrame;
	}

	inline function set_symbolFrame(frame:Int) {
		if (symbolFrame != frame) {
			if (pixels != null) {
				this.fill(FlxColor.TRANSPARENT);
			}
			currentSymbol.movieClip.goto(frame);
			resetSymbolSize();
		}
		return frame;
	}

	inline function get_finished():Bool {
		if (currentSymbol == null)
			return true;

		if (currentSymbol.indices != null && currentSymbol.indices.length > 0)
			return (curFrame >= currentSymbol.indices.length - 1);
		else
			return currentSymbol.movieClip.isFinished();
	}

	inline function get_curFrame():Int {
		return Math.floor(_animFrame);
	}
}
