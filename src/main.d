module main;

import std.stdio;
import std.math;
import std.exception;
import std.string;
import std.datetime;

import std.range : iota;
import std.random : randomCover;

import gdk.Color;
import gdk.RGBA;

import cairo.Context;

import gtk.Builder;
import gtk.Button;
import gtk.ColorButton;
import gtk.Main;
import gtk.MainWindow;
import gtk.Label;
import gtk.Widget;
import gtk.DrawingArea;
import gtk.Action;
import gtk.Adjustment;
import gtk.Window;
import gtk.SpinButton;
import gtk.Switch;
import gtk.Style;
import gtk.StyleContext;

class UIException : Exception
{
    this( string msg, string file=__FILE__, size_t line=__LINE__ ) pure nothrow @safe
    { super( msg, file, line ); }
}

struct TableValue
{
    string value;
}

interface Table
{
    void update();

    final ref const(TableValue) getValue( int x, int y ) const
    in { assert( x >= 0 && y >= 0 && x < width && y < height ); } body
    { return values[ width * y + x ]; }

    @property
    {
        void width( int val );
        int width() const;

        void height( int val );
        int height() const;

        const(TableValue[]) values() const;
    }
}

class SimpleTable : Table
{
private:

    int _width;
    int _height;

    TableValue[] _values;

public:

    this() { }

    void update()
    {
        setValuesCount();
        randomizeValues();
    }

    @property
    {
        void width( int val )
        in { assert( val > 0 ); } body
        {
            _width = val;
            update();
        }

        int width() const { return _width; }

        void height( int val )
        in { assert( val > 0 ); } body
        {
            _height = val;
            update();
        }

        int height() const { return _height; }

        const(TableValue[]) values() const { return _values; }
    }

protected:

    void randomizeValues()
    {
        int k = 1;
        foreach( i; randomCover( iota(_values.length) ) )
            _values[i] = TableValue( format( "%d", k++ ) );
    }

    final void setValuesCount()
    {
        auto n = _width * _height;
        if( _values.length != n )
            _values.length = n;
    }
}

final class UI
{
private:

    string glade_file;

    Builder builder;
    Table table;

    bool use_square = false;

    float scale = 1.0f;
    Color bg_color, fg_color;

public:

    this( string glade_file, Table table )
    in{ assert( table !is null ); } body
    {
        builder = new Builder;

        this.glade_file = glade_file;
        this.table = table;

        bg_color = new Color( 0, 0, 0 );
        fg_color = new Color( 255, 255, 255 );

        if( !builder.addFromFile( glade_file ) )
            except( "could not load glade object from file '%s'", glade_file );

        prepare();
    }

private:

    void prepare()
    {
        prepareMainWindow( obj!Window( "mwindow" ) );
        prepareTableSizeChange();
        prepareColorSelectors();
        prepareSquareSwitch();
        prepareCreateAction();
        prepareInitialTableSize();
        prepareDrawAlgo();
    }

    void prepareMainWindow( Window w )
    {
        w.setTitle( "schulte tables" );
        w.addOnHide( (Widget aux){ Main.quit(); } );
        w.showAll();
    }

    void prepareTableSizeChange()
    {
        obj!Adjustment( "adjwidth" ).addOnValueChanged( (Adjustment aux)
        {
            table.width = cast(int)aux.getValue();
            if( use_square )
                table.height = cast(int)aux.getValue();

            updateTable();
        });

        obj!Adjustment( "adjheight" ).addOnValueChanged( (Adjustment aux)
        {
            if( !use_square )
            {
                table.height = cast(int)aux.getValue();
                updateTable();
            }
        });

        obj!Adjustment( "adjscale" ).addOnValueChanged( (Adjustment aux)
        {
            scale = aux.getValue();
            redrawTable();
        });
    }

    void prepareColorSelectors()
    {
        obj!ColorButton( "colorbtnbackground" ).addOnColorSet( (aux)
        {
            aux.getColor( bg_color );
            redrawTable();
        });

        obj!ColorButton( "colorbtnforeground" ).addOnColorSet( (aux)
        {
            aux.getColor( fg_color );
            redrawTable();
        });
    }

    void prepareSquareSwitch()
    {
        obj!Switch( "squareswitch" ).addOnStateSet( (val,aux)
        {
            use_square = val;
            obj!SpinButton( "spinbtnheight" ).setVisible( !val );
            updateTable();
            return false;
        });
    }

    void prepareCreateAction()
    {
        obj!Action( "actionupdate" ).addOnActivate( (Action aux){ updateTable(); });
    }

    void prepareInitialTableSize()
    {
        auto aw = obj!Adjustment( "adjwidth" );
        auto ah = obj!Adjustment( "adjheight" );

        table.width = cast(int)aw.getValue();
        if( use_square )
            table.height = cast(int)aw.getValue();
        else
            table.height = cast(int)ah.getValue();

        updateTable();
    }

    void prepareDrawAlgo()
    {
        obj!DrawingArea( "drawingarea" ).addOnDraw( (Scoped!Context cr, Widget aux)
        {
            float line_width = 2;
            float margin = line_width * 2;

            auto w = aux.getAllocatedWidth();
            auto h = aux.getAllocatedHeight();

            float widget_aspect = cast(float)w / h;
            float table_aspect = cast(float)table.width / table.height;

            float draw_width = ( table_aspect >= widget_aspect ? w : h * table_aspect ) * scale - margin * 2;

            cr.setLineWidth( line_width );

            cr.setSourceRgb( bg_color.red(), bg_color.green(), bg_color.blue() );
            cr.rectangle( 0, 0, w, h );
            cr.fill();

            cr.setSourceRgb( fg_color.red(), fg_color.green(), fg_color.blue() );

            auto dw = cast(int)( draw_width );
            auto dh = cast(int)( draw_width / table_aspect );

            cr.rectangle( ( w - dw ) / 2, ( h - dh ) / 2, dw, dh );
            cr.strokePreserve();

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
                    auto y = ( h - dh + cell_size ) / 2 + cell_size * j + font_size / 2;

                    cr.moveTo( cast(int)x, cast(int)y );
                    cr.showText( tv.value );
                }

            return false;
        });
    }

    void updateTable()
    {
        updateTime( getElapsedTime() );

        table.update();
        redrawTable();
    }

    StopWatch sw;

    float getElapsedTime()
    {
        sw.stop();
        auto dt = sw.peek().to!("seconds",float);
        sw.reset();
        sw.start();
        return dt;
    }

    void updateTime( float time )
    {
        writefln( "update timeout % 6.2f sec", time );
        obj!Label( "labelmsg" ).setLabel( format( "% 6.2f sec", time ) );

        // TODO: log results
    }

    void redrawTable() { obj!DrawingArea( "drawingarea" ).queueDraw(); }

    auto obj(T)( string name )
    {
        auto ret = cast(T)builder.getObject( name );
        if( ret is null )
            except( "no '%s' element in file '%s'", name, glade_file );
        return ret;
    }

    void except( string file=__FILE__, size_t line=__LINE__, Args...)( Args args )
    { throw new UIException( format( args ), file, line ); }
}

int main( string[] args )
{
    string glade_file = "ui.glade";

    Main.init( args );

    new UI( glade_file, new SimpleTable );

    Main.run();

    return 0;
}
