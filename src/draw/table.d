module draw.table;

import draw.iface;

import gdk.Color;
import cairo.Context;

import table;

import des.log;

class TableDrawer : Drawer
{
    Color m_background, m_foreground;
    float m_scale = 1.0f;

    Table table;
    bool use_center_point = true;

public:

    this( Table table )
    in { assert( table !is null ); } body
    {
        this.table = table;
        m_background = new Color(0,0,0);
        m_foreground = new Color(255,255,255);
    }

    @property
    {
        ref Color background() { return m_background; }
        ref Color foreground() { return m_foreground; }

        void scale( float s )
        in { assert( s > 0 ); } body
        { m_scale = s; }

        float scale() const { return m_scale; }
    }

    void draw( Scoped!Context cr, int w, int h )
    {
        float line_width = 2;
        float margin = line_width * 2;

        float widget_aspect = cast(float)w / h;
        float table_aspect = cast(float)table.width / table.height;

        float draw_width = ( table_aspect >= widget_aspect ? w : h * table_aspect ) * scale - margin * 2;

        logger.trace( "table aspect: ", table_aspect );
        logger.trace( "widget aspect: ", widget_aspect );
        logger.trace( "draw width: ", draw_width );

        cr.setLineWidth( line_width );

        cr.setSourceRgb( background.red(), background.green(), background.blue() );
        cr.rectangle( 0, 0, w, h );
        cr.fill();

        cr.setSourceRgb( foreground.red(), foreground.green(), foreground.blue() );

        auto dw = cast(int)( draw_width );
        auto dh = cast(int)( draw_width / table_aspect );

        cr.rectangle( ( w - dw ) / 2, ( h - dh ) / 2, dw, dh );
        cr.stroke();

        auto cell_size = cast(float)dw / table.width;

        foreach( i; 0 .. table.width )
        {
            auto x = ( w - dw ) / 2 + cast(int)( cell_size * i );
            cr.moveTo( x, (h-dh) / 2 );
            cr.lineTo( x, (h+dh) / 2 );
        }

        foreach( i; 0 .. table.height )
        {
            auto y = ( h - dh ) / 2 + cast(int)( cell_size * i );
            cr.moveTo( (w-dw)/2, y );
            cr.lineTo( (w+dw)/2, y );
        }

        cr.strokePreserve();

        auto font_size = cell_size * 0.5;

        cr.setFontSize( font_size );
        cairo_text_extents_t te;

        foreach( j; 0 .. table.height )
            foreach( i; 0 .. table.width )
            {
                auto tv = table.getValue( i, j );
                cr.textExtents( tv.value, &te );

                auto x = ( w - dw + cell_size ) / 2 + cell_size * i - te.width / 2;
                auto y = ( h - dh + cell_size ) / 2 + cell_size * j + te.height / 2;

                cr.moveTo( cast(int)x, cast(int)y );
                cr.showText( tv.value );
            }

        if( use_center_point )
        {
            cr.setSourceRgb(255,0,0);
            cr.arc( w/2, h/2, line_width*2, 0, 3.1415*2 );
            cr.fill();
        }
    }
}
