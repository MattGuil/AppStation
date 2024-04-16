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

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    @IBOutlet weak var map: MKMapView!
    let locationManager = CLLocationManager()
    @IBOutlet weak var searchButton: UIButton!
    
    var stations : [[String: Any]]?
    var infoView: InfoView?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.startUpdatingLocation()
        
        map.delegate = self
        
        // Ajouter la vue personnalisée InfoView
        infoView = InfoView(frame: CGRect(x: 0, y: view.frame.height, width: view.frame.width, height: 200))
        view.addSubview(infoView!)
        
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? MKPointAnnotation else {
            return
        }
        
        // Récupérer les informations sur la station depuis les données de la station
        for station in self.stations! {
            if let fields = station["fields"] as? [String: Any],
               let adresse = fields["adresse"] as? String,
               let carburantsDisponibles = fields["carburants_disponibles"] as? String {
                
                if adresse == annotation.title {
                    // Afficher la vue InfoView avec les informations pertinentes
                    let infoView = InfoView(frame: CGRect(x: 0, y: view.frame.height - 200, width: view.frame.width, height: 200))
                    infoView.configure(adresse: adresse, carburantsDisponibles: carburantsDisponibles)
                    view.superview?.addSubview(infoView)
                    UIView.animate(withDuration: 0.3) {
                        infoView.frame.origin.y = view.frame.height - 200
                    }
                    break
                }
            }
        }
    }
    
    // Fonction pour dessiner les lignes de l'itinéraire sur la carte
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        // Afficher la localisation de l'utilisateur sur la carte
        map.showsUserLocation = true
        
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer()
        }
        
        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = .systemBlue
        renderer.lineWidth = 5
        return renderer
    }
    
    // Cette méthode est appelée chaque fois que la position de l'utilisateur est mise à jour
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        /*
         // Récupérer la dernière position de l'utilisateur
         guard let userLocation = locations.last else {
             return
         }
         
         // Mettre à jour la région de la carte pour inclure la nouvelle position de l'utilisateur
         let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: 2000, longitudinalMeters: 2000)
         map.setRegion(region, animated: true)
        */
        
    }
    
    // Gérer les erreurs de localisation
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Error requesting location: \(error.localizedDescription)")
    }
    
    
    
    @IBAction func searchButtonClicked(_ sender: UIButton) {
        guard let userLocation = locationManager.location else {
            print("Impossible de récupérer la localisation de l'utilisateur.")
            return
        }
        
        getUserCityLoc(forLocation: userLocation) { cityName in
            if let userCityLoc = cityName {
                print("La ville de l'utilisateur est : \(userCityLoc)")
                self.loadStationData(userCityLoc: userCityLoc)
            } else {
                print("Impossible de déterminer la ville de l'utilisateur.")
            }
        }
    }
    
    
    func getUserCityLoc(forLocation location: CLLocation, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard let placemark = placemarks?.first, error == nil else {
                // Gestion de l'erreur
                completion(nil)
                return
            }
            
            // Récupération du nom de la ville depuis le placemark
            if let city = placemark.locality {
                completion(city)
            } else {
                // Si le nom de la ville n'est pas disponible, on peut essayer d'autres informations comme le nom de la commune ou de la sous-localité
                if let subLocality = placemark.subLocality {
                    completion(subLocality)
                } else if let subAdministrativeArea = placemark.subAdministrativeArea {
                    completion(subAdministrativeArea)
                } else {
                    // Si aucune information n'est disponible, retourner nil
                    completion(nil)
                }
            }
        }
    }
    
    func loadStationData(userCityLoc: String) {
        let urlString = "https://data.economie.gouv.fr/api/records/1.0/search/"
        var urlComponents = URLComponents(string: urlString)!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "dataset", value: "prix-carburants-flux-instantane-v2"),
            URLQueryItem(name: "q", value: "ville:\(userCityLoc)"),
            URLQueryItem(name: "rows", value: "100")
        ]
        
        guard let url = urlComponents.url else {
            print("Invalid URL")
            return
        }
        
        loadDataFromAPI(apiUrl: url) { result in
            
            // Itinéraire le plus court
            var shortestRoute: MKRoute?

            // Position de l'itinéraire le plus court
            var destinationCoordinate: CLLocationCoordinate2D?
            
            switch result {
            case .success(let data):
                
                if let records = data["records"] as? [[String: Any]] {
                
                    self.stations = records
                    
                    var counterRecords = 0
                    var counterAnnotations = 0
                    
                    for record in records {
                        if let fields = record["fields"] as? [String: Any] {
                            
                            if let latitudeString = fields["latitude"] as? String,
                               let longitudeString = fields["longitude"] as? String,
                               let latitude = Double(latitudeString),
                               let longitude = Double(longitudeString),
                               let adresse = fields["adresse"] as? String {

                                // Marquer toutes les stations sur la map
                                let annotation = MKPointAnnotation()
                                annotation.coordinate = CLLocationCoordinate2D(latitude: latitude/100000, longitude: longitude/100000)
                                annotation.title = adresse
                                self.map.addAnnotation(annotation)

                                // Créer une requête d'itinéraire
                                let request = MKDirections.Request()
                                request.source = MKMapItem(placemark: MKPlacemark(coordinate: self.locationManager.location!.coordinate))
                                request.destination = MKMapItem(placemark: MKPlacemark(coordinate: annotation.coordinate))
                                request.transportType = .automobile // Spécifier le type de transport

                                // Créer un objet de direction pour obtenir les instructions de l'itinéraire
                                let directions = MKDirections(request: request)

                                // Calculer l'itinéraire
                                directions.calculate { (response, error) in
                                    guard let response = response, error == nil else {
                                         print("Erreur lors du calcul de l'itinéraire : \(error?.localizedDescription ?? "Erreur inconnue")")
                                         return
                                    }

                                    // Obtenir le premier itinéraire de la réponse
                                    let route = response.routes[0]

                                    // Vérifier si c'est le plus court jusqu'à présent
                                    if shortestRoute == nil || route.distance < shortestRoute!.distance {
                                        shortestRoute = route
                                        destinationCoordinate = annotation.coordinate

                                        self.map.removeOverlays(self.map.overlays)
                                        // Ajouter l'itinéraire à la carte
                                        self.map.addOverlay(route.polyline, level: .aboveRoads)
                                    }

                                    // Centrer la vue de la carte sur l'itinéraire le plus court
                                    if destinationCoordinate != nil {
                                        let insets = UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50) // Marge autour de l'itinéraire
                                        self.map.setVisibleMapRect(shortestRoute!.polyline.boundingMapRect, edgePadding: insets, animated: true)
                                    }
                                }

                                counterAnnotations += 1
                            }

                        }
                        counterRecords += 1
                    }
                    
                    print("counterRecords = \(counterRecords)")
                    print("counterAnnotations = \(counterAnnotations)")
                }
            case .failure(let error):
                print("Erreur lors du chargement des données (loadStationData) : \(error)")
            }
        }
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
