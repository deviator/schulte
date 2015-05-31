module table;

import swatch;
import des.log;

import std.range : iota;
import std.random : randomCover;

struct TableValue
{
    string value;
}

interface Table
{
    void update();
    void clearResults();

    final ref const(TableValue) getValue( int x, int y ) const
    in
    {
        assert( 0 <= x && x < width, "range violation (x)" );
        assert( 0 <= y && y < height, "range violation (x)" );
    }
    body { return values[ width * y + x ]; }

    @property
    {
        void width( int val );
        int width() const;

        void height( int val );
        int height() const;

        const(TableValue[]) values() const;
        const(float[]) results() const;
    }
}

class SimpleTable : Table
{
private:

    int m_width;
    int m_height;

    TableValue[] m_values;

    SWatch swatch;

public:

    this()
    {
        swatch = new SWatch;
    }

    void update()
    {
        auto dt = swatch.cycle();
        logger.info( "update cycle: % 6.2f sec", dt );
        setValuesCount();
        randomizeValues();
    }

    void clearResults() { swatch.clear(); }

    @property
    {
        void width( int val )
        in { assert( val > 0 ); } body
        {
            logger.info( val );
            m_width = val;
        }

        int width() const { return m_width; }

        void height( int val )
        in { assert( val > 0 ); } body
        {
            logger.info( val );
            m_height = val;
        }

        int height() const { return m_height; }

        const(TableValue[]) values() const { return m_values; }

        const(float[]) results() const { return swatch.intervals; }
    }

protected:

    void randomizeValues()
    {
        int k = 1;
        foreach( i; randomCover( iota(m_values.length) ) )
            m_values[i] = TableValue( format( "%d", k++ ) );
    }

    final void setValuesCount()
    {
        auto n = m_width * m_height;
        if( m_values.length != n )
            m_values.length = n;
    }
}
