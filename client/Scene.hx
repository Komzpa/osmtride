import flash.events.Event;
import flash.net.URLLoader;
import flash.net.URLRequest;
import flash.geom.Vector3D;
import flash.geom.Matrix3D;
import flash.display.Graphics;

class Outline {
	public var outline:Array<Float>;
	public var cx:Float;
	public var cy:Float;

	public function new(json:String)
	{
		outline = new Array<Float>();
		var pref = '{"type":"Polygon","coordinates":[[['.length;
		var extent = new Extent();
		for (pair in json.substr(pref, json.length - pref - 4).split("],["))
		{
			var p = pair.split(",");
			var x = Std.parseFloat(p[0]);
			var y = Std.parseFloat(p[1]);
			outline.push(x);
			outline.push(y);
			extent.update(x, y);
		}
		cx = (extent.minx + extent.maxx)/2;
		cy = (extent.miny + extent.maxy)/2;
	}
}

class Building extends Outline {
	public var top:Float;
	public var bottom:Float;

	public function new(json:String, top_:Float, bottom_:Float)
	{
		super(json);
		var mult = Math.cos(Merc.from_y(cy)*Math.PI/180.0);
		top = top_/mult;
		bottom = bottom_/mult;
	}
}

class Surface extends Outline {
	public var color:Int;

	public function new(json:String, type:String)
	{
		super(json);
		if (type == "sand")
			color = 0xf0f0f0;
		else if (type == "asphalt")
			color = 0xb0b0b0;
		else 
			color = 0xe0e0e0;
	}
}

class Scene
{
	static var buildings:Array<Building>;
	static var surfaces:Array<Surface>;
	public static var buildingsFlag:Bool;
	public static var surfacesFlag:Bool;

	public static function init()
	{
		var loadLines = function(url:String, func:Array<String>->Void)
		{
			var loader = new URLLoader(new URLRequest(url));
			loader.addEventListener(Event.COMPLETE, function(event)
			{
				var lines:Array<String> = loader.data.split("\n");
				for (line in lines)
					func(line.split("\t"));
				Main.needRepaint = true;
			});
		}

		buildings = new Array<Building>();
		surfaces = new Array<Surface>();
		buildingsFlag = true;
		surfacesFlag = true;

		loadLines("kc.txt", function(parts)
		{
			buildings.push(new Building(parts[0], Std.parseFloat(parts[2]), Std.parseFloat(parts[1])));
		});

		loadLines("sur.txt", function(parts)
		{
			surfaces.push(new Surface(parts[0], parts[1]));
		});
	}

	static function transformOutline(xy:Array<Float>, z:Float)
	{
		var ret = new Array<Float>();
		for (i in 0...Std.int(xy.length/2))
		{
			var vec = cameraMatrix.transformVector(new Vector3D(xy[2*i], xy[2*i + 1], z));
			var k = screenHeight*0.7;
			var isVisible = (vec.y > 0);
			ret.push(isVisible ? k*vec.x/vec.y + screenWidth*0.5 : 0.0);
			ret.push(isVisible ? -k*vec.z/vec.y + screenHeight*0.5 : 0.0);
		}
		return ret;
	}

	static var cameraMatrix:Matrix3D;
	static var screenWidth:Float;
	static var screenHeight:Float;

