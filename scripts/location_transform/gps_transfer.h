#ifndef GPS_TRANSFER_H_  
#define GPS_TRANSFER_H_  
  
#include<math.h>  

typedef struct 
{
    double lng;
    double lat;
} Location;

class GpsTransfer {  
public:  
    GpsTransfer() {};  
    virtual ~GpsTransfer();  
	
public:
    /**
     * WGS-84 转 GCJ-02
     */
    static Location TransformFromWGSToGCJ(Location wg_loc);
	
	/**
     * GCJ-02 转 WGS-84
     */
    static Location TransformFromGCJToWGS(Location gc_loc);

private:
    static int OutOfChina(double lat, double lon);

    static double TransformLat(double x, double y);

    static double TransformLon(double x, double y);  
};  
  
#endif /* GPS_TRANSFER_H_ */
