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

struct Fuel {
    let name: String
    let price: String
}

struct Infos {
    var address: String
    var distance: Int
    var automate: Bool
    var fuels: [Fuel]
}


class MapViewController: UIViewController, MKMapViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate  {
    
    @IBOutlet weak var map: MKMapView!
    let locationManager = CLLocationManager()
    
    var stations: [[String: Any]]?
    
    @IBOutlet weak var centerMapOnUserButton: UIButton!
    
    var infos = Infos(address: "", distance: 0, automate: false, fuels: [])
    
    @IBOutlet weak var infosView: UIView!
    @IBOutlet weak var automateIcon: UIImageView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    
    @IBOutlet weak var collectionView: UICollectionView!
    
    /*
    @IBOutlet weak var servicesLabel: UILabel!
    */
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.startUpdatingLocation()
        
        map.showsUserLocation = true
        map.delegate = self
        
        self.launchAutomaticSearch()
        
        infosView.layer.cornerRadius = 10
         
        // Ajoute un UITapGestureRecognizer à la vue principale
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        // S'assure que infosView est détectable par les gestes
        infosView.isUserInteractionEnabled = true
        
        collectionView.dataSource = self
        collectionView.delegate = self
        
    }
    
    func launchAutomaticSearch() {
        guard let userLocation = locationManager.location else {
            print("Impossible de récupérer la localisation de l'utilisateur.")
            return
        }
     
        self.getUserCity(forLocation: userLocation) { city in
            if let userCity = city {
                print("L'utilisateur est localisé dans la ville de : \(userCity)")
                self.loadDataFromAPI(userCity: userCity)
            } else {
                print("Impossible de déterminer la ville de l'utilisateur.")
            }
        }
        
        self.centerMapOnUserLocation(userLocation: userLocation)
    }
    
    func centerMapOnUserLocation(userLocation: CLLocation) {
        
        let regionRadius: CLLocationDistance = 3000
        let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
        map.setRegion(region, animated: true)
    }
    
    func getUserCity(forLocation location: CLLocation, completion: @escaping (String?) -> Void) {
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
    
    func loadDataFromAPI(userCity: String) {
        let urlString = "https://data.economie.gouv.fr/api/records/1.0/search/"
        var urlComponents = URLComponents(string: urlString)!
        
        urlComponents.queryItems = [
            URLQueryItem(name: "dataset", value: "prix-des-carburants-en-france-flux-instantane-v2"),
            URLQueryItem(name: "q", value: "ville:\(userCity)"),
            URLQueryItem(name: "rows", value: "100")
        ]
        
        guard let url = urlComponents.url else {
            print("Invalid URL")
            return
        }
        
        sendRequest(apiUrl: url) { result in
            
            switch result {
            case .success(let data):
                
                if let records = data["records"] as? [[String: Any]] {
                    
                    self.stations = records
                    
                    var counterRecords = 0
                    var counterAnnotations = 0
                    
                    for record in records {
                        if let fields = record["fields"] as? [String: Any] {
                            
                            if let geom = fields["geom"] as? [Double],
                               let latitude = geom.first,
                               let longitude = geom.last,
                               let adresse = fields["adresse"] as? String {
                                
                                // Marquer toutes les stations sur la map
                                let annotation = MKPointAnnotation()
                                annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                                annotation.title = adresse.uppercased()
                                self.map.addAnnotation(annotation)
                                
                                counterAnnotations += 1
                            }
                        }
                        counterRecords += 1
                    }
                    
                    print("Nombre de stations correspondantes à la requête dans l'API : \(counterRecords)")
                    print("Nombre de stations placées sur la map : \(counterAnnotations)")
                    
                }
            case .failure(let error):
                print("Erreur lors du chargement des données (loadStationData) : \(error)")
            }
        }
    }
    
    
    func sendRequest(apiUrl: URL, completion: @escaping (Result<[String: Any], Error>) -> Void) {
        
        // Création de la session URLSession
        let session = URLSession.shared
        
        // Création de la tâche
        let task = session.dataTask(with: apiUrl) { data, response, error in
            // Vérification des erreurs
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // Vérification de la réponse
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                completion(.failure(NSError(domain: "Response Error", code: 0, userInfo: nil)))
                return
            }
            
            // Vérification des données
            guard let data = data else {
                completion(.failure(NSError(domain: "Data Error", code: 0, userInfo: nil)))
                return
            }
            
            // Récupération des données JSON
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: []) as! [String: Any]
                completion(.success(json))
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
    
    @IBAction func centerMapOnUserClicked(_ sender: UIButton) {
        
        guard let userLocation = locationManager.location else {
            print("Impossible de récupérer la localisation de l'utilisateur.")
            return
        }
        
        self.centerMapOnUserLocation(userLocation: userLocation)
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        guard let annotation = view.annotation as? MKPointAnnotation else {
            return
        }
        
        var route : MKRoute?
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: self.locationManager.location!.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: annotation.coordinate))
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        
        directions.calculate { [self] (response, error) in
            guard let response = response, error == nil else {
                print("Erreur lors du calcul de l'itinéraire : \(error?.localizedDescription ?? "Erreur inconnue")")
                return
            }
            
            route = response.routes[0]
            self.map.removeOverlays(self.map.overlays)
            self.map.addOverlay(route!.polyline, level: .aboveRoads)
            
            let insets = UIEdgeInsets(top: 75, left: 50, bottom: 275, right: 50)
            self.map.setVisibleMapRect(route!.polyline.boundingMapRect, edgePadding: insets, animated: true)
            
            if let stationAddress = annotation.title {
                self.getInfosForStationAtAddress(requestedAddress: stationAddress, distanceFromUser: Int(round(route!.distance)))
            }
            
            self.automateIcon.isHidden = !infos.automate
            self.addressLabel.text = infos.address
            self.distanceLabel.text = "à \(infos.distance) m"
            
            self.collectionView.reloadData()
            
            // Afficher la InfosView
            self.infosView.isHidden = false
        }
        
    }
        
    func getInfosForStationAtAddress(requestedAddress: String, distanceFromUser: Int) {
        
        for station in self.stations! {
            if let fields = station["fields"] as? [String: Any],
               let automate = fields["horaires_automate_24_24"] as? String,
               let address = fields["adresse"] as? String,
               let fuelsString = fields["prix"] as? String {
                
                if address.uppercased() == requestedAddress.uppercased() {
                    
                    /*
                    print("#")
                    print("Adresse : \(address)")
                    print("Distance : \(distanceFromUser)")
                    print("Automate 24/24 : \(automate == "Oui")")
                    print("Carburants : \(fuelsString)")
                    print("#")
                    */
                    
                    self.infos.address = address.uppercased()
                    self.infos.distance = distanceFromUser
                    self.infos.automate = (automate == "Oui")
                    self.infos.fuels = []
                        
                    if let data = fuelsString.data(using: .utf8) {
                        do {
                            let JSONObj = try JSONSerialization.jsonObject(with: data, options: [])
                            if let array = JSONObj as? [[String: String]] {
                                for fuelData in array {
                                    if let name = fuelData["@nom"],
                                       let price = fuelData["@valeur"] {
                                        self.infos.fuels.append(Fuel(name: name, price: price))
                                    }
                                }
                            } else {
                                print("Format JSON invalide.")
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
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer()
        }
        
        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = .systemBlue
        renderer.lineWidth = 5
        return renderer
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer) {
        let location = sender.location(in: self.view)
        if !self.infosView.frame.contains(location) {
            
            // Cacher InfosView
            self.infosView.isHidden = true
            
            // Désélectionner l'annotation actuellement sélectionnée sur la carte
            if let selectedAnnotation = map.selectedAnnotations.first {
                self.map.deselectAnnotation(selectedAnnotation, animated: true)
            }
            
            // Effacer l'itinéraire affiché à l'écran
            self.map.removeOverlays(self.map.overlays)
        }
    }
    
    
}


extension MapViewController {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return infos.fuels.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FuelCell", for: indexPath) as! FuelCell
        let fuel = infos.fuels[indexPath.item]
        cell.configure(with: fuel)
        return cell
    }

}
 
 
class FuelCell: UICollectionViewCell {

    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var priceLabel: UILabel!

    func configure(with fuel: Fuel) {
        imageView.image = UIImage(named: fuel.name)
        priceLabel.text = fuel.price
    }
}
