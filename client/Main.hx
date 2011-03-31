import flash.display.Stage;
import flash.display.StageAlign;
import flash.display.StageScaleMode;
import flash.display.StageQuality;
import flash.ui.ContextMenu;
import flash.system.Security;
import flash.external.ExternalInterface;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.Error;
import flash.text.TextField;
import flash.geom.Vector3D;

class Main
{
	public static var tf:TextField;
	public static var needRepaint:Bool;

	static function main()
	{
		var root = flash.Lib.current;
		var menu = new ContextMenu();
		menu.hideBuiltInItems();
		root.contextMenu = menu;
		var stage = root.stage;
		stage.align = StageAlign.TOP_LEFT;
		stage.scaleMode = StageScaleMode.NO_SCALE;
		stage.quality = StageQuality.MEDIUM;

		tf = new TextField();
		root.addChild(tf);
		tf.x = 5;
		tf.y = 5;
		tf.width = 500;
		tf.height = 25;
		tf.visible = false;

		Scene.init();

		var wheelPosition:Float = 0.5;
		var getCameraHeight = function():Float
		{
			return 200 + 600*wheelPosition;
		}

		var params = flash.Lib.current.root.loaderInfo.parameters;
		var cameraX:Float = Std.parseFloat(params.x);
		var cameraY:Float = Std.parseFloat(params.y);
		var cameraYaw:Float = -100;

		var repaint = function()
		{
			root.graphics.clear();
			var w = stage.stageWidth;
			var h = stage.stageHeight;
			var mat = new flash.geom.Matrix();
			root.graphics.beginFill(0xffffff);
			root.graphics.drawRect(0, 0, w, h);
			root.graphics.endFill();

			var cameraHeight:Float = getCameraHeight();
			var cameraPitch:Float = 40 + (80 - 40)*wheelPosition;

			Scene.renderScene(flash.Lib.current.graphics, new Vector3D(cameraX, cameraY, cameraHeight), cameraPitch, cameraYaw);
			Main.needRepaint = false;
		}

		var startMouseX = 0.0;
		var startMouseY = 0.0;
		var isDragging = false;

		stage.addEventListener(MouseEvent.MOUSE_DOWN, function(event)
		{
			startMouseX = root.mouseX;
			startMouseY = root.mouseY;
			isDragging = true;
		});

		stage.addEventListener(MouseEvent.MOUSE_MOVE, function(event)
		{
			if (isDragging)
			{
				var mouseX = root.mouseX;
				var mouseY = root.mouseY;
				var speed = (1 + 2*wheelPosition)*(mouseY - startMouseY);
				cameraX += Math.sin(cameraYaw*Math.PI/180)*speed;
				cameraY += Math.cos(cameraYaw*Math.PI/180)*speed;
				cameraYaw -= (mouseX - startMouseX)/5.0;
				startMouseX = mouseX;
				startMouseY = mouseY;
				Main.needRepaint = true;
			}
		});

		stage.addEventListener(MouseEvent.MOUSE_UP, function(event)
		{
			isDragging = false;
		});

		var zoomBy = function(delta)
		{
			wheelPosition += (delta > 0) ? -0.1 : 0.1;
			wheelPosition = Math.max(0, Math.min(1, wheelPosition));
			Main.needRepaint = true;
		}

		ExternalInterface.addCallback("zoomBy", zoomBy);

		/*stage.addEventListener(MouseEvent.MOUSE_WHEEL, function(event:MouseEvent)
		{ 
			zoomBy(event.delta);
		});*/

		var lastWidth = 0;
		var lastHeight = 0;
		var zoomDirection = 0;
		stage.addEventListener(Event.ENTER_FRAME, function(event)
		{
			if (zoomDirection != 0)
				zoomBy(zoomDirection);
			if ((stage.stageWidth != lastWidth) || (stage.stageHeight != lastHeight))
			{
				lastWidth = stage.stageWidth;
				lastHeight = stage.stageHeight;
				Main.needRepaint = true;
			}
			if (Main.needRepaint)
				repaint();
		});

		var currentQuality = 1;
		stage.addEventListener(KeyboardEvent.KEY_DOWN, function(event:KeyboardEvent)
		{
			if (event.keyCode == 73) // i for info
			{
				Main.tf.visible = !Main.tf.visible;
			}
			if (event.keyCode == 81) // q for quality
			{
				if (currentQuality%3 == 0)
					stage.quality = StageQuality.MEDIUM;
				else if (currentQuality%3 == 1)
					stage.quality = StageQuality.HIGH;
				else if (currentQuality%3 == 2)
					stage.quality = StageQuality.LOW;
				currentQuality += 1;
				Main.needRepaint = true;
			}
			if (event.keyCode == 66) // b for buildings
			{
				Scene.buildingsFlag = !Scene.buildingsFlag;
				Main.needRepaint = true;
			}
			if (event.keyCode == 83) // s for surfaces
			{
				Scene.surfacesFlag = !Scene.surfacesFlag;
				Main.needRepaint = true;
			}
			if (event.keyCode == 38) // up arrow
				zoomDirection = 1;
			if (event.keyCode == 40) // down arrow
				zoomDirection = -1;
		});

		stage.addEventListener(KeyboardEvent.KEY_UP, function(event:KeyboardEvent)
		{
			if ((event.keyCode == 38) || (event.keyCode == 40))
				zoomDirection = 0;
		});
	}
}