import hxd.App;
import hxd.res.Resource;
import hx.heaps.svglite.SVGRenderer;
import h2d.Graphics;

class Main extends App {
    public override function init() {
        super.init();
		hxd.Res.initEmbed();
        var x = 0;
        for(eachBaseFile in hxd.Res.loader.load("feathersicon").iterator()){
            var content = eachBaseFile.toText();
            var g = new Graphics();
                    s2d.addChild(g);
                    g.x = x % 1000;
                    g.y = Math.floor(x / 1000) * 50;

                    var s = new SvgRenderer();
                    s.setUnitSize(5);
                    s.render(content, g);
                    g.scaleX = 1 / 5;
                    g.scaleY = 1 / 5;
                    x += Std.int(g.getBounds().width + 15);
        }
    
    }

    public static function main() {
        new Main();
    }
}