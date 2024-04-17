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

struct Carburant {
    let nom: String
    let prix: String
}

class CarburantCell: UICollectionViewCell {
    
    // Définis les IBOutlets pour les éléments de ta cellule (par exemple, UIImageView pour l'image, UILabel pour le prix, etc.)
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var prixLabel: UILabel!
    
    // Méthode pour configurer la cellule avec les données du carburant
    func configure(with carburant: Carburant) {
        imageView.image = UIImage(named: carburant.nom)
        prixLabel.text = carburant.prix
    }
}

// Dans ta classe UICollectionViewDataSource
extension MapViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return carburants.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "CarburantCell", for: indexPath) as! CarburantCell
        let carburant = carburants[indexPath.item]
        cell.configure(with: carburant)
        return cell
    }
}

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    @IBOutlet weak var map: MKMapView!
    let locationManager = CLLocationManager()
    @IBOutlet weak var searchButton: UIButton!
    
    var stations : [[String: Any]]?
    
    var carburants: [Carburant] = []
    
    @IBOutlet weak var InfoView: UIView!
    @IBOutlet weak var adresseLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var carburantsLabel: UIView!
    @IBOutlet weak var automateIcon: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.startUpdatingLocation()
        
        map.showsUserLocation = true
        map.delegate = self
        
        self.centerMapOnUserLocation()
        
        InfoView.layer.cornerRadius = 10
        
        // Ajoute un UITapGestureRecognizer à la vue principale
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        // Assure-toi que InfoView est détectable par les gestes
        InfoView.isUserInteractionEnabled = true
        
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        // Vérifie si le tap a eu lieu en dehors de InfoView
        let location = sender.location(in: self.view)
        if !InfoView.frame.contains(location) {
            // Cacher InfoView
            InfoView.isHidden = true
            
            // Désélectionner l'annotation actuellement sélectionnée sur la carte
            if let selectedAnnotation = map.selectedAnnotations.first {
                map.deselectAnnotation(selectedAnnotation, animated: true)
            }
            
            // Effacer l'itinéraire affiché à l'écran
            self.map.removeOverlays(self.map.overlays)
        }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let annotation = view.annotation as? MKPointAnnotation else {
            return
        }
        
        // Créer une requête d'itinéraire
        var route : MKRoute?
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: self.locationManager.location!.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: annotation.coordinate))
        request.transportType = .automobile

        // Créer un objet de direction pour obtenir les instructions de l'itinéraire
        let directions = MKDirections(request: request)

        // Calculer l'itinéraire
        directions.calculate { [self] (response, error) in
            guard let response = response, error == nil else {
                 print("Erreur lors du calcul de l'itinéraire : \(error?.localizedDescription ?? "Erreur inconnue")")
                 return
            }

            // Obtenir le premier itinéraire de la réponse
            route = response.routes[0]
            // Effacer l'itinéraire actuellement à l'écran (s'il existe)
            self.map.removeOverlays(self.map.overlays)
            // Ajouter l'itinéraire à la carte
            self.map.addOverlay(route!.polyline, level: .aboveRoads)

            // Centrer la vue de la carte sur l'itinéraire le plus court
            let insets = UIEdgeInsets(top: 75, left: 50, bottom: 275, right: 50) // Marge autour de l'itinéraire
            self.map.setVisibleMapRect(route!.polyline.boundingMapRect, edgePadding: insets, animated: true)
            
            // Récupérer les informations sur la station depuis les données de la station
            for station in self.stations! {
                if let fields = station["fields"] as? [String: Any],
                   let automate = fields["horaires_automate_24_24"] as? String,
                   let adresse = fields["adresse"] as? String,
                   let carburantsString = fields["prix"] as? String {
                    
                    if adresse.uppercased() == annotation.title {
                        self.automateIcon.isHidden = (automate == "Non")
                        self.adresseLabel.text = adresse.uppercased()
                        self.distanceLabel.text = "à \(Int(round(route!.distance))) m"
                        
                        // Convertir la chaîne carburantsDisponibles en tableau en utilisant le point-virgule comme délimiteur
                        // let carburantsArray = carburantsDisponibles.components(separatedBy: ";")

                        // Créer une UIStackView pour contenir les icones de carburant
                        let stackView = UIStackView()
                        stackView.axis = .horizontal
                        stackView.alignment = .center
                        stackView.distribution = .equalCentering
                        stackView.spacing = 10 // Espacement entre les images (ajuste selon tes préférences)
                        
                        if let data = carburantsString.data(using: .utf8) {
                            do {
                                let JSONObj = try JSONSerialization.jsonObject(with: data, options: [])
                                
                                if let array = JSONObj as? [[String: String]] {
                                    for carburant in array {
                                        // Vérifier si une image correspondante existe dans tes assets
                                        if let nom = carburant["@nom"],
                                           let prix = carburant["@valeur"],
                                           let image = UIImage(named: nom) {
                                            let imageView = UIImageView(image: image)
                                            
                                            let carburant = Carburant(nom: nom, prix: prix)
                                            carburants.append(carburant)
                                            
                                            imageView.contentMode = .scaleToFill
                                            imageView.widthAnchor.constraint(equalToConstant: 40).isActive = true
                                            imageView.heightAnchor.constraint(equalToConstant: 40).isActive = true
                                            
                                            // Ajouter l'image à la stackView
                                            stackView.addArrangedSubview(imageView)
                                        }
                                    }
                                    
                                    for subview in self.carburantsLabel.subviews {
                                        subview.removeFromSuperview()
                                    }
                                    
                                    // Définir l'alignement de la stackView sur .center
                                    stackView.alignment = .center

                                    // Ajouter la stackView à carburantsLabel
                                    carburantsLabel.addSubview(stackView)

                                    // Définir les contraintes pour centrer la stackView horizontalement
                                    stackView.translatesAutoresizingMaskIntoConstraints = false
                                    stackView.centerXAnchor.constraint(equalTo: carburantsLabel.centerXAnchor).isActive = true
                                    stackView.centerYAnchor.constraint(equalTo: carburantsLabel.centerYAnchor).isActive = true
                                } else {
                                    print("Invalid JSON format")
                                }
                            } catch {
                                print("Erreur lors de la conversion de la chaîne en JSON : \(error)")
                            }
                        } else {
                            print("Impossible de convertir la chaîne en données UTF-8")
                        }
                        
                     }
                }
            }
            
            self.InfoView.isHidden = false
        }
        
    }
    
    // Fonction pour dessiner les lignes de l'itinéraire sur la carte
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
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
                                annotation.title = adresse.uppercased()
                                self.map.addAnnotation(annotation)

                                counterAnnotations += 1
                            }

                        }
                        counterRecords += 1
                    }
                    
                    print("counterRecords = \(counterRecords)")
                    print("counterAnnotations = \(counterAnnotations)")
                    
                    // Centrer la vue sur la position de l'utilisateur
                    self.centerMapOnUserLocation()
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
    
    
    func centerMapOnUserLocation() {
        if let userLocation = locationManager.location?.coordinate {
            let regionRadius: CLLocationDistance = 1000 // Rayon de la région en mètres
            let region = MKCoordinateRegion(center: userLocation, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
            map.setRegion(region, animated: true)
        }
    }

}
