#include <iostream>
#include <string>
#include <sstream>
#include <vector>
#include "gps_transfer.h""

using namespace std;

int main(int argc, char *argv[]) {
    if(argc < 2) {
        return 1;
    }

    stringstream s_stream(argv[1]);
    vector<string> result;

    while(s_stream.good()) {
        string substr;
        getline(s_stream, substr, ',');
        result.push_back(substr);
    }

    if(result.size() != 2) {
        return 1;
    }

    double lon = stod(result[0]);
    double lat = stod(result[1]);

    Location location = {
        lng: lon,
        lat: lat
    };

    Location wgsLocation = GpsTransfer::TransformFromGCJToWGS(location);

    cout << wgsLocation.lng << "," << wgsLocation.lat;

    return 0;
}

