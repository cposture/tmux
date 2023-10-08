#include "gps_transfer.h"
#include <math.h>

const double pi = 3.14159265358979324;

// Krasovsky 1940
// a = 6378245.0, 1/f = 298.3
// b = a * (1 - f)
// ee = (a^2 - b^2) / a^2;
const double a = 6378245.0;
const double ee = 0.00669342162296594323;

int GpsTransfer::OutOfChina(double lat, double lon)
{
    if (lon < 72.004 || lon > 137.8347)
        return 1;
    if (lat < 0.8293 || lat > 55.8271)
        return 1;
	
    return 0;
}

double GpsTransfer::TransformLat(double x, double y)
{
    double ret = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(x > 0 ? x:-x);
    ret += (20.0 * sin(6.0 * x * pi) + 20.0 *sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * sin(y * pi) + 40.0 * sin(y / 3.0 * pi)) * 2.0 / 3.0;
    ret += (160.0 * sin(y / 12.0 * pi) + 320 * sin(y * pi / 30.0)) * 2.0 / 3.0;
	
    return ret;
}

double GpsTransfer::TransformLon(double x, double y)
{
    double ret = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(x > 0 ? x:-x);
    ret += (20.0 * sin(6.0 * x * pi) + 20.0 * sin(2.0 * x * pi)) * 2.0 / 3.0;
    ret += (20.0 * sin(x * pi) + 40.0 * sin(x / 3.0 * pi)) * 2.0 / 3.0;
    ret += (150.0 * sin(x / 12.0 * pi) + 300.0 * sin(x / 30.0 * pi)) * 2.0 / 3.0;
	
    return ret;
}

/**
 * WGS-84 转 GCJ-02
 */
Location GpsTransfer::TransformFromWGSToGCJ(Location wg_loc)
{
    Location gc_loc;
    if (OutOfChina(wg_loc.lat, wg_loc.lng))
    {
        gc_loc = wg_loc;
        return gc_loc;
    }
    double d_lat = TransformLat(wg_loc.lng - 105.0, wg_loc.lat - 35.0);
    double d_lon = TransformLon(wg_loc.lng - 105.0, wg_loc.lat - 35.0);
    double rad_lat = wg_loc.lat / 180.0 * pi;
    double magic = sin(rad_lat);
    magic = 1 - ee * magic * magic;
    double sqrt_magic = sqrt(magic);
    d_lat = (d_lat * 180.0) / ((a * (1 - ee)) / (magic * sqrt_magic) * pi);
    d_lon = (d_lon * 180.0) / (a / sqrt_magic * cos(rad_lat) * pi);
    gc_loc.lat = wg_loc.lat + d_lat;
    gc_loc.lng = wg_loc.lng + d_lon;
    
    return gc_loc;
}

/**
 * GCJ-02 转 WGS-84
 */
Location GpsTransfer::TransformFromGCJToWGS(Location gc_loc)
{
    Location wg_loc = gc_loc;
    Location curr_gc_loc, d_loc;
    while (1) 
	{
        curr_gc_loc = TransformFromWGSToGCJ(wg_loc);
        d_loc.lat = gc_loc.lat - curr_gc_loc.lat;
        d_loc.lng = gc_loc.lng - curr_gc_loc.lng;
        if (fabs(d_loc.lat) < 1e-7 && fabs(d_loc.lng) < 1e-7) 
		{  
		    // 1e-7 ~ centimeter level accuracy
            // Result of experiment:
            // Most of the time 2 iterations would be enough for an 1e-8 accuracy (milimeter level).
            //
            return wg_loc;
        }
		
        wg_loc.lat += d_loc.lat;
        wg_loc.lng += d_loc.lng;
    }
    
    return wg_loc;
}
