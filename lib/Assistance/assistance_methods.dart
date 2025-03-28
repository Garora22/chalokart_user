import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trippo_maps/Assistance/request_assistant.dart';
import 'package:trippo_maps/global/global.dart';
import 'package:trippo_maps/models/direction.dart';
import 'package:trippo_maps/models/direction_details_info.dart';
import 'package:trippo_maps/models/direction_details_with_polyline.dart';
import 'package:trippo_maps/models/trips_history_model.dart';
import 'package:trippo_maps/models/user_model.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../global/map_key.dart';
import '../infoHandler/app_info.dart';

class AssistantMethods {
  static void readCurrentOnlineUserInfo() async {
    currentUser = firebaseAuth.currentUser;
    DatabaseReference userRef = FirebaseDatabase.instance
        .ref()
        .child("users")
        .child(currentUser!.uid);
    userRef.once().then((snap) {
      if (snap.snapshot.value != null) {
        userModelCurrentInfo = UserModel.fromSnapshot(snap.snapshot);
      }
    });
  }

  static Future<String> searchAddressForGeoCoordinates(
    Position position,
    context,
  ) async {
    String apiUrl =
        "https://maps.googleapis.com/maps/api/geocode/json?latlng=${position.latitude},${position.longitude}&key=$mapKey";
    String humanReadableAddress = "";
    var requestResponse = await RequestAssistant.receiveRequest(apiUrl);

    if (requestResponse != "Error occurred, no response") {
      humanReadableAddress = requestResponse["results"][0]["formatted_address"];

      Directions userPickupAddress = Directions();
      userPickupAddress.locationLatitude = position.latitude;
      userPickupAddress.locationLongitude = position.longitude;
      userPickupAddress.locationName = humanReadableAddress;

      Provider.of<AppInfo>(
        context,
        listen: false,
      ).updatePickupLocationAddress(userPickupAddress);
    }
    return humanReadableAddress;
  }

  static Future<(DirectionDetailsWithPolyline, dynamic)>
  obtainOriginToDestinationDirectionDetails(
    LatLng originPosition,
    LatLng destinationPosition,
  ) async {
    DirectionDetailsWithPolyline directionDetailsWithPolyline =
        DirectionDetailsWithPolyline();
    // print("Function called");
    var responseDirectionApi =
        await RequestAssistant.receiveRequestForDirectionDetails(
          originPosition,
          destinationPosition,
        );
    DirectionDetailsWithPolyline nullInstance = DirectionDetailsWithPolyline(
      e_points: null,
      distance_value_in_meters: null,
      duration_text_in_s: null,
    );
    // print(responseDirectionApi);
    if (responseDirectionApi == "Error occurred, no response") {
      return (nullInstance, "");
    }
    directionDetailsWithPolyline.e_points =
        responseDirectionApi["routes"][0]["polyline"]["encodedPolyline"];
    directionDetailsWithPolyline.distance_value_in_meters =
        responseDirectionApi["routes"][0]["distanceMeters"];
    directionDetailsWithPolyline.duration_text_in_s =
        responseDirectionApi["routes"][0]["duration"];
    // print("asdf");
    // print(responseDirectionApi["routes"][0]["polyline"]["encodedPolyline"]);
    return (
      directionDetailsWithPolyline,
      responseDirectionApi["routes"][0]["polyline"]["encodedPolyline"],
    );
  }

  static double calculateFareAmountFromOriginToDestination(
    DirectionDetailsWithPolyline directionDetailsWithPolyline,
  ) {
    double timeTravelledFareAmountPerMinute =
        (directionDetailsWithPolyline.distance_value_in_meters! / 60) * 0.1;
    double distanceTravelledFareAmountPerKilometer =
        (directionDetailsWithPolyline.distance_value_in_meters! / 1000) * 0.1;
    double totalFareAmount =
        timeTravelledFareAmountPerMinute +
        distanceTravelledFareAmountPerKilometer;
    return double.parse(totalFareAmount.toStringAsFixed(1));
  }

  static sendNotificationToDriverNow(
    String deviceRegistrationToken,
    String userRideRequestId,
    context,
  ) async {
    String destinationAddress = userDropOffAddress;
    Map<String, String> headerNotification = {
      'Content-Type': 'application/json',
      'Authorization': cloudMessagingServerToken,
    };
    Map bodyNotification = {
      "body": "Destination Address: \n$destinationAddress",
      "title": "New Trip Request",
    };

    Map dataMap = {
      "click_action": "FLUTTER_NOTIFICATION_CLICK",
      "id": "1",
      "status": "done",
      "rideRequested": userRideRequestId,
    };

    Map officialNotificationFormat = {
      "notification": bodyNotification,
      "data": dataMap,
      "priority": "high",
      "to": deviceRegistrationToken,
    };
    var responseNotification = http.post(
      Uri.parse("https://fcm.googleapis.com/fcm/send"),
      headers: headerNotification,
      body: jsonEncode(officialNotificationFormat),
    );
  }

  static void readTripsKeysForOnlineUser(context) {
    FirebaseDatabase.instance
        .ref()
        .child("All Ride Requests")
        .orderByChild("userName")
        .equalTo(userModelCurrentInfo!.name)
        .once()
        .then((snap) {
          if (snap.snapshot.value != null) {
            Map keysTripsId = snap.snapshot.value as Map;
            int overAllTripsCounter = keysTripsId.length;
            Provider.of<AppInfo>(
              context,
              listen: false,
            ).updateOverAllTripsCounter(overAllTripsCounter);
            List<String> tripKeysList = [];
            keysTripsId.forEach((key, value) {
              tripKeysList.add(key);
            });
            Provider.of<AppInfo>(
              context,
              listen: false,
            ).updateOverAllTripsKeys(tripKeysList);

            readTripsKeysForOnlineUser(context);
          }
        });
  }

  static void readTripsHistoryInformation(context) {
    var tripsAllKeys =
        Provider.of<AppInfo>(context, listen: false).historyTripsKeyList;
    for (String eachKey in tripsAllKeys) {
      FirebaseDatabase.instance
          .ref()
          .child("All Ride Requests")
          .child(eachKey)
          .once()
          .then((snap) {
            var eachTripHistory = TripsHistoryModel.fromSnapshot(snap.snapshot);
            if ((snap.snapshot.value as Map)["status"] == "ended") {
              Provider.of<AppInfo>(
                context,
                listen: false,
              ).updateOverAllTripsHistoryInformation(eachTripHistory);
            }
          });
    }
  }
}
