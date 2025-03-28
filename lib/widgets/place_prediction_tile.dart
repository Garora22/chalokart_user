import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trippo_maps/global/map_key.dart';
import 'package:trippo_maps/models/predicted_places.dart';
import 'package:trippo_maps/widgets/progress_dialog.dart';

import '../Assistance/request_assistant.dart';
import '../global/global.dart';
import '../infoHandler/app_info.dart';
import '../models/direction.dart';

class PlacePredictionTileDesign extends StatefulWidget {


  final PredictedPlaces? predictedPlaces;

  PlacePredictionTileDesign({this.predictedPlaces});


  @override
  State<PlacePredictionTileDesign> createState() => _PlacePredictionTileDesignState();
}

class _PlacePredictionTileDesignState extends State<PlacePredictionTileDesign> {

  getPlaceDirectionDetails(String? placeId, context) async{
    showDialog(
        context: context,
        builder: (BuildContext context)=>ProgressDialog(
          message: "Setting Drop Off, Please wait...",
        )
    );

    String placeDirectionUrl="https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$mapKey";

    var responseApi=await RequestAssistant.receiveRequest(placeDirectionUrl);

    Navigator.pop(context);

    if(responseApi=="Error occurred, no response"){
      return;
    }

    if(responseApi["status"]=="OK"){
      Directions directions=Directions();
      directions.locationName=responseApi["result"]["name"];
      directions.locationId=placeId;
      directions.locationLatitude=responseApi["result"]["geometry"]["location"]["lat"];
      directions.locationLongitude=responseApi["result"]["geometry"]["location"]["lng"];

      Provider.of<AppInfo>(context, listen: false).updateDropOffLocationAddress(directions);

      setState(() {
        userDropOffAddress=directions.locationName!;
      });

      Navigator.pop(context, "obtainedDropOffLocation");
    }

  }

  @override
  Widget build(BuildContext context) {
    bool darkTheme=MediaQuery.of(context).platformBrightness==Brightness.dark;
    return ElevatedButton(
        onPressed: (){
          getPlaceDirectionDetails(widget.predictedPlaces!.place_id, context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: darkTheme? Colors.greenAccent.shade400:Colors.green,
        ),
        child: Padding(
            padding: EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(
                  Icons.add_location,
                  color: darkTheme? Colors.greenAccent.shade400:Colors.greenAccent,
                ),

                SizedBox(width: 10,),
                Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.predictedPlaces!.main_text!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            color: darkTheme? Colors.black54:Colors.white,
                          )
                        ),
                        Text(
                            widget.predictedPlaces!.secondary_text!,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 16,
                              color: darkTheme? Colors.greenAccent.shade400:Colors.greenAccent,
                            )
                        ),
                      ],
                    )
                )
              ],
            )
        )
    );
  }
}
