//
//  MapViewController.swift
//  AppStation
//
//  Created by Matthieu Guillemin on 04/04/2024.
//

import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var map: MKMapView!
    
    let locationManager = CLLocationManager()
    
    var userLocation : CLLocation?
    
    // var stations: [[String: Any]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let apiUrl = URL(string: "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-des-carburants-en-france-flux-instantane-v2/records?select=adresse,geom&where=code_departement%3D75&limit=100")!
        
        loadDataFromAPI(apiUrl: apiUrl) { result in
            switch result {
            case .success(let json):
                print(json)
                
                if let records = json["results"] as? [[String: Any]] {
                    
                    var counterRecords = 0
                    var counterAnnotations = 0
                    
                    for record in records {
                        if let latitude = (record["geom"] as? [String: Double])?["lat"],
                           let longitude = (record["geom"] as? [String: Double])?["lon"] {
                            
                            let annotation = MKPointAnnotation()
                            annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                            if let adresse = record["adresse"] as? String {
                                annotation.title = adresse
                            }
                            self.map.addAnnotation(annotation)
                            
                            counterAnnotations += 1

                        }
                        counterRecords += 1
                    }
                    
                    print("counterRecords = \(counterRecords)")
                    print("counterAnnotations = \(counterAnnotations)")
                }
                
                /*
                // Affiche les distances
                if let records = json["results"] as? [[String: Any]] {
                        
                    var counter = 0
                    
                    for record in records {
                            
                            guard let geo_point = record["geom"] as? [String: Double],
                                  let latitude = geo_point["lat"],
                                  let longitude = geo_point["lon"] else {
                                continue
                            }
                         
                            let stationLocation = CLLocation(latitude: latitude, longitude: longitude)
                            if let userLocation = self.userLocation {
                                let distance = userLocation.distance(from: stationLocation)
                                print(distance)
                            } else {
                                print("Aucune position de l'utilisateur disponible")
                            }
                            counter += 1
                    
                    }
                    
                    print("counter = \(counter)")
                    
                }
                */
            case .failure(let error):
                print("Erreur lors du chargement des données :", error)
            }
        }
        
        // Demander l'autorisation pour l'utilisation de la localisation
        locationManager.requestWhenInUseAuthorization()
        
        // Définir le délégué de CLLocationManager
        locationManager.delegate = self
        
        // Configuration de la précision de la localisation
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        
        // Commencer à mettre à jour la localisation
        locationManager.startUpdatingLocation()
        
        // Afficher la localisation de l'utilisateur sur la carte
        map.showsUserLocation = true
    }
    
    // Cette méthode est appelée chaque fois que la position de l'utilisateur est mise à jour
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        // Récupérer la dernière position de l'utilisateur
        guard let userLocation = locations.last else {
            return
        }
        
        // Mettre à jour la région de la carte pour inclure la nouvelle position de l'utilisateur
        // let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
        // map.setRegion(region, animated: true)
        
        // Mise à jour de la variable globale userLocation
        self.userLocation = userLocation
    }
    
    // Gérer les erreurs de localisation
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error requesting location: \(error.localizedDescription)")
    }
    
    func loadDataFromAPI(apiUrl: URL, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        // création de la session URLSession
        let session = URLSession.shared
        
        // création de la tâche de données
        let task = session.dataTask(with: apiUrl) { data, response, error in
            // vérification des erreurs
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // vérification de la réponse
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "Response Error", code: 0, userInfo: nil)))
                return
            }
            
            // vérification des données
            guard let data = data else {
                completion(.failure(NSError(domain: "Data Error", code: 0, userInfo: nil)))
                return
            }
            
            // récupération des données JSON
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                completion(.success(json))
            } catch {
                completion(.failure(error))
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
                let stationName = nearestStation["name"] as? String {
                 let annotation = MKPointAnnotation()
                 annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                 annotation.title = stationName
                 self.map.addAnnotation(annotation)
             }
         }
     }
     */

}
