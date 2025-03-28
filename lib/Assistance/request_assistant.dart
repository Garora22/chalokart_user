import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:trippo_maps/global/map_key.dart';

class RequestAssistant{
  static Future<dynamic> receiveRequest(String url) async{
    http.Response response=await http.get(Uri.parse(url));
    try{
      if(response.statusCode==200)
      {
        String responseData=response.body;//json
        var decodeResponse=jsonDecode(responseData);
        return decodeResponse;
      }
      else {
        return" Error occurred, no response";
      }
    }
    catch(e){
      return " Error occurred, no response";
    }
  }

  static Future<dynamic> receiveRequestForDirectionDetails(LatLng originPosition, LatLng destinationPosition) async{
    try {
      final url=Uri.parse("https://routes.googleapis.com/directions/v2:computeRoutes");

      final headers = {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': mapKey,
        'X-Goog-FieldMask': 'routes.distanceMeters,routes.duration,routes.polyline.encodedPolyline',
      };

      final body = jsonEncode({
        'origin': {
          'location': {
            'latLng': {
              'latitude': originPosition.latitude,
              'longitude': originPosition.longitude,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': destinationPosition.latitude,
              'longitude': destinationPosition.longitude,
            },
          },
        },
        'travelMode': 'DRIVE',
      });

      final response = await http.post(url, headers: headers, body: body);
      // print("another one called");
      if (response.statusCode == 200) {
        // print(jsonDecode(response.body));
        return jsonDecode(response.body);
      } else {
        return "Error occurred, no response";
      }
    } catch (e) {
      return "Error occurred, no response";
    }
  }

}