import 'package:flutter/cupertino.dart';
import 'package:trippo_maps/models/trips_history_model.dart';

import '../models/direction.dart';

class AppInfo extends ChangeNotifier {
  Directions? userPickupLocation, userDropOffLocation;

  int countTotalTrips = 0;

  List<String> historyTripsKeyList = [];
  //
  // List<TripsHistoryModel> allTripsHistoryList = [];
  List<TripsHistoryModel> allTripsHistoryInformationList = [];

  void updatePickupLocationAddress(Directions userPickupAddress) {
    userPickupLocation = userPickupAddress;
    notifyListeners();
  }

  void updateDropOffLocationAddress(Directions dropOffAddress) {
    userDropOffLocation = dropOffAddress;
    notifyListeners();
  }

  updateOverAllTripsCounter(int overAllTripsCounter) {
    countTotalTrips = overAllTripsCounter;
    notifyListeners();
  }

  updateOverAllTripsKeys(List<String> tripsKeysList) {
    historyTripsKeyList = tripsKeysList;
    notifyListeners();
  }

  updateOverAllTripsHistoryInformation(TripsHistoryModel eachTripHistory) {
    allTripsHistoryInformationList.add(eachTripHistory);
    notifyListeners();
  }
}
