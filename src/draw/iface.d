module draw.iface;

import cairo.Context;
import gtk.Widget;

interface Drawer
{
    bool draw( Scoped!Context cr, Widget aux );
}

string scopeSave(string name)
{
    import std.string;
    return format( q{ %1$s.save(); scope(exit) %1$s.restore(); }, name );
}
