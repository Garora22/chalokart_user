import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geocoder2/geocoder2.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart'as loc;
import 'package:provider/provider.dart';

import '../Assistance/assistance_methods.dart';
import '../global/map_key.dart';
import '../infoHandler/app_info.dart';
import '../models/direction.dart';

class PrecisePickupScreen extends StatefulWidget {
  const PrecisePickupScreen({super.key});

  @override
  State<PrecisePickupScreen> createState() => _PrecisePickupScreenState();
}

class _PrecisePickupScreenState extends State<PrecisePickupScreen> {

  LatLng? pickLocation;
  loc.Location location=loc.Location();
  // String? _address;
  final Completer<GoogleMapController> _controllerGoogleMap = Completer();
  GoogleMapController? newGoogleMapController;
  Position? userCurrentPosition;
  double bottomPaddingOfMap=0;
  static const CameraPosition _kGooglePlex = CameraPosition(
    target: LatLng(26.512507487655384, 80.23335575281814),
    zoom: 14.4746,
  );


  final GlobalKey<ScaffoldState> _scaffoldState=GlobalKey<ScaffoldState>();

  locateUserPosition() async{
    Position cPosition= await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    userCurrentPosition=cPosition;

    LatLng latLngPosition = LatLng(userCurrentPosition!.latitude, userCurrentPosition!.longitude);
    CameraPosition cameraPosition=CameraPosition(target: latLngPosition, zoom: 15);

    newGoogleMapController!.animateCamera(CameraUpdate.newCameraPosition(cameraPosition));

    String humanReadableAddress=await AssistantMethods.searchAddressForGeoCoordinates(userCurrentPosition!, context);




    // initializeGeoFireListener();
    //
    // AssistantMethods.readTripsKeysForOnlineUser(context);

  }
  getAddressesFromLatLng() async{
    try{
      GeoData data= await Geocoder2.getDataFromCoordinates(
          latitude: pickLocation!.latitude,
          longitude: pickLocation!.longitude,
          googleMapApiKey: mapKey
      );
      setState(() {

        Directions userPickupAddress=Directions();
        userPickupAddress.locationLatitude=pickLocation!.latitude;
        userPickupAddress.locationLongitude=pickLocation!.longitude;
        userPickupAddress.locationName=data.address;

        // _address=data.address;

        Provider.of<AppInfo>(context, listen: false).updatePickupLocationAddress(userPickupAddress);
      });

    }
    catch(e){
      print(e);
    }
  }
  @override
  Widget build(BuildContext context) {
    bool darkTheme=MediaQuery.of(context).platformBrightness==Brightness.dark;
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            padding: EdgeInsets.only(top: 100, bottom: bottomPaddingOfMap),
            mapType: MapType.normal,
            myLocationEnabled:true,
            zoomGesturesEnabled:true,
            zoomControlsEnabled:true,
            initialCameraPosition: _kGooglePlex,
            onMapCreated: (GoogleMapController controller){
              _controllerGoogleMap.complete(controller);
              newGoogleMapController=controller;

              setState(() {
                bottomPaddingOfMap=50;
              });

              locateUserPosition();
            },
            onCameraMove: (CameraPosition? position){
              if(pickLocation!=position!.target){
                setState(() {
                  pickLocation = position.target;
                });
              }
            },

            onCameraIdle: (){
              getAddressesFromLatLng();
            },

          ),
          Align(
            alignment: Alignment.center,
            child: Padding(
                padding: EdgeInsets.only(top:60, bottom: bottomPaddingOfMap),
                child: Image.asset("images/marker_icon_map.png", height: 45,width: 45,),
            ),
          ),
          Positioned(
            top: 80,
            left: 20,
            right: 20,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black),
                color: Colors.white
              ),
              padding: EdgeInsets.all(20),
              child: Text(
                Provider.of<AppInfo>(context).userPickupLocation!=null ?
                '${Provider.of<AppInfo>(context).userPickupLocation!.locationName!.substring(0,15)}...'
                    : 'Add Pickup Location',
                overflow: TextOverflow.visible, softWrap: true,
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 10,
            right:10,
            child: Padding(
              padding: EdgeInsets.all(12),
              child: ElevatedButton(
                  onPressed: (){
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkTheme? Colors.greenAccent.shade400:Colors.greenAccent,
                    textStyle: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,

                    )
                  ),
                  child: Text(
                    "Set Current Location",
                    style: TextStyle(
                      color: Colors.white
                    ),

                  )
              ),
            ),
          ),
        ],
      ),
    );
  }
}
