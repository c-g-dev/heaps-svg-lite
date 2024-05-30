package hx.heaps.svglite;

import h2d.Graphics;
import haxe.xml.Parser;

using StringTools;

class SvgRenderer {
	var currentColor:Int = 0xFFFFFF;
	var strokes:Array<GraphicsCommands> = [];
    var unitSize: Int = 1;

	public function new() {}

	public function setCurrentColor(currentColor:Int) {
		this.currentColor = currentColor;
	}

    public function setUnitSize(unitSize:Int) {
		this.unitSize = unitSize;
	}

	public function render(svgString:String, g:Graphics):Void {
		strokes = [];
		var xml = Parser.parse(svgString);
		var svgTag = xml.firstElement();
		handleSvgAttributes(svgTag);

		for (child in svgTag.elements()) {
			switch (child.nodeType) {
				case Xml.Element:
					{
						var tagName = child.nodeName;
						switch (tagName) {
							case 'path':
								var d = child.get('d');
								drawPath(d);
							case 'ellipse':
								var cx = Std.parseFloat(child.get('cx'));
								var cy = Std.parseFloat(child.get('cy'));
								var rx = Std.parseFloat(child.get('rx'));
								var ry = Std.parseFloat(child.get('ry'));
								strokes.push(GraphicsCommands.DrawEllipse(cx, cy, rx, ry, 0, 0));
							case 'line':
								var x1 = Std.parseFloat(child.get('x1'));
								var y1 = Std.parseFloat(child.get('y1'));
								var x2 = Std.parseFloat(child.get('x2'));
								var y2 = Std.parseFloat(child.get('y2'));
								strokes.push(GraphicsCommands.MoveTo(x1, y1));
								strokes.push(GraphicsCommands.LineTo(x2, y2));
							case 'circle':
								var cx = Std.parseFloat(child.get('cx'));
								var cy = Std.parseFloat(child.get('cy'));
								var r = Std.parseFloat(child.get('r'));
								strokes.push(GraphicsCommands.DrawCircle(cx, cy, r));
							case 'rect':
								var x = Std.parseFloat(child.get('x'));
								var y = Std.parseFloat(child.get('y'));
								var width = Std.parseFloat(child.get('width'));
								var height = Std.parseFloat(child.get('height'));
								var rx:Null<Float> = Std.parseFloat(child.get('rx'));
								var ry:Null<Float> = Std.parseFloat(child.get('ry'));
								strokes.push(GraphicsCommands.MoveTo(x, y));
								if ((rx != null || ry != null) && (rx != 0 || ry != 0)) {
									strokes.push(GraphicsCommands.DrawRoundedRect(x, y, width, height, rx));
								} else {
									strokes.push(GraphicsCommands.DrawRect(x, y, width, height));
								}
							case 'polygon':
								var points = parsePoints(child.get('points'));
								if (points.length > 0) {
									strokes.push(GraphicsCommands.MoveTo(points[0].x, points[0].y));
									for (i in 1...points.length) {
										strokes.push(GraphicsCommands.LineTo(points[i].x, points[i].y));
										strokes.push(GraphicsCommands.MoveTo(points[i].x, points[i].y));
									}
									strokes.push(GraphicsCommands.LineTo(points[0].x, points[0].y));
								}
							case 'polyline':
								var points = parsePoints(child.get('points'));
								if (points.length > 0) {
									strokes.push(GraphicsCommands.MoveTo(points[0].x, points[0].y));
									for (i in 1...points.length) {
										strokes.push(GraphicsCommands.LineTo(points[i].x, points[i].y));
										strokes.push(GraphicsCommands.MoveTo(points[i].x, points[i].y));
									}
								}
						}
					}
				default:
			}
		}
		executeCommands(g);
	}

