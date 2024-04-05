//
//  MapViewController.swift
//  AppStation
//
//  Created by Matthieu Guillemin on 04/04/2024.
//

import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController {
    
    let locationManager = CLLocationManager()
    
    // var stations: [[String: Any]] = []
    @IBOutlet weak var map: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // loadDataFromAPI()
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.startUpdatingLocation()
        
        map.showsUserLocation = true
    }
    
    func loadDataFromAPI() {
        // définition de l'URL de l'API
        let apiUrl = URL(string: "https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/prix_des_carburants_j_7/records")!
        
        // création de la session URLSession
        let session = URLSession.shared
        
        // création de la tâche de données
        let task = session.dataTask(with: apiUrl) { data, response, error in
            // vérification des erreurs
            if let error = error {
                print("Erreur : \(error)")
                return
            }
            
            // vérification de la réponse
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("Réponse invalide")
                return
            }
            
            // vérification des données
            guard let data = data else {
                print("Aucune donnée reçue")
                return
            }
            
            // récupération des données JSON
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print(json)
                }
            } catch {
                print("Erreur lors de la conversion JSON : \(error)")
            }
        }
        
        // lancement de la tâche
        task.resume()
    }

    /*
     func placeNearestStationMarker(userLocation: CLLocation) {
         var nearestStation: [String: Any]? = nil
         var nearestDistance: CLLocationDistance = Double.infinity

         for record in self.stations {
             guard let geo_point = record["geo_point"] as? [String: Double],
                   let latitude = geo_point["lat"],
                   let longitude = geo_point["lon"] else {
                 continue
             }

             let stationLocation = CLLocation(latitude: latitude, longitude: longitude)
             let distance = userLocation.distance(from: stationLocation)

             if distance < nearestDistance {
                 nearestDistance = distance
                 nearestStation = record
             }
         }

         if let nearestStation = nearestStation {
             // Ajouter un marqueur pour la station la plus proche sur la carte
             if let latitude = (nearestStation["geo_point"] as? [String: Double])?["lat"],
                let longitude = (nearestStation["geo_point"] as? [String: Double])?["lon"],
                let stationName = nearestStation["station_name"] as? String {
                 let annotation = MKPointAnnotation()
                 annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                 annotation.title = stationName
                 map.addAnnotation(annotation)
             }
         }
     }
     */


}
