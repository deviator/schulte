module draw.iface;

import cairo.Context;
import gtk.Widget;

interface Drawer
{
    void draw( Scoped!Context cr, int w, int h );
}

void drawAssist( Widget w, Drawer d )
in
{ 
    assert( w !is null, "widget must be not null" );
    assert( d !is null, "drawer must be not null" );
}
body { w.addOnDraw( &(new DrawAssist(d).drawSignal) ); }

private class DrawAssist
{
package:

    Drawer drawer;

    this( Drawer d ) { drawer = d; }

    bool drawSignal( Scoped!Context cr, Widget aux )
    {
        drawer.draw( scoped!Context(cr.getContextStruct), 
                            aux.getAllocatedWidth(), 
                            aux.getAllocatedHeight() );
        return false;
    }
}

string scopeSave(string name)
{
    import std.string;
    return format( q{ %1$s.save(); scope(exit) %1$s.restore(); }, name );
}