    @:access(h2d.Graphics)
	private function executeCommands(g:Graphics):Void {
		for (cmd in strokes) {
			switch (cmd) {
				case GraphicsCommands.MoveTo(x, y): {
					g.moveTo(x * unitSize, y * unitSize);
				}
				case GraphicsCommands.LineTo(x, y): {
					g.lineTo(x * unitSize, y * unitSize);
				}
				case GraphicsCommands.DrawEllipse(cx, cy, rx, ry, rotation, segments): {
					g.drawEllipse(cx * unitSize, cy * unitSize, rx * unitSize, ry * unitSize, rotation, segments);
				}
				case GraphicsCommands.DrawRect(x, y, width, height): {
					g.drawRect(x * unitSize, y * unitSize, width * unitSize, height * unitSize);
				}
				case GraphicsCommands.DrawCircle(cx, cy, r): {
					g.drawCircle(cx * unitSize, cy * unitSize, r * unitSize);
				}
				case GraphicsCommands.DrawRoundedRect(x, y, width, height, radius): {
					drawRoundedRect(g, x * unitSize, y * unitSize, width * unitSize, height * unitSize, radius * unitSize);
				}
				case GraphicsCommands.CurveTo(cx, cy, x, y): {
					g.curveTo(cx * unitSize, cy * unitSize, x * unitSize, y * unitSize);
				}
				case GraphicsCommands.CubicCurveTo(x, y, cx1, cy1, cx2, cy2, x1, y1): {
					g.cubicCurveTo(cx1 * unitSize, cy1 * unitSize, cx2 * unitSize, cy2 * unitSize, x1 * unitSize, y1 * unitSize);
				}
				case GraphicsCommands.DrawArc(x0, y0, rx, ry, xAxisRotation, largeArcFlag, sweepFlag, dx, dy): {
					drawArc(g, x0 * unitSize, y0 * unitSize, rx * unitSize, ry * unitSize, xAxisRotation, largeArcFlag, sweepFlag, dx * unitSize, dy * unitSize);
				}
				case GraphicsCommands.LineSize(w): {
					g.lineSize = w * unitSize;
				}
				case GraphicsCommands.LineAlpha(a): {
					g.lineA = a;
				}
				case GraphicsCommands.LineColor(r, gCol, b): {
					g.lineR = r;
					g.lineG = gCol;
					g.lineB = b;
				}
				case GraphicsCommands.Flush: {
					g.flush();
				}
			}
		}
	}

	private function getMatches(ereg:EReg, input:String, index:Int = 0):Array<String> {
		var matches = [];
		while (ereg.match(input)) {
			matches.push(ereg.matched(index));
			input = ereg.matchedRight();
		}
		return matches;
	}

