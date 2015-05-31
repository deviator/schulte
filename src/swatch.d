module swatch;

import std.datetime : StopWatch;

class SWatch
{
    StopWatch sw;
    float[] m_intervals;

public:

    this() { sw.start(); }

    float cycle()
    {
        sw.stop();
        auto dt = sw.peek().to!("seconds",float);
        sw.reset();
        sw.start();
        m_intervals ~= dt;
        return dt;
    }

    void clear() { m_intervals = []; }

    @property const(float[]) intervals() const
    { return m_intervals; }
}
