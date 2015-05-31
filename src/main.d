module main;

import std.stdio;
import std.math;
import std.exception;
import std.string;
import std.datetime;

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

import table;
import draw;

class UIException : Exception
{
    this( string msg, string file=__FILE__, size_t line=__LINE__ ) pure nothrow @safe
    { super( msg, file, line ); }
}

final class UI
{
private:

    string glade_file;

    Builder builder;

    Table table;

    bool use_square = false;

    TableDrawer table_drawer;
    ResultDrawer result_drawer;

public:

    this( string glade_file, Table table )
    in{ assert( table !is null ); } body
    {
        builder = new Builder;

        this.glade_file = glade_file;
        this.table = table;

        table_drawer = new TableDrawer( table );
        result_drawer = new ResultDrawer( table );

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
        prepareUpdateAction();
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
            if( key.keyval == 32 /+ space key val +/ ) updateTable();
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
            table_drawer.scale = aux.getValue();
            logger.Debug!"adjscale.valueChanged"( table_drawer.scale );
            redrawTable();
        });
    }

    void prepareColorSelectors()
    {
        obj!ColorButton( "colorbtnbackground" ).addOnColorSet( (aux)
        {
            aux.getColor( table_drawer.background );
            logger.Debug!"colorbtnbackground.colorSet"( table_drawer.background );
            redrawTable();
        });

        obj!ColorButton( "colorbtnforeground" ).addOnColorSet( (aux)
        {
            aux.getColor( table_drawer.foreground );
            logger.Debug!"colorbtnforeground.colorSet"( table_drawer.foreground );
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

    void prepareUpdateAction()
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
        drawAssist( obj!DrawingArea( "drawingarea" ), table_drawer );
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
        drawAssist( obj!DrawingArea( "resultdraw" ), result_drawer );
    }

    void updateTable()
    {
        table.update();
        updateTime( table.results[$-1] );

        redrawTable();

        logger.Debug( "pass" );
    }

    void updateTableSize()
    {
        setTableSizeFromWidgets();
        updateTable();
        table.clearResults();
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

    void firstUpdateTable()
    {
        table.update();
        table.clearResults();
        redrawTable();
    }

    void updateTime( float time )
    {
        obj!Label( "labelmsg" ).setLabel( format( "time: % 6.2f sec", time ) );

        setResultListWidgetValues();
        redrawResults();
    }

    void setResultListWidgetValues()
    {
        auto rl = obj!ListStore( "resultlist" );
        rl.clear();
        foreach( tt; table.results )
            rl.setValue( rl.createIter(), 0, new Value( tt ) );
    }

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
