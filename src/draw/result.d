module draw.result;

import std.string;
import std.algorithm;

import des.log;

import draw.iface;

import table;

import cairo.Context;

struct RColor { float r=.0f, g=.0f, b=.0f; }

class ResultDrawer : Drawer
{
    RColor bg, fg, ln, mclr, mclr2;

    Table table;

public:

    this( Table table )
    in { assert( table !is null ); } body
    {
        this.table = table;
        bg = RColor(1,1,1);
        fg = RColor(0,0,0);
        ln = RColor(.9,.9,.9);
        mclr = RColor(0,0,1);
        mclr2 = RColor(0,1,1);
    }

    void draw( Scoped!Context cr, int w, int h )
    {
        float line_width = 2;
        float margin = line_width * 2;
        float font_size = 14;
        float margin_left = font_size * 4;

        float max_time = reduce!max( 0.0f, table.results );
        size_t cnt = table.results.length;

        cr.setSourceRgb( bg.r, bg.g, bg.b );
        cr.rectangle( 0, 0, w, h );
        cr.fill();

        cr.setFontSize( font_size );
        cr.setLineWidth( line_width );

        cr.setSourceRgb( fg.r, fg.g, fg.b );

        float max_height = h - margin * 2 - font_size * 2;
        float max_time_in_pixel = max_height - font_size;
        float cnt_in_pixel = w - margin_left - font_size;

        float origin_x = margin_left;
        float origin_y = h - margin - font_size * 2;

        cr.moveTo( origin_x, origin_y - max_height );
        cr.lineTo( origin_x, origin_y );

        cr.moveTo( origin_x, origin_y );
        cr.lineTo( origin_x + cnt_in_pixel, origin_y );

        cr.stroke();

        float dx = cnt_in_pixel / cnt;
        float start_x_offset = dx * 0.5;
        auto lw = line_width;

        {
            mixin( scopeSave("cr") );

            cr.setSourceRgb( ln.r, ln.g, ln.b );
            cr.setLineWidth( 1 );

            foreach( i; 0 .. cnt )
            {
                auto x = origin_x + dx * i + start_x_offset;
                cr.moveTo( x, origin_y + font_size * 0.3 );
                cr.lineTo( x, origin_y - max_height );
            }

            auto h_cnt = max_height / ( font_size * 3 );
            auto time_step = max_time / h_cnt;
            auto time_scale = max_time_in_pixel / max_time;

            float step_step = 10;
            time_step = cast(long)( time_step * step_step ) / step_step;
            auto time_step_in_pixel = time_step * time_scale;

            auto step_cnt = cast(ulong)(max_time_in_pixel / time_step_in_pixel)+1;

            foreach( i; 1 .. step_cnt )
            {
                auto x = origin_x - font_size * 0.3;
                auto y = origin_y - time_step * i * time_scale;
                cr.moveTo( x, y );
                cr.lineTo( origin_x + cnt_in_pixel, y );
            }

            cr.stroke();

            cairo_text_extents_t te;
            cr.setSourceRgb( fg.r, fg.g, fg.b );

            foreach( i; 1 .. step_cnt )
            {
                auto x = origin_x - font_size * 0.3;
                auto time_value = time_step * i;
                auto y = origin_y - time_value * time_scale;
                auto text = format( "%6.1f", time_value );
                cr.textExtents( text, &te );
                cr.moveTo( x - te.width - font_size, y + te.height/2 );
                cr.showText( text );
            }
        }

        {
            mixin( scopeSave("cr") );

            cr.setSourceRgb( mclr.r, mclr.g, mclr.b );

            float last_x = float.nan, last_y;

            foreach( i; 0 .. cnt )
            {
                auto x = origin_x + dx * i + start_x_offset;
                auto y = origin_y - max_time_in_pixel * ( table.results[i] / max_time );
                cr.rectangle( x-lw, y-lw, lw*2, lw*2 );

                if( last_x !is float.nan )
                {
                    cr.moveTo( last_x, last_y );
                    cr.lineTo( x, y );
                }

                last_x = x;
                last_y = y;
            }

            cr.stroke();
        }

        {
            mixin( scopeSave("cr") );

            cr.setSourceRgb( mclr2.r, mclr2.g, mclr2.b );
            float avg_time = cnt == 0 ? 0 : reduce!((r,v)=>r+=v)( 0.0f, table.results ) / cnt;
            auto avg_in_pixel = origin_y - max_time_in_pixel * ( avg_time / max_time );
            cr.moveTo( origin_x, avg_in_pixel );
            cr.lineTo( origin_x + cnt_in_pixel, avg_in_pixel );
            cr.stroke();
        }

        cairo_text_extents_t te;

        cr.setSourceRgb( fg.r, fg.g, fg.b );

        foreach( i; 0 .. cnt )
        {
            string text = format( "%d", i+1 );

            auto x = origin_x + dx * i + start_x_offset;
            auto y = origin_y + font_size * 1.5;

            cr.textExtents( text, &te );
            cr.moveTo( x - te.width/2, y );
            cr.showText( text );
        }
    }
}
