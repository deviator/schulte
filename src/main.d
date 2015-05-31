module main;

import std.stdio;
import std.math;
import std.exception;
import std.string;
import std.datetime;
import std.algorithm;

import std.range : iota;
import std.random : randomCover;

import gdk.Color;
import gdk.RGBA;

import cairo.Context;

import gtk.Box;
import gtk.Builder;
import gtk.Button;
import gtk.CheckButton;
import gtk.ColorButton;
import gtk.Main;
import gtk.MainWindow;
import gtk.Label;
import gtk.Widget;
import gtk.DrawingArea;
import gtk.Action;
import gtk.Adjustment;
import gtk.Window;
import gtk.ListStore;
import gtk.TreeIter;
import gtk.SpinButton;
import gtk.Switch;
import gtk.Style;
import gtk.StyleContext;
import gobject.Value;

import des.log;

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
        prepareMainWindow();
        prepareTableSizeChange();
        prepareColorSelectors();
        prepareShowParamsSwitch();
        prepareSquareSwitch();
        prepareCreateAction();
        prepareInitialTableSize();
        prepareDrawingTable();
        prepareShowingResults();
        prepareDrawingResults();
    }

    void prepareMainWindow()
    {
        auto w = obj!Window( "mwindow" );
        w.setTitle( "schulte tables" );
        w.addOnKeyPress( ( GdkEventKey* key, Widget aux )
        {
            logger.Debug!"key press"( "key val: ", key.keyval );
            if( key.keyval == 32 ) updateTable();
            return true;
        });
        w.addOnHide( (Widget aux){ Main.quit(); } );
        w.showAll();
    }

    void prepareTableSizeChange()
    {
        obj!Adjustment( "adjwidth" ).addOnValueChanged( (Adjustment aux)
        {
            logger.Debug!"adjwidth.valueChanged"( cast(int)aux.getValue() );
            updateTableSize();
        });

        obj!Adjustment( "adjheight" ).addOnValueChanged( (Adjustment aux)
        {
            logger.Debug!"adjheight.valueChanged"( cast(int)aux.getValue() );
            updateTableSize();
        });

        obj!Adjustment( "adjscale" ).addOnValueChanged( (Adjustment aux)
        {
            scale = aux.getValue();
            logger.Debug!"adjscale.valueChanged"( scale );
            redrawTable();
        });
    }

    void prepareColorSelectors()
    {
        obj!ColorButton( "colorbtnbackground" ).addOnColorSet( (aux)
        {
            aux.getColor( bg_color );
            logger.Debug!"colorbtnbackground.colorSet"( bg_color );
            redrawTable();
        });

        obj!ColorButton( "colorbtnforeground" ).addOnColorSet( (aux)
        {
            aux.getColor( fg_color );
            logger.Debug!"colorbtnforeground.colorSet"( fg_color );
            redrawTable();
        });
    }

    void prepareShowParamsSwitch()
    {
        obj!CheckButton( "showparamscheck" ).addOnToggled( (aux)
        {
            bool val = aux.getActive();
            logger.Debug!"showparamscheck.toggled"( val );
            obj!Box( "parambox" ).setVisible( val );
        });
    }

    void prepareSquareSwitch()
    {
        obj!Switch( "squareswitch" ).addOnStateSet( (val,aux)
        {
            use_square = val;
            logger.Debug!"squareswitch.stateSet"( val );
            obj!SpinButton( "spinbtnheight" ).setVisible( !val );

            if( use_square )
                obj!Adjustment( "adjheight" ).setValue( obj!Adjustment( "adjwidth" ).getValue() );

            updateTableSize();

            return false;
        });
    }

    void prepareCreateAction()
    {
        obj!Action( "actionupdate" ).addOnActivate( (Action aux){ updateTable(); });
    }

    void prepareInitialTableSize()
    {
        setTableSizeFromWidgets();
        firstUpdateTable();
    }

    void prepareDrawingTable()
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
                    auto y = ( h - dh + cell_size ) / 2 + cell_size * j + te.height / 2;

                    cr.moveTo( cast(int)x, cast(int)y );
                    cr.showText( tv.value );
                }

            return false;
        });
    }

    void prepareShowingResults()
    {
        auto w = obj!Window( "resultwindow" );

        obj!Action( "actionshowresults" ).addOnActivate( (aux)
        {
            if( w.isVisible() )
            {
                w.hide();
                aux.setLabel( "show results" );
            }
            else
            {
                w.showAll();
                aux.setLabel( "hide results" );
            }
        });

        w.setTitle( "results" );
        w.addOnShow( (aux)
        {
            obj!Label( "resultlabel" ).setLabel(
                    format( "for table %dx%d", table.width, table.height ) );
        });
        w.addOnDelete( (ev, aux) { w.hide(); return true; });
    }

    void prepareDrawingResults()
    {
        obj!DrawingArea( "resultdraw" ).addOnDraw( (Scoped!Context cr, Widget aux)
        {
            float line_width = 2;
            float margin = line_width * 2;
            float font_size = 14;

            float max_time = reduce!max( 0.0f, times );
            size_t cnt = times.length;

            auto w = aux.getAllocatedWidth();
            auto h = aux.getAllocatedHeight();

            cr.setFontSize( font_size );
            cr.setLineWidth( line_width );

            cr.setSourceRgb( 255, 255, 255 );

            float max_time_in_pixel = h - margin * 2 - font_size * 2;
            float cnt_in_pixel = w - font_size * 3;

            float origin_x = font_size * 2;
            float origin_y = h - margin - font_size * 2;

            cr.moveTo( origin_x, origin_y - max_time_in_pixel );
            cr.lineTo( origin_x, origin_y );

            cr.moveTo( origin_x, origin_y );
            cr.lineTo( origin_x + cnt_in_pixel, origin_y );

            cr.stroke();

            float dx = cnt_in_pixel / cnt;
            float start_x_offset = dx * 0.5;
            auto lw = line_width;

            cr.save();
            {
                cr.setSourceRgb( 255, 255, 255 );
                cr.setLineWidth( 1 );
                foreach( i; 0 .. cnt )
                {
                    auto x = origin_x + dx * i + start_x_offset;
                    cr.moveTo( x, origin_y + font_size * 0.3 );
                    cr.lineTo( x, origin_y - max_time_in_pixel );
                }
                cr.stroke();
            }
            cr.restore();

            cr.setSourceRgb( 255, 0, 0 );

            float last_x = float.nan, last_y;

            foreach( i; 0 .. cnt )
            {
                auto x = origin_x + dx * i + start_x_offset;
                auto y = origin_y - max_time_in_pixel * ( times[i] / max_time );
                cr.rectangle( x-lw, y-lw, lw*2, lw*2 );

                if( last_x !is float.nan )
                {
                    cr.moveTo( last_x, last_y );
                    cr.lineTo( x, y );
                }

                last_x = x;
                last_y = y;
            }

            //cr.fill();
            cr.stroke();

            cairo_text_extents_t te;

            cr.setSourceRgb( 255, 255, 255 );

            foreach( i; 0 .. cnt )
            {
                string text = format( "%d", i+1 );

                auto x = origin_x + dx * i + start_x_offset;
                auto y = origin_y + font_size * 1.5;

                cr.textExtents( text, &te );
                cr.moveTo( x - te.width/2, y );
                cr.showText( text );
            }

            return false;
        });

    }

    void showResultWindow()
    {
        obj!Window( "resultwindow" ).showAll();
    }

    void updateTable()
    {
        updateTime( getElapsedTime() );

        table.update();
        redrawTable();

        logger.Debug( "pass" );
    }

    void updateTableSize()
    {
        times = [];

        setTableSizeFromWidgets();

        updateTable();
    }

    void setTableSizeFromWidgets()
    {
        auto aw = obj!Adjustment( "adjwidth" );
        auto ah = obj!Adjustment( "adjheight" );

        table.width = cast(int)aw.getValue();
        if( use_square )
            table.height = cast(int)aw.getValue();
        else
            table.height = cast(int)ah.getValue();

        logger.Debug( "%dx%d", table.width, table.height );
    }

    StopWatch sw;

    void firstUpdateTable()
    {
        sw.start();

        table.update();
        redrawTable();
    }

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
        logger.info( "update timeout % 6.2f sec", time );

        obj!Label( "labelmsg" ).setLabel( format( "time: % 6.2f sec", time ) );

        appendTimeToResultList( time );
        setResultListWidgetValues();
        redrawResults();
    }

    void setResultListWidgetValues()
    {
        auto rl = obj!ListStore( "resultlist" );
        rl.clear();
        foreach( tt; times )
            rl.setValue( rl.createIter(), 0, new Value( tt ) );
    }

    float[] times;

    void appendTimeToResultList( float time ) { times ~= time; }

    void redrawTable() { obj!DrawingArea( "drawingarea" ).queueDraw(); }
    void redrawResults() { obj!DrawingArea( "resultdraw" ).queueDraw(); }

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