	public static function renderScene(graphics:Graphics, camera:Vector3D, cameraPitch:Float, cameraYaw:Float)
	{
		screenWidth = flash.Lib.current.stage.stageWidth;
		screenHeight = flash.Lib.current.stage.stageHeight;
		cameraMatrix = new Matrix3D();
		cameraMatrix.appendTranslation(-camera.x, -camera.y, -camera.z);
		cameraMatrix.appendRotation(cameraYaw, new Vector3D(0.0, 0.0, 1.0));
		cameraMatrix.appendRotation(cameraPitch, new Vector3D(1.0, 0.0, 0.0));

		var screenExtent = new Extent();
		screenExtent.update(0, 0);
		screenExtent.update(screenWidth, screenHeight);

		var grayscale = function(t:Float):Int
		{
			var color:Int = Math.round(255*t);
			return ((color << 16) + (color << 8) + color);
		}
		var polysDrawn = 0;
		var drawPolygon = function(coords:Array<Float>, color:Int, opacity:Float)
		{
			for (c in coords)
				if (c == 0.0)
					return;

			var polyExtent = new Extent();
			for (i in 0...Std.int(coords.length/2))
				polyExtent.update(coords[2*i], coords[2*i + 1]);
			if (!polyExtent.overlaps(screenExtent))
				return;

			graphics.beginFill(color, opacity);
			graphics.moveTo(coords[0], coords[1]);
			for (i in 1...Std.int(coords.length/2))
				graphics.lineTo(coords[2*i], coords[2*i + 1]);
			graphics.endFill();
			polysDrawn += 1;
		}

		var surfacesDrawn = 0;
		if (surfacesFlag)
		{
			for (surface in surfaces)
			{
				var dx = camera.x - surface.cx;
				var dy = camera.y - surface.cy;
				var distance = dx*dx + dy*dy;
				var maxDistance = 3000*1000;
				if (distance > maxDistance)
					continue;

				var t = distance/maxDistance;
				drawPolygon(transformOutline(surface.outline, 0), grayscale(t*0.15 + 0.85), 1.0);
				surfacesDrawn += 1;
			}
		}

		var buildingsDrawn = 0;
		if (buildingsFlag)
		{
			buildings.sort(function(b1, b2)
			{
				var dx1 = b1.cx - camera.x;
				var dy1 = b1.cy - camera.y;
				var dx2 = b2.cx - camera.x;
				var dy2 = b2.cy - camera.y;
				return Std.int(dx2*dx2 + dy2*dy2 - dx1*dx1 - dy1*dy1);
			});
			for (building in buildings)
			{
				var dx = camera.x - building.cx;
				var dy = camera.y - building.cy;
				var distance = dx*dx + dy*dy;
				var maxDistance = 2000*1000;
				if (distance > maxDistance)
					continue;
	
				var t = distance/maxDistance;
				var lineColor = grayscale(t*0.6 + 0.4);
				var wallColor = grayscale(t*0.5 + 0.5);
				var wallColor2 = grayscale(t*0.9 + 0.1);
				var roofColor = grayscale(t*0.3 + 0.7);
	
				var topOutline = transformOutline(building.outline, building.top);
				var bottomOutline = transformOutline(building.outline, building.bottom);
	
				//graphics.lineStyle(Math.NaN, 0, 0.0);
				//drawPolygon(bottomOutline, roofColor);
	
				graphics.lineStyle(1, lineColor, 1.0);
				var len = Std.int(topOutline.length/2);
				for (j in 0...len)
				{
					var i1 = 2*j;
					var i2 = (j == (len - 1)) ? 0 : (2*j + 2);
					var x1 = topOutline[i1];
					var y1 = topOutline[i1 + 1];
					var x2 = topOutline[i2];
					var y2 = topOutline[i2 + 1];
					var x3 = bottomOutline[i2];
					var y3 = bottomOutline[i2 + 1];
					var x4 = bottomOutline[i1];
					var y4 = bottomOutline[i1 + 1];
	
					if ((x2*y3 + x1*y2 + x3*y1) < (x3*y2 + x2*y1 + x1*y3))
						drawPolygon([x1, y1, x2, y2, x3, y3, x4, y4], wallColor2, 0.5);
					else
						drawPolygon([x1, y1, x2, y2, x3, y3, x4, y4], wallColor, 0.5);
				}
	
				graphics.lineStyle(Math.NaN, 0, 0.0);
				drawPolygon(topOutline, roofColor, 0.5);

				buildingsDrawn += 1;
			}
		}

		Main.tf.text = "buildings: " + buildingsDrawn + 
			", surfaces: " + surfacesDrawn +
			", polygons: " + polysDrawn +
			", quality: " + flash.Lib.current.stage.quality;
	}
}