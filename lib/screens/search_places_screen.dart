import 'package:flutter/material.dart';
import 'package:trippo_maps/widgets/place_prediction_tile.dart';

import '../Assistance/request_assistant.dart';
import '../global/map_key.dart';
import '../models/predicted_places.dart';

class SearchPlacesScreen extends StatefulWidget {
  const SearchPlacesScreen({super.key});

  @override
  State<SearchPlacesScreen> createState() => _SearchPlacesScreenState();
}

class _SearchPlacesScreenState extends State<SearchPlacesScreen> {

  List<PredictedPlaces> placePredictionList=[];

  findPlaceAutoCompleteSearch(String inputText) async{
    if(inputText.length>1){
      String urlAutoCompleteSearch="https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$inputText&key=$mapKey&components=country:IN";

      var responseAutoCompleteSearch=await RequestAssistant.receiveRequest(urlAutoCompleteSearch);
      if(responseAutoCompleteSearch=="Error occurred, no response"){
        return;
      }
      if(responseAutoCompleteSearch["status"]=="OK"){
        var predictions=responseAutoCompleteSearch["predictions"];

        var placePredictionsList=(predictions as List).map((jsonData)=>PredictedPlaces.fromJson(jsonData)).toList();

        setState(() {
          placePredictionList=placePredictionsList;
        });
      }

    }
  }

  @override
  Widget build(BuildContext context) {

    bool darkTheme=MediaQuery.of(context).platformBrightness==Brightness.dark;
    return GestureDetector(
      onTap: (){
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: darkTheme? Colors.black:Colors.white,
        appBar: AppBar(
          backgroundColor: darkTheme? Colors.greenAccent.shade400:Colors.greenAccent,
          leading: GestureDetector(
            onTap: (){
              Navigator.pop(context);
            },
            child: Icon(Icons.arrow_back, color: darkTheme? Colors.black:Colors.white,),
          ),
          title: Text(
            "Set drop off location",
            style: TextStyle(color:darkTheme? Colors.black: Colors.white, fontWeight: FontWeight.bold),
          ),
          elevation: 0.0,
        ),
        body: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: darkTheme? Colors.greenAccent.shade400:Colors.greenAccent,
                boxShadow: [
                  BoxShadow(
                    color: Colors.white54,
                    blurRadius: 8.0,
                    spreadRadius: 0.5,
                    offset: Offset(
                      0.7,0.7,
                    ),
                  )
                ]
              ),
              child: Padding(
                padding: EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.adjust_sharp,
                          color: darkTheme? Colors.black:Colors.white,
                        ),
                        SizedBox(height: 18,),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: TextField(
                              onChanged: (value){
                                findPlaceAutoCompleteSearch(value);
                              },
                              decoration: InputDecoration(
                                hintText: "Search here",
                                hintStyle: TextStyle(
                                  color: darkTheme ? Colors.green.withOpacity(0.6) : Colors.green.shade700.withOpacity(0.7),
                                  fontSize: 18,
                                  fontStyle: FontStyle.italic,
                                  letterSpacing: 0.5,
                                ),
                                fillColor: darkTheme?Colors.black: Colors.white54,
                                filled: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: darkTheme ? Colors.greenAccent.shade700 : Colors.greenAccent,
                                    width: 1.5,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: darkTheme ? Colors.greenAccent.shade700 : Colors.greenAccent,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: darkTheme ? Colors.greenAccent.shade400 : Colors.greenAccent.shade400,
                                    width: 2.0,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: darkTheme ? Colors.greenAccent.shade400 : Colors.greenAccent.shade700,
                                ),

                              ),

                            )
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
            ),
            //display place prediction result
            (placePredictionList.isNotEmpty)
                ? Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: darkTheme ? Colors.grey.shade800 : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: darkTheme ? Colors.black26 : Colors.grey.withOpacity(0.3),
                      spreadRadius: 2,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: placePredictionList.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: PlacePredictionTileDesign(
                          predictedPlaces: placePredictionList[index],
                        ),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) {
                      return Divider(
                        height: 16,
                        indent: 16,
                        endIndent: 16,
                        color: darkTheme ? Colors.greenAccent.shade700 : Colors.greenAccent.shade200,
                        thickness: 0.5,
                      );
                    }
                ),
              ),
            ) : Container()
          ],
        ),
      ),
    );
  }
}
