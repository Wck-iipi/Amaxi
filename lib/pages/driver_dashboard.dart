import 'package:amaxi/Maps/mapsUtil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:flutter_map/src/layer/marker_layer.dart' as marker;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';
import 'package:latlong2/latlong.dart' as latLng;
import 'package:flutter_map/plugin_api.dart';
import 'package:flutter_mapbox_navigation/library.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapMarker {
    final String? image;
    final String? title;
    final latLng.LatLng location;

    MapMarker({
        this.image,
        required this.title,
        required this.location,
    });
}

// Globals


class AppConstants {
    var dLat, dLong;

    static void readDriver() {
        // double dLat = 0.0, dLong = 0.0;
        // var driversRef = FirebaseFirestore.instance.collection("drivers");
        // var response =  driversRef.get();
        // var responseArr = [];
        // print("___________________RUN________________________");
        // print(response);
        // print("_______________________________________");
        // response.then((value) => {
        //   value.docs.forEach((result) {
        //     dLat = result.data()['location'][0];
        //     dLong = result.data()['location'][1];
        //   })
        // });
        print("Spare me");
    }

  static double user_long = 76.75124201279625; // lat of user
  static double user_lat = 30.728236491597823; // long of user
  static double hosp_long = 76.76938534904092; // lat for nearest hospital
  static double hosp_lat = 30.724073914302423; // long for nearest hospital
  static double driver_lat = 30.724073914302423;
  static double driver_long = 76.76938534904092;

  static String driver_name = "Varun Kainthla";

  //ignore these values
  static String mapBoxAccessToken = 'pk.eyJ1IjoicGxheWVybWF0aGluc29uIiwiYSI6ImNsMXFnMjRvbjEybHUza3BkanNjcTNxZjcifQ.JK4A3zEl7O9U7-8G48avag';
  static String mapBoxStyleId = 'clcahnp7s000415r4b12il5mr';

  static final userLocation = latLng.LatLng(user_lat, user_long);
  static final driverLocation = latLng.LatLng(driver_lat, driver_long);
  static final hospitalLocation = latLng.LatLng(hosp_lat, hosp_long);
  static final mapMarkers = [
    MapMarker(
        title:'User Location',
        location: latLng.LatLng(user_lat, user_long),
    ),
    MapMarker(
        //image:'No.jpg',
        title:'Driver Location',
        location: latLng.LatLng(driver_lat, driver_long),
    ),
    MapMarker(
        title: "Hospital", 
        location:latLng.LatLng(hosp_lat, hosp_long)
    )
  ];
}

class driverDashboard extends StatefulWidget {
  const driverDashboard({Key? key}) : super(key: key);

  @override
  State<driverDashboard> createState() => _driverDashboardState();
}

class _driverDashboardState extends State<driverDashboard> {
  //WayPoints for starting and ending of destination

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    AppConstants.readDriver();
  }

