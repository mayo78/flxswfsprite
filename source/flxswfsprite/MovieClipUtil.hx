package flxswfsprite;

import openfl.display.MovieClip;

class MovieClipUtil {
	public static function isFinished(movieClip:MovieClip) {
		return movieClip.currentFrame > movieClip.totalFrames;
	}
	
	public static function goto(movieClip:MovieClip, frame:Int) {
		@:privateAccess
		movieClip.__timeline.__goto(frame);
	}

	public static function getChildren(movieClip:MovieClip) {
		@:privateAccess
		return movieClip.__children;
	}
}