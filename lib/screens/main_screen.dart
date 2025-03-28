import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_geofire/flutter_geofire.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geocoder2/geocoder2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:provider/provider.dart';
import 'package:trippo_maps/screens/splash_screen.dart';
import 'package:trippo_maps/global/global.dart';
import 'package:trippo_maps/global/map_key.dart';
import 'package:trippo_maps/infoHandler/app_info.dart';
import 'package:trippo_maps/models/direction_details_info.dart';
import 'package:trippo_maps/models/direction_details_with_polyline.dart';
import 'package:trippo_maps/screens/drawer_screen.dart';
import 'package:trippo_maps/screens/precise_pickup_screen.dart';
import 'package:trippo_maps/screens/rate_driver_screen.dart';
import 'package:trippo_maps/screens/search_places_screen.dart';
import 'package:url_launcher/url_launcher.dart';

import '../Assistance/assistance_methods.dart';
import '../Assistance/geofire.assistent.dart';
import '../models/active_nearby_available_drivers.dart';
import '../models/direction_details_info.dart';
import '../models/direction.dart';
import '../widgets/progress_dialog.dart';

Future<void> _makePhoneCall(String url) async {
  final Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    throw "Could not launch $url";
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  LatLng? pickLocation;
  loc.Location location = loc.Location();
  // String? _address;
  final Completer<GoogleMapController> _controllerGoogleMap = Completer();
  GoogleMapController? newGoogleMapController;
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(26.512507487655384, 80.23335575281814),
    zoom: 14.4746,
  );

  final GlobalKey<ScaffoldState> _scaffoldState = GlobalKey<ScaffoldState>();

  double searchLocationContainerHeight = 220;
  double waitingResponseFromDriverContainerHeight = 0;
  double SuggestedRidesContainerHeight = 0;
  double AssignedDriverInfoContainerHeight = 0;
  double showSearchingForDriverContainerHeight = 0;
  Position? userCurrentPosition;

  var geoLocation = Geolocator();

  LocationPermission? _locationPermission;
  double bottomPaddingOfMap = 0;

  List<LatLng> pLineCoordinatesList = [];

  Set<Polyline> polylineSet = {};

  Set<Marker> markerSet = {};

  Set<Circle> circleSet = {};

  String userName = "";
  String userEmail = "";

  bool openNavigationDrawer = true;

  bool activeNearbyDriverKeysLoaded = false;

  BitmapDescriptor? activeNearbyIcon;
  DatabaseReference? referenceRideRequest;
  String selectedVehicleType = "";
  String driverRideStatus = "Driver is Coming";
  StreamSubscription<DatabaseEvent>? tripRideRequestsInfoStreamSubscription;
  String userRideRequestStatus = "";
  bool requestPositionInfo = true;
  List<ActiveNearByAvailableDrivers> onlineNearByAvailableDriversList = [];
  locateUserPosition() async {
    Position cPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    userCurrentPosition = cPosition;

    LatLng latLngPosition = LatLng(
      userCurrentPosition!.latitude,
      userCurrentPosition!.longitude,
    );
    CameraPosition cameraPosition = CameraPosition(
      target: latLngPosition,
      zoom: 15,
    );

    newGoogleMapController!.animateCamera(
      CameraUpdate.newCameraPosition(cameraPosition),
    );

    String humanReadableAddress =
        await AssistantMethods.searchAddressForGeoCoordinates(
          userCurrentPosition!,
          context,
        );
    print("this is your address$humanReadableAddress");

    if (userModelCurrentInfo != null) {
      userName = userModelCurrentInfo!.name!;
      userEmail = userModelCurrentInfo!.email!;
    } else {
      userName = "Unknown";
      userEmail = "Unknown";
    }

    initializeGeoFireListener();
    //
    AssistantMethods.readTripsKeysForOnlineUser(context);
  }

  initializeGeoFireListener() {
    Geofire.initialize("activeDrivers");
    Geofire.queryAtLocation(
      userCurrentPosition!.latitude,
      userCurrentPosition!.longitude,
      10,
    )!.listen((map) {
      if (map != null) {
        var callBack = map["callBack"];

        switch (callBack) {
          //driver becomes active
          case Geofire.onKeyEntered:
            ActiveNearByAvailableDrivers activeNearByAvailableDrivers =
                ActiveNearByAvailableDrivers();
            activeNearByAvailableDrivers.locationLatitude = map["latitude"];
            activeNearByAvailableDrivers.locationLongitude = map["longitude"];
            activeNearByAvailableDrivers.driverId = map["key"];
            GeofireAssistent.activeNearByAvailableDriversList.add(
              activeNearByAvailableDrivers,
            );
            if (activeNearbyDriverKeysLoaded == true) {
              displayActiveDriversOnUsersMap();
            }
            break;
          // when driver become inactive or offline
          case Geofire.onKeyExited:
            GeofireAssistent.deleteOfflineDriverFromList(map["key"]);
            displayActiveDriversOnUsersMap();
            break;

          //update location of driver
          case Geofire.onKeyMoved:
            ActiveNearByAvailableDrivers activeNearByAvailableDrivers =
                ActiveNearByAvailableDrivers();
            activeNearByAvailableDrivers.locationLatitude = map["latitude"];
            activeNearByAvailableDrivers.locationLongitude = map["longitude"];
            activeNearByAvailableDrivers.driverId = map["key"];
            GeofireAssistent.updateActiveNearByAvailableDriverLocation(
              activeNearByAvailableDrivers,
            );
            displayActiveDriversOnUsersMap();
            break;

          //display online driver icon on map
          case Geofire.onGeoQueryReady:
            activeNearbyDriverKeysLoaded = true;
            displayActiveDriversOnUsersMap();
            break;
        }
      }
      setState(() {});
    });
  }

  displayActiveDriversOnUsersMap() {
    setState(() {
      markerSet.clear();
      circleSet.clear();

      Set<Marker> driversMarkersSet = <Marker>{};
      for (ActiveNearByAvailableDrivers eachDriver
          in GeofireAssistent.activeNearByAvailableDriversList) {
        LatLng eachDriverActivePosition = LatLng(
          eachDriver.locationLatitude!,
          eachDriver.locationLongitude!,
        );
        Marker marker = Marker(
          markerId: MarkerId(eachDriver.driverId!),
          position: eachDriverActivePosition,
          icon: activeNearbyIcon!,
          rotation: 360,
        );
        driversMarkersSet.add(marker);
      }
      setState(() {
        markerSet = driversMarkersSet;
      });
    });
  }

  createActiveNearByDriverIconMarker() {
    if (activeNearbyIcon == null) {
      ImageConfiguration imageConfiguration = createLocalImageConfiguration(
        context,
        size: Size(0.2, 0.2),
      );
      BitmapDescriptor.asset(imageConfiguration, "images/car.png").then((
        value,
      ) {
        activeNearbyIcon = value;
      });
    }
  }

  Future<void> drawPolylineFromOriginToDestination(bool darkTheme) async {
    var originPosition =
        Provider.of<AppInfo>(context, listen: false).userPickupLocation;
    var destinationPosition =
        Provider.of<AppInfo>(context, listen: false).userDropOffLocation;

    var originLatLng = LatLng(
      originPosition!.locationLatitude!,
      originPosition.locationLongitude!,
    );
    var destinationLatLng = LatLng(
      destinationPosition!.locationLatitude!,
      destinationPosition.locationLongitude!,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) => ProgressDialog(message: "Please wait"),
    );

    var (
      directionDetailsWithPolyline,
      encodedPolylineString,
    ) = await AssistantMethods.obtainOriginToDestinationDirectionDetails(
      originLatLng,
      destinationLatLng,
    );

    setState(() {
      tripDirectionDetailsInfo = directionDetailsWithPolyline;
    });

    Navigator.pop(context);

    PolylinePoints pPoints = PolylinePoints();
    List<PointLatLng> decodePolyLinePointsResultList = pPoints.decodePolyline(
      encodedPolylineString,
    );
    // print(decodePolyLinePointsResultList);
    pLineCoordinatesList.clear();

    if (decodePolyLinePointsResultList.isNotEmpty) {
      for (var pointLatLng in decodePolyLinePointsResultList) {
        pLineCoordinatesList.add(
          LatLng(pointLatLng.latitude, pointLatLng.longitude),
        );
      }
    }

    polylineSet.clear();

    setState(() {
      Polyline polyline = Polyline(
        color: darkTheme ? Colors.greenAccent : Colors.greenAccent,
        polylineId: PolylineId("PolylineID"),
        jointType: JointType.round,
        points: pLineCoordinatesList,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        geodesic: true,
        width: 8,
        visible: true,
      );

      polylineSet.add(polyline);
    });
    // print("Divyam");
    // print(pLineCoordinatesList);
    LatLngBounds boundsLatLng;
    if (originLatLng.latitude > destinationLatLng.latitude &&
        originLatLng.longitude > destinationLatLng.longitude) {
      boundsLatLng = LatLngBounds(
        southwest: destinationLatLng,
        northeast: originLatLng,
      );
    } else if (originLatLng.longitude > destinationLatLng.longitude) {
      boundsLatLng = LatLngBounds(
        southwest: LatLng(originLatLng.latitude, destinationLatLng.longitude),
        northeast: LatLng(destinationLatLng.latitude, originLatLng.longitude),
      );
    } else if (originLatLng.latitude > destinationLatLng.latitude) {
      boundsLatLng = LatLngBounds(
        southwest: LatLng(destinationLatLng.latitude, originLatLng.longitude),
        northeast: LatLng(originLatLng.latitude, destinationLatLng.longitude),
      );
    } else {
      boundsLatLng = LatLngBounds(
        southwest: originLatLng,
        northeast: destinationLatLng,
      );
    }
    newGoogleMapController!.animateCamera(
      CameraUpdate.newLatLngBounds(boundsLatLng, 65),
    );

    Marker originMarker = Marker(
      markerId: MarkerId("originID"),
      infoWindow: InfoWindow(
        title: originPosition.locationName,
        snippet: "Origin",
      ),
      position: originLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );

    Marker destinationMarker = Marker(
      markerId: MarkerId("destinationID"),
      infoWindow: InfoWindow(
        title: destinationPosition.locationName,
        snippet: "Destination",
      ),
      position: destinationLatLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );

    setState(() {
      markerSet.add(originMarker);
      markerSet.add(destinationMarker);
    });

    Circle originCircle = Circle(
      circleId: CircleId("originID"),
      fillColor: Colors.greenAccent,
      radius: 12,
      strokeWidth: 3,
      strokeColor: Colors.white,
      center: originLatLng,
    );
    Circle destinationCircle = Circle(
      circleId: CircleId("destinationID"),
      fillColor: Colors.greenAccent,
      radius: 12,
      strokeWidth: 3,
      strokeColor: Colors.white,
      center: destinationLatLng,
    );

    setState(() {
      circleSet.add(originCircle);
      circleSet.add(destinationCircle);
    });
  }

  void showSearchingForDriverContainer() {
    setState(() {
      showSearchingForDriverContainerHeight = 200;
    });
  }

  void showSuggestedRidesContainer() {
    setState(() {
      SuggestedRidesContainerHeight = 550;
      bottomPaddingOfMap = 400;
    });
  }

  // getAddressesFromLatLng() async{
  //   try{
  //     GeoData data= await Geocoder2.getDataFromCoordinates(
  //         latitude: pickLocation!.latitude,
  //         longitude: pickLocation!.longitude,
  //         googleMapApiKey: mapKey
  //     );
  //     setState(() {
  //
  //       Directions userPickupAddress=Directions();
  //       userPickupAddress.locationLatitude=pickLocation!.latitude;
  //       userPickupAddress.locationLongitude=pickLocation!.longitude;
  //       userPickupAddress.locationName=data.address;
  //
  //       // _address=data.address;
  //
  //       Provider.of<AppInfo>(context, listen: false).updatePickupLocationAddress(userPickupAddress);
  //     });
  //
  //   }
  //   catch(e){
  //     print(e);
  //   }
  // }

  checkLocationPermissionAllowed() async {
    _locationPermission = await Geolocator.requestPermission();

    if (_locationPermission == LocationPermission.denied) {
      _locationPermission = await Geolocator.requestPermission();
    }
  }

  saveRideRequestInformation(String selectedVehicleType) {
    //1.Save the ride information
    referenceRideRequest =
        FirebaseDatabase.instance.ref().child("All Ride Requests").push();
    var originLocation =
        Provider.of<AppInfo>(context, listen: false).userPickupLocation;
    var destinationLocation =
        Provider.of<AppInfo>(context, listen: false).userDropOffLocation;
    Map originLocationMap = {
      "latitude": originLocation!.locationLatitude.toString(),
      "longitude": originLocation.locationLongitude.toString(),
    };
    Map destinationLocationMap = {
      "latitude": destinationLocation!.locationLatitude.toString(),
      "longitude": destinationLocation.locationLongitude.toString(),
    };
    Map userInformationMap = {
      "origin": originLocationMap,
      "destination": destinationLocationMap,
      "time": DateTime.now().toString(),
      "userName": userModelCurrentInfo!.name,
      "userPhone": userModelCurrentInfo!.phone,
      "originAddress": originLocation.locationName,
      "destinationAddress": destinationLocation.locationName,
      "driverId": "waiting",
    };
    referenceRideRequest!.set(userInformationMap);
    tripRideRequestsInfoStreamSubscription = referenceRideRequest!.onValue
        .listen((eventSnap) async {
          if (eventSnap.snapshot.value == null) {
            return;
          }
          if ((eventSnap.snapshot.value as Map)["cart_details"] != null) {
            setState(() {
              driverCartDetails =
                  (eventSnap.snapshot.value as Map)["cart_details"].toString();
            });
          }
          if ((eventSnap.snapshot.value as Map)["driverName"] != null) {
            setState(() {
              driverName =
                  (eventSnap.snapshot.value as Map)["driverName"].toString();
            });
          }
          if ((eventSnap.snapshot.value as Map)["driverPhone"] != null) {
            setState(() {
              driverPhone =
                  (eventSnap.snapshot.value as Map)["driverPhone"].toString();
            });
          }
          if ((eventSnap.snapshot.value as Map)["ratings"] != null) {
            setState(() {
              driverRatings =
                  (eventSnap.snapshot.value as Map)["ratings"].toString();
            });
          }
          if ((eventSnap.snapshot.value as Map)["status"] != null) {
            setState(() {
              userRideRequestStatus =
                  (eventSnap.snapshot.value as Map)["status"].toString();
            });
          }
          if ((eventSnap.snapshot.value as Map)["driverLocation"] != null) {
            double driverCurrentPositionLat = double.parse(
              (eventSnap.snapshot.value as Map)["driverLocation"]["latitude"]
                  .toString(),
            );
            double driverCurrentPositionLng = double.parse(
              (eventSnap.snapshot.value as Map)["driverLocation"]["longitude"]
                  .toString(),
            );
            LatLng driverCurrentPositionLatLng = LatLng(
              driverCurrentPositionLat,
              driverCurrentPositionLng,
            );
            //status=accepted
            if (userRideRequestStatus == "accepted") {
              updateArrivalTimeToUserPickUpLocation(
                driverCurrentPositionLatLng,
              );
            }
            //status= arrived
            if (userRideRequestStatus == "arrived") {
              setState(() {
                driverRideStatus = "Driver has arrived";
              });
            }
            //status =onTrip
            if (userRideRequestStatus == "ontrip") {
              updateReachingTimeToUserDropOffLocation(
                driverCurrentPositionLatLng,
              );
            }
            if (userRideRequestStatus == "ended") {
              if ((eventSnap.snapshot.value as Map)["fareAmount"] != null) {
                double fareAmount = double.parse(
                  (eventSnap.snapshot.value as Map)["fareAmount"].toString(),
                );
                var response = showDialog(
                  context: context,
                  builder:
                      (BuildContext context) =>
                          payFareAmountDialog(fareAmount: fareAmount),
                );
                if (response == "Cash Paid") {
                  //user can rate the driver now
                  if ((eventSnap.snapshot.value as Map)["driverId"] != null) {
                    String assignedDriverId =
                        (eventSnap.snapshot.value as Map)["driverId"]
                            .toString();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (c) => RateDriverScreen(
                              assignedDriverId: assignedDriverId,
                            ),
                      ),
                    );

                    referenceRideRequest!.onDisconnect();
                    tripRideRequestsInfoStreamSubscription!.cancel();
                  }
                }
              }
            }
          }
        });
    onlineNearByAvailableDriversList =
        GeofireAssistent.activeNearByAvailableDriversList;
    searchNearestOnlineDrivers(selectedVehicleType);
  }

  searchNearestOnlineDrivers(selectedVehicleType) async {
    if (onlineNearByAvailableDriversList == 0) {
      referenceRideRequest!.remove();

      setState(() {
        polylineSet.clear();
        markerSet.clear();
        circleSet.clear();
        pLineCoordinatesList.clear();
      });

      Fluttertoast.showToast(msg: "No online driver is available");
      Fluttertoast.showToast(msg: "Search again. \n Restarting App");

      Future.delayed(Duration(milliseconds: 4000), () {
        referenceRideRequest!.remove();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (c) => SplashScreen()),
        );
      });
      return;
    }

    await retrieveOnlineDriversInformation(onlineNearByAvailableDriversList);

    print("Drivers List: $driversList");

    for (int i = 0; i < driversList.length; i++) {
      if (driversList[i]["car details"]["type"] == selectedVehicleType) {
        AssistantMethods.sendNotificationToDriverNow(
          driversList[i]["token"],
          referenceRideRequest!.key!,
          context,
        );
      }
    }

    Fluttertoast.showToast(msg: "Notification Sent Successfully");

    showSearchingForDriverContainer();

    await FirebaseDatabase.instance
        .ref()
        .child("All Ride Requested")
        .child(referenceRideRequest!.key!)
        .child("driverID")
        .onValue
        .listen((eventRideRequestSnapshot) {
          print("EventSnapShot: ${eventRideRequestSnapshot.snapshot.value}");
          if (eventRideRequestSnapshot.snapshot.value != null) {
            if (eventRideRequestSnapshot.snapshot.value != "waiting") {
              showUIForAssignedDriverInfo();
            }
          }
        });
  }

  updateArrivalTimeToUserPickUpLocation(
    LatLng driverCurrentPositionLatLng,
  ) async {
    if (requestPositionInfo == true) {
      requestPositionInfo = false;
      LatLng userPickUpPosition = LatLng(
        userCurrentPosition!.latitude,
        userCurrentPosition!.longitude,
      );

      var (
        directionDetailsWithPolyline,
        _,
      ) = await AssistantMethods.obtainOriginToDestinationDirectionDetails(
        driverCurrentPositionLatLng,
        userPickUpPosition,
      );

      if (directionDetailsWithPolyline == null) {
        return;
      }

      setState(() {
        // Use duration_text_in_s if you want to show distance
        driverRideStatus =
            "Driver is Coming - ${directionDetailsWithPolyline.distance_value_in_meters ?? 0} meters";
      });

      requestPositionInfo = true;
    }
  }

  updateReachingTimeToUserDropOffLocation(driverCurrentPositionLatLng) async {
    if (requestPositionInfo == true) {
      requestPositionInfo = false;

      var dropOffLocation =
          Provider.of<AppInfo>(context, listen: false).userDropOffLocation;

      LatLng userDestinationPosition = LatLng(
        dropOffLocation!.locationLatitude!,
        dropOffLocation.locationLongitude!,
      );

      var (
        directionDetailsInfo,
        _,
      ) = await AssistantMethods.obtainOriginToDestinationDirectionDetails(
        driverCurrentPositionLatLng,
        userDestinationPosition,
      );

      if (directionDetailsInfo == null) {
        return;
      }

      setState(() {
        driverRideStatus =
            "Going Towards Destination - ${directionDetailsInfo.distance_value_in_meters ?? 0} meters";
      });

      requestPositionInfo = true;
    }
  }

  showUIForAssignedDriverInfo() {
    setState(() {
      waitingResponseFromDriverContainerHeight = 0;
      searchLocationContainerHeight = 0;
      AssignedDriverInfoContainerHeight = 200;
      SuggestedRidesContainerHeight = 0;
      bottomPaddingOfMap = 200;
    });
  }

  retrieveOnlineDriversInformation(List onlineNearestDriversList) async {
    driversList.clear();
    DatabaseReference ref = FirebaseDatabase.instance.ref().child("drivers");

    for (int i = 0; i < onlineNearestDriversList.length; i++) {
      await ref
          .child(onlineNearestDriversList[i].driverId.toString())
          .once()
          .then((dataSnapshot) {
            var driverKeyInfo = dataSnapshot.snapshot.value;
            driversList.add(driverKeyInfo);
            print("drivers key information = $driversList");
          });
    }
  }

  Widget payFareAmountDialog({required double fareAmount}) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.transparent,
      child: Container(
        margin: EdgeInsets.all(8),
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.white,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 20),
            Text(
              "Fare Amount",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
            SizedBox(height: 20),
            Text(
              "₹$fareAmount",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 50),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                "This is the total trip fare amount",
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.all(18),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, "Cash Paid");
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Pay Cash",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "₹$fareAmount",
                      style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 4),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    checkLocationPermissionAllowed();
  }

  @override
  Widget build(BuildContext context) {
    bool darkTheme =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    createActiveNearByDriverIconMarker();
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        key: _scaffoldState,
        drawer: DrawerScreen(),
        body: Stack(
          children: [
            GoogleMap(
              mapType: MapType.normal,
              myLocationEnabled: true,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: true,
              initialCameraPosition: _kGooglePlex,
              polylines: polylineSet,
              markers: markerSet,
              circles: circleSet,
              onMapCreated: (GoogleMapController controller) {
                _controllerGoogleMap.complete(controller);
                newGoogleMapController = controller;

                setState(() {
                  bottomPaddingOfMap = 200;
                });

                locateUserPosition();
              },
              // onCameraMove: (CameraPosition? position){
              //   if(pickLocation!=position!.target){
              //     setState(() {
              //       pickLocation = position.target;
              //     });
              //   }
              // },
              //
              // onCameraIdle: (){
              //   getAddressesFromLatLng();
              // },
            ),

            // Align(
            //   alignment: Alignment.center,
            //   child: Padding(
            //       padding: const EdgeInsets.only(bottom: 40.0),
            //       child: Image.asset("images/pick_pin.jpg", height: 45,width: 45,),
            //   ),
            // ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: AssignedDriverInfoContainerHeight,
                decoration: BoxDecoration(
                  color: darkTheme ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Text(
                        driverRideStatus,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 5),
                      Divider(
                        thickness: 1,
                        color: darkTheme ? Colors.grey : Colors.grey[300],
                      ),
                      SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      darkTheme
                                          ? Colors.amber.shade400
                                          : Colors.lightBlue,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.person,
                                  color:
                                      darkTheme ? Colors.black : Colors.white,
                                ),
                              ),
                              SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    driverName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.star, color: Colors.orange),
                                      SizedBox(width: 5),
                                      Text(
                                        driverRatings.isEmpty
                                            ? "0.00"
                                            : double.parse(
                                              driverRatings,
                                            ).toStringAsFixed(2),
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Image.asset("images/car.png", scale: 3),
                              Text(
                                driverCartDetails,
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 5),
                      Divider(
                        thickness: 1,
                        color: darkTheme ? Colors.grey : Colors.grey[300],
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          _makePhoneCall("tel: ${driverPhone}");
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              darkTheme ? Colors.amber.shade400 : Colors.blue,
                        ),
                        icon: Icon(Icons.phone),
                        label: Text("Call Driver"),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Positioned
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: showSearchingForDriverContainerHeight,
                decoration: BoxDecoration(
                  color: darkTheme ? Colors.black : Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    topLeft: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      LinearProgressIndicator(
                        color: darkTheme ? Colors.amber.shade400 : Colors.green,
                      ),
                      SizedBox(height: 10),
                      Center(
                        child: Text(
                          "Searching for Driver",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      GestureDetector(
                        onTap: () {
                          // Cancel search functionality
                          setState(() {
                            showSearchingForDriverContainerHeight = 0;
                            SuggestedRidesContainerHeight = 0;
                          });
                        },
                        child: Container(
                          height: 50,
                          width: 50,
                          decoration: BoxDecoration(
                            color: darkTheme ? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(width: 1, color: Colors.grey),
                          ),
                          child: Icon(Icons.close, size: 25),
                        ),
                      ),
                      SizedBox(height: 15),
                      Container(
                        width: double.infinity,
                        child: Text(
                          "Cancel",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            //   top: 40,
            //   left: 20,
            //   right: 20,
            //   child: Container(
            //     decoration: BoxDecoration(
            //       border: Border.all(color: Colors.black),
            //       color: Colors.white
            //     ),
            //     padding: EdgeInsets.all(20),
            //     child: Text(
            //       Provider.of<AppInfo>(context).userPickupLocation!=null ?
            //       (Provider.of<AppInfo>(context).userPickupLocation!.locationName!.substring(0,45))+'...'
            //           : 'Add Pickup Location',
            //       overflow: TextOverflow.visible, softWrap: true,
            //     ),
            //   ),
            // )
            //custom Hamburger Icon for drawer
            Positioned(
              top: 50,
              left: 20,
              child: Container(
                child: GestureDetector(
                  onTap: () {
                    _scaffoldState.currentState!.openDrawer();
                  },
                  child: CircleAvatar(
                    backgroundColor:
                        darkTheme ? Colors.greenAccent.shade400 : Colors.white,
                    child: Icon(
                      Icons.menu,
                      color:
                          darkTheme ? Colors.greenAccent : Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),

            // ui FOR LOCATION SERACH
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.fromLTRB(10, 50, 10, 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: darkTheme ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color:
                                  darkTheme
                                      ? Colors.grey.shade900
                                      : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(5),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        color:
                                            darkTheme
                                                ? Colors.greenAccent.shade400
                                                : Colors.green,
                                      ),
                                      SizedBox(width: 10),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "From",
                                            style: TextStyle(
                                              color:
                                                  darkTheme
                                                      ? Colors
                                                          .greenAccent
                                                          .shade400
                                                      : Colors.green,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            Provider.of<AppInfo>(
                                                      context,
                                                    ).userPickupLocation !=
                                                    null
                                                ? '${Provider.of<AppInfo>(context).userPickupLocation!.locationName!.substring(0, 15)}...'
                                                : 'Add Pickup Location',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 5),
                                Divider(
                                  height: 1,
                                  thickness: 2,
                                  color:
                                      darkTheme
                                          ? Colors.greenAccent.shade400
                                          : Colors.greenAccent,
                                ),
                                SizedBox(height: 5),
                                Padding(
                                  padding: EdgeInsets.all(5),
                                  child: GestureDetector(
                                    onDoubleTap: () async {
                                      // go to search places screen
                                      var responseFromSearchScreen =
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (c) => SearchPlacesScreen(),
                                            ),
                                          );

                                      if (responseFromSearchScreen ==
                                          "obtainedDropOffLocation") {
                                        setState(() {
                                          openNavigationDrawer = false;
                                        });
                                      }

                                      await drawPolylineFromOriginToDestination(
                                        darkTheme,
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.location_on_outlined,
                                          color:
                                              darkTheme
                                                  ? Colors.greenAccent.shade400
                                                  : Colors.green,
                                        ),
                                        SizedBox(width: 10),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              "To",
                                              style: TextStyle(
                                                color:
                                                    darkTheme
                                                        ? Colors
                                                            .greenAccent
                                                            .shade400
                                                        : Colors.green,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              Provider.of<AppInfo>(
                                                        context,
                                                      ).userDropOffLocation !=
                                                      null
                                                  ? Provider.of<AppInfo>(
                                                        context,
                                                      )
                                                      .userDropOffLocation!
                                                      .locationName!
                                                  : 'Add Drop Off Location',
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (c) => PrecisePickupScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      darkTheme
                                          ? Colors.greenAccent.shade400
                                          : Colors.greenAccent,
                                  textStyle: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: Text(
                                  "Change Pick Up Address",
                                  style: TextStyle(
                                    color:
                                        darkTheme ? Colors.black : Colors.white,
                                  ),
                                ),
                              ),
                              SizedBox(width: 20),
                              ElevatedButton(
                                onPressed: () {
                                  if (Provider.of<AppInfo>(
                                        context,
                                        listen: false,
                                      ).userDropOffLocation !=
                                      null) {
                                    showSuggestedRidesContainer();
                                  } else {
                                    Fluttertoast.showToast(
                                      msg: "Please Select Destination location",
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      darkTheme
                                          ? Colors.greenAccent.shade400
                                          : Colors.greenAccent,
                                  textStyle: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                child: Text(
                                  "Show Fare",
                                  style: TextStyle(
                                    color:
                                        darkTheme ? Colors.black : Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            //ui for suggested ride
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: SuggestedRidesContainerHeight,
                decoration: BoxDecoration(
                  color:
                      Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(20),
                    topLeft: Radius.circular(20),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.greenAccent.shade400
                                      : Colors.green,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Icon(Icons.star, color: Colors.white),
                          ),
                          SizedBox(width: 10),
                          Text(
                            Provider.of<AppInfo>(context).userPickupLocation !=
                                    null
                                ? Provider.of<AppInfo>(context)
                                    .userPickupLocation!
                                    .locationName!
                                    .substring(0, 30)
                                : 'Not Getting Address',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.shade700,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Icon(Icons.star, color: Colors.white),
                          ),
                          SizedBox(width: 10),
                          Text(
                            Provider.of<AppInfo>(context).userDropOffLocation !=
                                    null
                                ? '${Provider.of<AppInfo>(context).userDropOffLocation!.locationName!.substring(0, 15)}..'
                                : 'Where to',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Text(
                        "SUGGESTED RIDES",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedVehicleType = "private";
                              });
                            },
                            child: Container(
                              width: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color:
                                    selectedVehicleType == "private"
                                        ? (darkTheme
                                            ? Colors.green.shade600
                                            : Colors.green.shade400)
                                        : (darkTheme
                                            ? Colors.grey.shade800
                                            : Colors.grey[200]),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 2,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: 15,
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color:
                                            selectedVehicleType == "private"
                                                ? Colors.white.withOpacity(0.2)
                                                : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Image.asset(
                                        "images/car.png",
                                        scale: 1,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      "Private Cart",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color:
                                            selectedVehicleType == "private"
                                                ? Colors.white
                                                : (darkTheme
                                                    ? Colors.white70
                                                    : Colors.black87),
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      tripDirectionDetailsInfo != null
                                          ? "Rs ${((AssistantMethods.calculateFareAmountFromOriginToDestination(tripDirectionDetailsInfo!) * 2) * 107).toStringAsFixed(1)}"
                                          : "Calculating...",
                                      style: TextStyle(
                                        color:
                                            selectedVehicleType == "private"
                                                ? Colors.white70
                                                : Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedVehicleType = "public";
                              });
                            },
                            child: Container(
                              width: 160,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color:
                                    selectedVehicleType == "public"
                                        ? (darkTheme
                                            ? Colors.green.shade600
                                            : Colors.green.shade400)
                                        : (darkTheme
                                            ? Colors.grey.shade800
                                            : Colors.grey[200]),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    spreadRadius: 2,
                                    blurRadius: 8,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: 20,
                                  horizontal: 15,
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color:
                                            selectedVehicleType == "public"
                                                ? Colors.white.withOpacity(0.2)
                                                : Colors.grey.shade300,
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Image.asset(
                                        "images/car.png",
                                        scale: 1,
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      "Public Cart",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color:
                                            selectedVehicleType == "public"
                                                ? Colors.white
                                                : (darkTheme
                                                    ? Colors.white70
                                                    : Colors.black87),
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      tripDirectionDetailsInfo != null
                                          ? "Rs ${((AssistantMethods.calculateFareAmountFromOriginToDestination(tripDirectionDetailsInfo!) * 1.5) * 107).toStringAsFixed(1)}"
                                          : "Calculating...",
                                      style: TextStyle(
                                        color:
                                            selectedVehicleType == "public"
                                                ? Colors.white70
                                                : Colors.grey.shade600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            if (selectedVehicleType != "") {
                              saveRideRequestInformation(selectedVehicleType);
                            } else {
                              Fluttertoast.showToast(
                                msg:
                                    "Please select cart from \n suggested options.",
                              );
                            }
                          },
                          child: Container(
                            padding: EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color:
                                  darkTheme
                                      ? Colors.greenAccent.shade400
                                      : Colors.green,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                "Request a Ride",
                                style: TextStyle(
                                  color:
                                      darkTheme ? Colors.black : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
