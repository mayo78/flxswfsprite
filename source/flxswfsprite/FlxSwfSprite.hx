package flxswfsprite;

import flixel.math.FlxAngle;
import flixel.FlxCamera;
import flixel.graphics.frames.FlxFrame;
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
	var frames:Array<FlxFrame>;
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
	public final symbolAnimComplete:FlxTypedSignal<SymbolData->Void> = new FlxTypedSignal<SymbolData->Void>();
	/**
	 * Signal called when the current symbol changes its frame
	 */
	public final symbolAnimFrame:FlxTypedSignal<(SymbolData, Int) -> Void> = new FlxTypedSignal<(SymbolData, Int) -> Void>();

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

	/**
	 * Experimental
	 * Will make FlxFrames similar to a standard spritesheet for every frame
	 */
	public final renderFrames:Bool;
	
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

	var symbolMatrix = new Matrix();

	var symbolDirty:Bool = true;

	public function new(x = .0, y = .0, library:String, renderFrames:Bool = false) {
		super(x, y);

		this.renderFrames = renderFrames;

		this.library = library;

		if (!renderFrames) {
			clipContainer = new Sprite();
			clipContainer.visible = false;
	
			FlxG.addChildBelowMouse(clipContainer);
		}
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
		final frames = new Array<FlxFrame>();

		while (movieClip.currentFrame < movieClip.totalFrames) {
			var minX = .0;
			var minY = .0;
			var maxX = .0;
			var maxY = .0;
			for (child in movieClip.getChildren()) {
				if (!renderFrames) {
					if (child.x != 0 && rect.x > child.x || rect.x == 0)
						rect.x = child.x;
	
					if (child.y != 0 && rect.y > child.y || rect.y == 0)
						rect.y = child.y;
	
					rect.width = Math.max(rect.width, child.x + child.width);
					rect.height = Math.max(rect.height, child.y + child.height);
				} else {
					minX = Math.min(minX, child.x);
					minY = Math.min(minY, child.y);
					maxX = Math.max(maxX, child.x + child.width);
					maxY = Math.max(maxY, child.y + child.height);
				}
			}
			if (renderFrames) {
				final key = '$library$symbol:frame${movieClip.currentFrame}';
				var graphic = FlxG.bitmap.get(key);
				if (graphic == null) {
					graphic = FlxGraphic.fromRectangle(Math.ceil(maxX - minY), Math.ceil(maxY - minY), 0x00, false, key);
					graphic.persist = true;
					graphic.imageFrame.frame.offset.set(minX, minY);
					symbolMatrix.identity();
					symbolMatrix.translate(-minX, -minY);
					symbolMatrix.scale(drawScale, drawScale);
					graphic.bitmap.draw(movieClip, symbolMatrix, null, null, false);
				}
				#if (flixel < "5.4.0")
				frame.parent.useCount++;
				#else
				frame.parent.incrementUseCount();
				#end
				frames.push(graphic.imageFrame.frame);
			}

			movieClip.nextFrame();
		}

		if (!renderFrames) {
			movieClip.goto(0);
	
			rect.width = rect.width - rect.x;
			rect.height = rect.height - rect.y;
	
			rect.x *= drawScale;
			rect.y *= drawScale;
	
			rect.width *= drawScale * 1.5;
			rect.height *= drawScale * 1.5;
	
			clipContainer.addChild(movieClip);
		}

		final symbolData:SymbolData = {
			name: name ?? symbol,
			graphic: renderFrames ? null : FlxGraphic.fromRectangle(Math.ceil(rect.width), Math.ceil(rect.height), 0x00, true, '$this$library:$symbol:graphic'),
			movieClip: movieClip,
			loop: loop,
			fps: fps,
			indices: indices,
			activeRect: rect,
			frames: frames,
		}

		if (!renderFrames)
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
			if (!renderFrames) {
				currentSymbol.movieClip.stopAllMovieClips();
				if (syncMovieClips)
					updateMovieClips(currentSymbol.movieClip, false);
			}

			symbolFrame = frame;
			_animFrame = frame;
			_movieClipAnimFrame = 0;

			fps = currentSymbol.fps;
			if (!renderFrames)
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
		//movieClip.stop();
		for (child in movieClip.getChildren()) {
			if (Std.isOfType(child, MovieClip))
				updateMovieClips(cast child, advance);
		}
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (!stopMovieClips && !renderFrames) {
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

	function redrawSymbol() {
		if (pixels != null) {
			this.fill(FlxColor.TRANSPARENT);
			symbolMatrix.identity();
			symbolMatrix.scale(drawScale, drawScale);
			graphic.bitmap.draw(currentSymbol.movieClip, symbolMatrix, null, null, false);
		}
		symbolDirty = false;
	}

	override function draw() {
		if (currentSymbol != null && symbolDirty && !renderFrames) {
			redrawSymbol();
		}

		super.draw();
	}

	override function isSimpleRender(?camera:FlxCamera):Bool {
		if (drawScale != 1)
			return false;
		return super.isSimpleRender(camera);
	}

	override function drawComplex(camera:FlxCamera):Void
	{
		_frame.prepareMatrix(_matrix, FlxFrameAngle.ANGLE_0, checkFlipX(), checkFlipY());
		final inv = 1 / drawScale;
		_matrix.scale(inv, inv);
		_matrix.translate(-origin.x, -origin.y);
		_matrix.scale(scale.x, scale.y);

		if (bakedRotationAngle <= 0)
		{
			updateTrig();

			if (angle != 0)
				_matrix.rotateWithTrig(_cosAngle, _sinAngle);
		}

		getScreenPosition(_point, camera).subtractPoint(offset);
		_point.add(origin.x, origin.y);
		_matrix.translate(_point.x, _point.y);

		if (isPixelPerfectRender(camera))
		{
			_matrix.tx = Math.floor(_matrix.tx);
			_matrix.ty = Math.floor(_matrix.ty);
		}

		camera.drawPixels(_frame, framePixels, _matrix, colorTransform, blend, antialiasing, shader);
	}

	override function destroy() {
		super.destroy();

		if (!renderFrames)
			FlxG.removeChild(clipContainer);
		symbolMatrix = null;

		for (i in animationMap) {
			i.activeRect.put();
			i.activeRect = null;
			i.movieClip = null;
			if (renderFrames) {
				while (i.frames.length > 0) {
					final frame = i.frames.pop();
					if (frame != null && frame.parent != null) {
						#if (flixel < "5.4.0")
						frame.parent.useCount--;
						#else
						frame.parent.decrementUseCount();
						#end
						frame.destroy();
					}
				}
			} else {
				i.graphic.destroy();
				i.graphic = null;
			}
			i.frames = null;
		}

		animationMap.clear();
		animationMap = null;

		symbolAnimComplete.destroy();
		symbolAnimFrame.destroy();

	}

	inline function get_symbolFrame() {
		return currentSymbol.movieClip.currentFrame;
	}

	inline function set_symbolFrame(frame:Int) {
		if (symbolFrame != frame) {
			if (renderFrames) {
				this.frame = currentSymbol.frames[frame];
			} else {
				currentSymbol.movieClip.goto(frame);
				resetSymbolSize();
				symbolDirty = true;
			}
		}
		return frame;
	}

	inline function get_finished():Bool {
		if (currentSymbol == null)
			return true;

		if (currentSymbol.indices != null && currentSymbol.indices.length > 0)
			return curFrame >= currentSymbol.indices.length - 1;
		else if (renderFrames)
			return curFrame >= currentSymbol.frames.length - 1;
		else
			return currentSymbol.movieClip.isFinished();
	}

	inline function get_curFrame():Int {
		return Math.floor(_animFrame);
	}
}
