# heaps-svg-lite

A basic SVG renderer for Heaps. Only for drawing vector paths -- does not implement all of the advanced features of the SVG format, of which they are many. 

As a benchmark of the scope of the renderer, here it is drawing all of the feathericon.com open source icons:

https://cardgdev.github.io/heaps-svg-lite/bin/


## Usage
```haxe

var g = new Graphics();
s2d.addChild(g);

var s = new SvgRenderer();
s.setUnitSize(5); //the "scale" of the rendering. 
//You could just scale the graphics object, but with heaps graphics drawing you get higher fidelity drawing large and scaling down
//because the curve sampling is decided at draw time
s.render(content, g);


```
