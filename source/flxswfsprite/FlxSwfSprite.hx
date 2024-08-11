package flxswfsprite;

import flixel.math.FlxRect;
import openfl.geom.Rectangle;
import flixel.math.FlxPoint;
import lime.utils.Log;
import flixel.util.FlxColor;
import openfl.geom.Matrix;
import openfl.display.Sprite;
import flixel.graphics.FlxGraphic;
import openfl.display.DisplayObject;
import flixel.FlxG;
import openfl.Assets;
import openfl.display.MovieClip;
import flixel.FlxSprite;

using flixel.util.FlxSpriteUtil;
using StringTools;

typedef SymbolData = {
	var name:String;
	var graphic:FlxGraphic;
	var movieClip:MovieClip;
	var activeRect:FlxRect;
	var size:FlxPoint;
	var loop:Bool;
	var fps:Float;
	var indices:Null<Array<Int>>;
}

class FlxSwfSprite extends FlxSprite {
	public static var warn:Bool;

	public var drawScale:Float = 1;

	public var symbolAnimComplete:SymbolData->Void;

	public var symbolFrame(get, set):Int;

	public var playing:Bool;

	public var fps:Float;

	var _animFrame:Float;

	var library:String;

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

	public function addSymbol(symbol:String, name:String = null, fps:Float = 24, loop:Bool = false, ?indices:Array<Int>, ?library:String) {
		library = library ?? this.library;
		final movieClip = Assets.getMovieClip('$library:${formatSymbolName(symbol)}');
		if (movieClip == null) {
			symbolError(symbol);
			return;
		}

		// dumb dumb dumb dumb dumb dumb
		var first = true;
		final rect = FlxRect.get();
		final size = FlxPoint.get();

		
		while (movieClip.currentFrame < movieClip.totalFrames) {
			@:privateAccess
			for (child in movieClip.__children) {
				if (child.x != 0 && rect.x > child.x || rect.x == 0)
					rect.x = child.x;
				if (child.y != 0  && rect.y > child.y|| rect.y == 0)
					rect.y = child.y;
				first = false;
				rect.width = Math.max(rect.width, child.x + child.width);
				rect.height = Math.max(rect.height, child.y + child.height);
			}
			movieClip.nextFrame();
		}
		movieClip.gotoAndStop(0);
		rect.width = rect.width - rect.x;
		rect.height = rect.height - rect.y;
		size.scale(drawScale);
		rect.x *= drawScale;
		rect.y *= drawScale;
		rect.width *= drawScale * 1.5;
		rect.height *= drawScale * 1.5;

		clipContainer.addChild(movieClip);

		final poo:SymbolData = {
			name: name ?? symbol,
			graphic: FlxGraphic.fromRectangle(Math.ceil(rect.width), Math.ceil(rect.height), 0x00, true, '$this$library:$symbol:graphic'),
			movieClip: movieClip,
			loop: loop,
			fps: fps,
			indices: indices,
			activeRect: rect,
			size: size,
		}
		
		poo.graphic.persist = true;

		animationMap.set(poo.name, poo);
	}

	public function playSymbol(name:String) {
		if (!animationMap.exists(name)) {
			symbolError(name);
		} else {
			playing = true;
			currentSymbol = animationMap.get(name);
			symbolFrame = 0;
			_animFrame = 0;
			fps = currentSymbol.fps;
			frames = currentSymbol.graphic.imageFrame;
			updateHitbox();
		}
	}

	override function updateHitbox() {
		frameWidth = Math.ceil(currentSymbol.activeRect.width / 1.5);
		frameHeight = Math.ceil(currentSymbol.activeRect.height / 1.5);
		super.updateHitbox();
	}

	public function symbolExists(name:String) {
		return animationMap.exists(name);
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		if (playing) {
			_animFrame += elapsed * fps;
			var nextFrame = Math.floor(_animFrame);
			if (currentSymbol.indices == null
				&& nextFrame > currentSymbol.movieClip.totalFrames
				|| currentSymbol.indices != null
				&& nextFrame > currentSymbol.indices.length - 1) {
				if (currentSymbol.loop)
					_animFrame = nextFrame = 0;
				else
					playing = false;
				if (symbolAnimComplete != null)
					symbolAnimComplete(currentSymbol);
			}
			if (playing)
				symbolFrame = currentSymbol.indices != null ? currentSymbol.indices[nextFrame] : nextFrame;
		}
	}

	override function draw() {
		if (currentSymbol != null) {
			this.fill(FlxColor.TRANSPARENT);
			symbolMatrix.identity();
			// what the fuck
			symbolMatrix.scale(drawScale, drawScale);
			//symbolMatrix.translate(-currentSymbol.activeRect.x, -currentSymbol.activeRect.y);
			graphic.bitmap.draw(currentSymbol.movieClip, symbolMatrix, null, null, false);
		}
		super.draw();
	}

	override function destroy() {
		super.destroy();
		FlxG.removeChild(clipContainer);
		symbolMatrix = null;
		for (i in animationMap) {
			i.graphic.decrementUseCount();
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
			@:privateAccess
			currentSymbol.movieClip.__timeline.__goto(frame);
		}
		return frame;
	}
}