	private function drawPath(d:String):Void {
		var commandRegex = ~/[a-zA-Z][^a-zA-Z]*/g;
		var commands = getMatches(commandRegex, d);
		var currentPoint = {x: 0.0, y: 0.0};
		var lastControlPoint = null;
		var firstPoint = null;
		for (command in commands) {
			var type = command.charAt(0);
			var data = [];
			for (s in command.substring(1).trim().split(" ")) {
				var nums = getMatches(~/-?\d*\.?\d+/g, s);
				for (n in nums) {
					data.push(Std.parseFloat(n));
				}
			}

			var isRelative = type >= 'a' && type <= 'z';
			type = type.toUpperCase();

			switch (type) {
				case 'M':
					if (isRelative) {
						currentPoint = {x: currentPoint.x + data[0], y: currentPoint.y + data[1]};
					} else {
						currentPoint = {x: data[0], y: data[1]};
					}
					strokes.push(GraphicsCommands.MoveTo(currentPoint.x, currentPoint.y));
					if (firstPoint == null) {
						firstPoint = currentPoint;
					}
				case 'L':
					for (i in 0...data.length) {
						if (i % 2 == 0) {
							if (isRelative) {
								currentPoint = {x: currentPoint.x + data[i], y: currentPoint.y + data[i + 1]};
							} else {
								currentPoint = {x: data[i], y: data[i + 1]};
							}
							strokes.push(GraphicsCommands.LineTo(currentPoint.x, currentPoint.y));
						}
					}
				case 'H':
					for (x in data) {
						if (isRelative) {
							currentPoint.x += x;
						} else {
							currentPoint.x = x;
						}
						strokes.push(GraphicsCommands.LineTo(currentPoint.x, currentPoint.y));
					}
				case 'V':
					for (y in data) {
						if (isRelative) {
							currentPoint.y += y;
						} else {
							currentPoint.y = y;
						}
						strokes.push(GraphicsCommands.LineTo(currentPoint.x, currentPoint.y));
					}
				case 'C':
					for (i in 0...data.length) {
						if (i % 6 == 0) {
							var cx1 = isRelative ? currentPoint.x + data[i] : data[i];
							var cy1 = isRelative ? currentPoint.y + data[i + 1] : data[i + 1];
							var cx2 = isRelative ? currentPoint.x + data[i + 2] : data[i + 2];
							var cy2 = isRelative ? currentPoint.y + data[i + 3] : data[i + 3];
							var x = isRelative ? currentPoint.x + data[i + 4] : data[i + 4];
							var y = isRelative ? currentPoint.y + data[i + 5] : data[i + 5];
							strokes.push(GraphicsCommands.CubicCurveTo(currentPoint.x, currentPoint.y, cx1, cy1, cx2, cy2, x, y));
							currentPoint = {x: x, y: y};
							lastControlPoint = {x: cx2, y: cy2};
						}
					}
				case 'S':
					for (i in 0...data.length) {
						if (i % 4 == 0) {
							var reflectedControlPoint = (lastControlPoint != null) ? {
								x: 2 * currentPoint.x - lastControlPoint.x,
								y: 2 * currentPoint.y - lastControlPoint.y
							} : {x: currentPoint.x, y: currentPoint.y};
							var cx = isRelative ? currentPoint.x + data[i] : data[i];
							var cy = isRelative ? currentPoint.y + data[i + 1] : data[i + 1];
							var x = isRelative ? currentPoint.x + data[i + 2] : data[i + 2];
							var y = isRelative ? currentPoint.y + data[i + 3] : data[i + 3];
							strokes.push(GraphicsCommands.CubicCurveTo(currentPoint.x, currentPoint.y, reflectedControlPoint.x, reflectedControlPoint.y, cx,
								cy, x, y));
							lastControlPoint = {x: cx, y: cy};
							currentPoint = {x: x, y: y};
						}
					}
				case 'Q':
					for (i in 0...data.length) {
						if (i % 4 == 0) {
							var cx = isRelative ? currentPoint.x + data[i] : data[i];
							var cy = isRelative ? currentPoint.y + data[i + 1] : data[i + 1];
							var x = isRelative ? currentPoint.x + data[i + 2] : data[i + 2];
							var y = isRelative ? currentPoint.y + data[i + 3] : data[i + 3];
							strokes.push(GraphicsCommands.CurveTo(cx, cy, x, y));
							currentPoint = {x: x, y: y};
							lastControlPoint = {x: cx, y: cy};
						}
					}
				case 'T':
					for (i in 0...data.length) {
						if (i % 2 == 0) {
							var reflectedControlPoint = (lastControlPoint != null) ? {
								x: 2 * currentPoint.x - lastControlPoint.x,
								y: 2 * currentPoint.y - lastControlPoint.y
							} : {x: currentPoint.x, y: currentPoint.y};
							var x = isRelative ? currentPoint.x + data[i] : data[i];
							var y = isRelative ? currentPoint.y + data[i + 1] : data[i + 1];
							strokes.push(GraphicsCommands.CurveTo(reflectedControlPoint.x, reflectedControlPoint.y, x, y));
							lastControlPoint = reflectedControlPoint;
							currentPoint = {x: x, y: y};
						}
					}
				case 'A':
                    strokes.push(GraphicsCommands.MoveTo(currentPoint.x, currentPoint.y));
					for (i in 0...data.length) {
						if (i % 7 == 0) {
							var rx = data[i];
							var ry = data[i + 1];
							var angle = data[i + 2];
							var largeArcFlag = Std.int(data[i + 3]);
							var sweepFlag = Std.int(data[i + 4]);
							var x = isRelative ? currentPoint.x + data[i + 5] : data[i + 5];
							var y = isRelative ? currentPoint.y + data[i + 6] : data[i + 6];
							strokes.push(GraphicsCommands.DrawArc(currentPoint.x, currentPoint.y, rx, ry, angle, largeArcFlag, sweepFlag, x - currentPoint.x,
								y - currentPoint.y));
							currentPoint = {x: x, y: y};
                            strokes.push(GraphicsCommands.MoveTo(currentPoint.x, currentPoint.y));
						}
					}
				case 'Z':
					strokes.push(GraphicsCommands.MoveTo(currentPoint.x, currentPoint.y));
					strokes.push(GraphicsCommands.LineTo(firstPoint.x, firstPoint.y));
			}
		}
	}

