//
//  MapViewController.swift
//  AppStation
//
//  Created by Matthieu Guillemin on 04/04/2024.
//

import Foundation
import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController, CLLocationManagerDelegate {
    
    @IBOutlet weak var map: MKMapView!
    let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
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
        let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
        map.setRegion(region, animated: true)
        
        // Mise à jour de la variable globale userLocation
        // self.userLocation = userLocation.coordinate
        
        let latMin = (userLocation.coordinate.latitude - 5) * 100000
        let latMax = (userLocation.coordinate.latitude + 5) * 100000
        let lonMin = (userLocation.coordinate.longitude - 5) * 100000
        let lonMax = (userLocation.coordinate.longitude + 5) * 100000
        
        let baseUrl = "https://data.economie.gouv.fr/api/explore/v2.1/catalog/datasets/prix-carburants-flux-instantane-v2/records"
        let query   = "latitude>=\(latMin) AND latitude<=\(latMax) AND longitude>=\(lonMin) AND longitude<=\(lonMax)"
        let apiUrl = URL(string: "\(baseUrl)?q=\(query)")!
         
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
                
            case .failure(let error):
                print("Erreur lors du chargement des données :", error)
            }
        }
        
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

}