double calculateDistance(latitude1, latitude2, longitude1, longitude2) { //in Km
    var latitude1Radians = latitude1 / 57.29577951;
    var latitude2Radians = latitude2 / 57.29577951;
    var longitude1Radians = longitude1 / 57.29577951;
    var longitude2Radians = longitude2 / 57.29577951;
    var difference = longitude2Radians - longitude1Radians;
    var distance = 3963 * acos((sin(latitude2Radians) * sin(latitude2Radians)) + cos(latitude1Radians) * cos(latitude2Radians) * cos(difference));
    return distance;
}

  latLng.LatLng source = AppConstants.driverLocation;
  latLng.LatLng destination = AppConstants.hospitalLocation;
  latLng.LatLng stop1 = AppConstants.userLocation;
  late WayPoint sourceWayPoint, destinationWayPoint, stop1Point;


  var waypoints = <WayPoint>[];

  //Config variables for Mapbox Navigation
  late MapBoxNavigation directions;
  late MapBoxOptions _options;
  late double distanceRemaining, durationRemaining;
  late MapBoxNavigationViewController _controller;
  final bool isMultipleStop = false;
  String? instruction = "";
  bool? arrived = false;
  bool routeBuilt = false;
  bool isNavigating = false;

  Future<void> _onRouteEvent(e) async {
    distanceRemaining = await directions.distanceRemaining;
    durationRemaining = await directions.durationRemaining;

    switch (e.eventType) {
      case MapBoxEvent.progress_change:
        var progressEvent = e.data as RouteProgressEvent;
        arrived = progressEvent.arrived;
        if (progressEvent.currentStepInstruction != null)
        instruction = progressEvent.currentStepInstruction;
        break;
      case MapBoxEvent.route_building:
      case MapBoxEvent.route_built:
        routeBuilt = true;
        break;
      case MapBoxEvent.route_build_failed:
        routeBuilt = false;
        break;
      case MapBoxEvent.navigation_running:
        isNavigating = true;
        break;
      case MapBoxEvent.on_arrival:
        arrived = true;
        if (!isMultipleStop) {
          await Future.delayed(Duration(seconds: 3));
          await _controller.finishNavigation();
        } else {}
        break;
      case MapBoxEvent.navigation_finished:
      case MapBoxEvent.navigation_cancelled:
        routeBuilt = false;
        isNavigating = false;
        break;
      default:
        break;
    }
    //refresh UI
    setState(() {});
    }

    Future<void> initialize() async{
        if(!mounted) return;
        //Setup the directions
        directions = MapBoxNavigation(onRouteEvent: _onRouteEvent);
        var _options = MapBoxOptions(
            zoom: 11.0,
            // alternatives: true,
            voiceInstructionsEnabled: true,
            bannerInstructionsEnabled: true,
            mode: MapBoxNavigationMode.drivingWithTraffic,
            units: VoiceUnits.metric,
            simulateRoute: true, //if you want to stop the car make it false
            language: "en",
            isOptimized: true
        );

        //Configure waypoints
        sourceWayPoint = WayPoint(name:"Source", latitude: source.latitude, longitude: source.longitude);
        destinationWayPoint = WayPoint(name:"Destination", latitude: destination.latitude, longitude: destination.longitude);
        stop1Point = WayPoint(name: "User", latitude: stop1.latitude, longitude: stop1.longitude);

        waypoints.add(sourceWayPoint);
        waypoints.add(stop1Point);
        waypoints.add(destinationWayPoint);
        //Start trip
        await directions.startNavigation(wayPoints: waypoints, options: _options);
    }
    // void initState() {
    //         super.initState();
    //         initialize();
    // }


  List<marker.Marker> myMarker = <marker.Marker>[];

  // Coordinates -> Ready in python model
  void findDriverProcessStart(){

    setState(() {
      var mapMarker = AppConstants.mapMarkers;
      for (var i = 0; i < mapMarker.length; i++) {
        myMarker.add(
            marker.Marker(
                point: mapMarker[i].location,
                width: 100,
                height: 100,
                builder: (context) => Image.asset("assets/marker.png"),
            )
        );
              
    }
      initialize();
      print("Pressed BOIIIIIII");
    });

  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 33, 32, 32),
        title: Text("Hey " + AppConstants.driver_name),
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          FlutterMap(
            options: MapOptions(
              minZoom: 5,
              maxZoom: 18,
              zoom: 13,
              center: AppConstants.userLocation,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    "https://api.mapbox.com/styles/v1/playermathinson/clcahnp7s000415r4b12il5mr/tiles/256/{z}/{x}/{y}@2x?access_token=pk.eyJ1IjoicGxheWVybWF0aGluc29uIiwiYSI6ImNsMXFnMjRvbjEybHUza3BkanNjcTNxZjcifQ.JK4A3zEl7O9U7-8G48avag",
                additionalOptions: {
                   'mapStyleId': AppConstants.mapBoxStyleId,
                   'accessToken': AppConstants.mapBoxAccessToken,
                },
              ),
              MarkerLayer(
                markers : myMarker ,
              ),
                //Here it starts
              //   Container(
              //   color: Colors.grey,
              //   child: MapBoxNavigationView(
              //       options: _options,
              //       onRouteEvent: _onRouteEvent,
              //       onCreated:
              //           (MapBoxNavigationViewController controller) async {
              //         _controller = controller;
              //       }),
              // ),
            ],
          ),
          ElevatedButton(
            onPressed: findDriverProcessStart, 
            child: Text("I am ready to drive"),
            style: ElevatedButton.styleFrom(
                primary: Colors.red,
            ),
          )

        ],
      ),
    );
  }
}