	private function handleSvgAttributes(svgElement:Xml):Void {
		var width = svgElement.get('width');
		var height = svgElement.get('height');
		var viewBox = svgElement.get('viewBox');
		var fill = svgElement.get('fill');
		var stroke = svgElement.get('stroke');
		var strokeWidth = svgElement.get('stroke-width');
		var strokeLinecap = svgElement.get('stroke-linecap');
		var strokeLinejoin = svgElement.get('stroke-linejoin');
		var classAttr = svgElement.get('class');

		var styles:Array<SVGStyle> = [];
		if (stroke != null && stroke != "currentColor") {
			styles.push(SVGStyle.Stroke(parseHexColor(stroke)));
		}
		if (stroke != null && stroke == "currentColor") {
			styles.push(SVGStyle.Stroke(currentColor));
		}
		if (strokeWidth != null) {
			styles.push(SVGStyle.StrokeWidth(Std.parseFloat(strokeWidth)));
		}
		setGraphicsStyle(styles);
	}

	private function setGraphicsStyle(styles:Array<SVGStyle>):Void {
		strokes.push(GraphicsCommands.Flush);
		strokes.push(GraphicsCommands.LineAlpha(1));
		for (style in styles) {
			switch (style) {
				case SVGStyle.Fill(color):
					{
						// Handle fill color
					}
				case SVGStyle.Stroke(color):
					{
						var c = color;
						strokes.push(GraphicsCommands.LineColor(((c >> 16) & 0xFF) / 255., ((c >> 8) & 0xFF) / 255., (c & 0xFF) / 255.));
					}
				case SVGStyle.StrokeWidth(w):
					strokes.push(GraphicsCommands.LineSize(w));
			}
		}
	}

