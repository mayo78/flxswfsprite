package flxswfsprite;

import lime.utils.Log;
import lime.utils.AssetLibrary;
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
	var stageWidth:Float;
	var stageHeight:Float;
	var loop:Bool;
	var fps:Float;
	var indices:Null<Array<Int>>;
}

class FlxSwfSprite extends FlxSprite {
	public var symbolAnimComplete:SymbolData->Void;

	public var symbolFrame(get, set):Int;

	public var playing:Bool;

	public var fps:Float;

	var _animFrame:Float;

	var library:String;

	var assetLibrary:AssetLibrary;

	var animationMap:Map<String, SymbolData> = [];

	var currentSymbol:SymbolData;

	var clipContainer:Sprite;

	var _clipSize:Sprite;

	var symbolMatrix = new Matrix();

	public function new(x = .0, y = .0, library:String) {
		super(x, y);

		this.library = library;
		assetLibrary = Assets.getLibrary(library);
		trace(library, assetLibrary, assetLibrary.list(null));

		clipContainer = new Sprite();
		clipContainer.visible = false;
		_clipSize = new Sprite();
		clipContainer.addChild(_clipSize);
		FlxG.addChildBelowMouse(clipContainer);
	}

	// me wnen i forget how to use eregs and dont care enough to look it up
	static final _az123 = 'abcdefghijklmnopqrstuvwxyz1234567890_';

	static function formatSymbolName(inp:String) {
		var out = '';
		var i = 0;
		while (i < inp.length) {
			if (!inp.isSpace(i)) {
				var char = inp.charAt(i);
				if (!_az123.contains(char.toLowerCase()))
					char = '_';
				out += char;
			}
			i++;
		}
		return out;
	}

	function symbolCheck(symbol:String) {
		return assetLibrary.exists(formatSymbolName(symbol), null);
	}

	function symbolError(symbol:String) {
		FlxG.log.error('Couldn\'t find symbol $symbol');
	}

	public function addSymbol(symbol:String, name:String = null, fps:Float = 24, loop:Bool = false, ?indices:Array<Int>) {
		if (!symbolCheck(symbol) && Log.throwErrors) {
			symbolError(symbol);
			return;
		}
		final movieClip = Assets.getMovieClip('$library:${formatSymbolName(symbol)}');
		if (movieClip == null) {
			symbolError(symbol);
			return;
		}

		// dumb dumb dumb dumb dumb dumb
		var mW = .0;
		var mH = .0;
		var mSW = .0;
		var mSH = .0;

		_clipSize.addChild(movieClip);
		while (movieClip.currentFrame < movieClip.totalFrames) {
			// no matter what i could not get a proper size (due to registration points i think??) so whatever
			mW = Math.max(mW, _clipSize.width * 1.5);
			mH = Math.max(mH, _clipSize.height * 1.5);
			mSW = Math.max(mSW, _clipSize.stage.width);
			mSH = Math.max(mSH, _clipSize.stage.height);
			movieClip.nextFrame();
		}
		_clipSize.removeChild(movieClip);
		clipContainer.addChild(movieClip);

		final poo:SymbolData = {
			name: name ?? symbol,
			graphic: FlxGraphic.fromRectangle(Math.ceil(mW), Math.ceil(mH), 0x00, true, '$library:$symbol:graphic'),
			movieClip: movieClip,
			loop: loop,
			fps: fps,
			stageWidth: mSW,
			stageHeight: mSH,
			indices: indices,
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
		}
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
			symbolMatrix.translate(currentSymbol.graphic.width / 2.5, (-currentSymbol.stageHeight / 1.5) + currentSymbol.graphic.height / 1.5);
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