	@:access(h2d.Graphics) 
public function drawRoundedRect(graphics: h2d.Graphics, x : Float, y : Float, w : Float, h : Float, radius : Float, nsegments = 0 ) {
	if (radius <= 0) {
		return graphics.drawRect(x, y, w, h);
	}
	x += radius;
	y += radius;
	w -= radius * 2;
	h -= radius * 2;
	graphics.flush();
	if( nsegments == 0 )
		nsegments = Math.ceil(Math.abs(radius * hxd.Math.degToRad(90) / 4));
	if( nsegments < 3 ) nsegments = 3;
	var angle = hxd.Math.degToRad(90) / (nsegments - 1);
	inline function corner(x, y, angleStart) {
		graphics.moveTo(x, y);
		for ( i in 0...nsegments) {
			var a = i * angle + hxd.Math.degToRad(angleStart);
			graphics.lineTo(x + Math.cos(a) * radius, y + Math.sin(a) * radius);
		}
	}
	graphics.lineTo(x, y - radius);
	graphics.lineTo(x + w, y - radius);
	
	corner(x + w, y, 270);
	graphics.lineTo(x + w + radius, y + h);
	corner(x + w, y + h, 0);
	graphics.lineTo(x, y + h + radius);
	corner(x, y + h, 90);
	graphics.lineTo(x - radius, y);
	corner(x, y, 180);
	graphics.flush();
}

@:access(h2d.Graphics) 
public function drawArc(graphics: h2d.Graphics, x0: Float, y0: Float, rx: Float, ry: Float, xAxisRotation: Float, largeArcFlag: Int, sweepFlag: Int, dx: Float, dy: Float) {
	graphics.flush();

	var x1 = x0 + dx;
	var y1 = y0 + dy;

	if (rx == 0 && ry == 0) {
		graphics.lineTo(x1, y1);
		return;
	}

	var rad = Math.PI / 180 * xAxisRotation;
	var cosRad = Math.cos(rad);
	var sinRad = Math.sin(rad);

	var dx2 = (x0 - x1) / 2;
	var dy2 = (y0 - y1) / 2;
	var x1p = cosRad * dx2 + sinRad * dy2;
	var y1p = -sinRad * dx2 + cosRad * dy2;

	var rxSq = rx * rx;
	var rySq = ry * ry;
	var x1pSq = x1p * x1p;
	var y1pSq = y1p * y1p;

	var radicant = ((rxSq * rySq) - (rxSq * y1pSq) - (rySq * x1pSq)) / ((rxSq * y1pSq) + (rySq * x1pSq));
	radicant = Math.max(radicant, 0);
	var factor = (largeArcFlag == sweepFlag ? -1 : 1) * Math.sqrt(radicant);

	var cxp = factor * ((rx * y1p) / ry);
	var cyp = factor * (-(ry * x1p) / rx);

	var cx = cosRad * cxp - sinRad * cyp + (x0 + x1) / 2;
	var cy = sinRad * cxp + cosRad * cyp + (y0 + y1) / 2;

	var startAngle = Math.atan2((y1p - cyp) / ry, (x1p - cxp) / rx);
	var endAngle = Math.atan2((-y1p - cyp) / ry, (-x1p - cxp) / rx);

	var angleDiff = endAngle - startAngle;
	if (sweepFlag == 0 && angleDiff > 0) angleDiff -= 2 * Math.PI;
	else if (sweepFlag == 1 && angleDiff < 0) angleDiff += 2 * Math.PI;

	var nsegments = Math.ceil(Math.abs(angleDiff / (Math.PI / 4)));
	var angleStep = angleDiff / nsegments;
	for (i in 0...nsegments + 1) {
		var angle = startAngle + i * angleStep;
		var x = cx + Math.cos(angle) * rx;
		var y = cy + Math.sin(angle) * ry;
		graphics.lineTo(x, y);
	}

	graphics.flush();
}

	private function parseHexColor(hex:String):Int {
		if (hex.charAt(0) == '#') {
			hex = hex.substring(1);
		}
		return Std.parseInt('0x' + hex);
	}

	private function parsePoints(points:String):Array<{x:Float, y:Float}> {
		var pointsArray = points.split(" ");
		var result = [];
		for (i in 0...pointsArray.length) {
			if (i % 2 == 0) {
				var x = Std.parseFloat(pointsArray[i]);
				var y = Std.parseFloat(pointsArray[i + 1]);
				result.push({x: x, y: y});
			}
		}
		return result;
	}
}

enum GraphicsCommands {
	LineTo(x:Float, y:Float);
	MoveTo(x:Float, y:Float);
	DrawArc(x0:Float, y0:Float, rx:Float, ry:Float, xAxisRotation:Float, largeArcFlag:Int, sweepFlag:Int, dx:Float, dy:Float);
	DrawRect(x:Float, y:Float, width:Float, height:Float);
	DrawCircle(cx:Float, cy:Float, r:Float);
	DrawEllipse(cx:Float, cy:Float, rx:Float, ry:Float, rotation:Float, segments:Int);
	DrawRoundedRect(x:Float, y:Float, width:Float, height:Float, radius:Float);
	CurveTo(cx:Float, cy:Float, x:Float, y:Float);
	CubicCurveTo(x:Float, y:Float, cx1:Float, cy1:Float, cx2:Float, cy2:Float, x1:Float, y1:Float);
	LineSize(w:Float);
	LineAlpha(a:Float);
	LineColor(r:Float, g:Float, b:Float);
	Flush;
}

enum SVGStyle {
	Fill(color:Int);
	Stroke(color:Int);
	StrokeWidth(w:Float);
}
