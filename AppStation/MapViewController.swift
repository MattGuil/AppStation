//
//  MapViewController.swift
//  AppStation
//
//  Created by Matthieu Guillemin on 04/04/2024.
//

// #### CODE A EXECUTER SUR UN VRAI DEVICE POUR ETRE GEOLOCALISE EN FRANCE ####
// #### L'API UTILISEE RECENSE UNIQUEMENT LES STATIONS SERVICES FRANCAISES ####

import Foundation
import UIKit
import MapKit
import CoreLocation

// Structure représentant un type de carburant
// Permettra de faciliter l'affichage des carburants disponibles à la station sélectionnée
struct Fuel {
    let name: String
    let price: String
}

// Structure représentant les informations principales de la station sélectionnée
// Facilitera le nettoyage préalable et l'affichage des données
struct Infos {
    var address: String
    var distance: Int
    var automate: Bool
    var fuels: [Fuel]
    var services: [String]
}


class MapViewController: UIViewController, MKMapViewDelegate, UICollectionViewDataSource, UICollectionViewDelegate  {
    
    // Outlets pour les éléments d'interface utilisateur
    @IBOutlet weak var map: MKMapView!
    @IBOutlet weak var centerMapOnUserButton: UIButton!
    @IBOutlet weak var infosView: UIView!
    @IBOutlet weak var automateIcon: UIImageView!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var fuelsCollectionView: UICollectionView!
    @IBOutlet weak var servicesList: UILabel!
    // @IBOutlet weak var servicesCollectionView: UICollectionView!
    
    // Propriétés de classe
    let locationManager = CLLocationManager()
    var stations: [[String: Any]]?
    var infos = Infos(address: "", distance: 0, automate: false, fuels: [], services: [])
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configuration du gestionnaire de localisation
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = kCLDistanceFilterNone
        locationManager.startUpdatingLocation()
        
        // Configuration de la carte
        map.showsUserLocation = true
        map.delegate = self
        
        infosView.layer.cornerRadius = 10
         
        // Ajoute un UITapGestureRecognizer à la vue principale
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        view.addGestureRecognizer(tapGesture)
        
        // S'assure que infosView est détectable par les gestes
        infosView.isUserInteractionEnabled = true
        
        // Configuration de la collectionView des carburants
        fuelsCollectionView.dataSource = self
        fuelsCollectionView.delegate = self
        
        // servicesCollectionView.dataSource = self
        // servicesCollectionView.delegate = self
        
        // Lancement d'une recherche
        self.launchAutomaticSearch()
        
    }
    
    // Méthode mère, appelée au démarrage de l'application
    func launchAutomaticSearch() {
        
        // On s'assure que l'utilisateur a bien été géolocalisé
        guard let userLocation = locationManager.location else {
            print("Impossible de récupérer la localisation de l'utilisateur.")
            return
        }
     
        // On récupère le nom de la ville dans laquelle l'utilisateur se trouve et on charge les données de toutes les stations services présentes dans cette ville depuis l'API
        self.getUserCity(forLocation: userLocation) { city in
            if let userCity = city {
                print("L'utilisateur est localisé dans la ville de : \(userCity)")
                self.loadDataFromAPI(userCity: userCity)
            } else {
                print("Impossible de déterminer la ville de l'utilisateur.")
            }
        }
        
        // Une fois que toutes les stations ont été géolocalisées, on centre la vue de la carte sur la position de l'utilisateur
        self.centerMapOnUserLocation(userLocation: userLocation)
    }
    
    // Méthode pour centrer la carte sur la position de l'utilisateur
    func centerMapOnUserLocation(userLocation: CLLocation) {
        
        let regionRadius: CLLocationDistance = 3000
        let region = MKCoordinateRegion(center: userLocation.coordinate, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
        map.setRegion(region, animated: true)
    }
    
    // Méthode pour récupérer la ville de l'utilisateur à partir de sa localisation
    func getUserCity(forLocation location: CLLocation, completion: @escaping (String?) -> Void) {
        
        let geocoder = CLGeocoder()
        // CLGeocoder est une classe du framework Core Location d'Apple qui fournit des fonctionnalités de géocodage et de géolocalisation inversée
        // Permet de convertir des adresses en coordonnées géographiques (géocodage) et vice versa (géolocalisation inversée)
        // Dans notre cas, on l'utilise pour la géolocalisation inversée
        
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
    
    // Méthode pour charger les données depuis l'API en fonction de la ville de l'utilisateur
    func loadDataFromAPI(userCity: String) {
        
        // On genère la requête API en fournissant...
        
        // ...le domaine, ...
        let urlString = "https://data.economie.gouv.fr/api/records/1.0/search/"
        var urlComponents = URLComponents(string: urlString)!
        
        // ...le dataset et les paramètres
        urlComponents.queryItems = [
            URLQueryItem(name: "dataset", value: "prix-des-carburants-en-france-flux-instantane-v2"),
            URLQueryItem(name: "q", value: "ville:\(userCity)"),
            URLQueryItem(name: "rows", value: "100")
        ]
        
        // On s'assure que la requête générée est valide
        guard let url = urlComponents.url else {
            print("Invalid URL")
            return
        }
        
        // On fait appel à la fonction sendRequest() pour l'envoyer
        sendRequest(apiUrl: url) { result in
            
            switch result {
            case .success(let data):
                
                // En cas de succès de la requête (code 200)
                // On traite la réponse
                
                if let records = data["records"] as? [[String: Any]] {
                    
                    // Enregistrement des stations renvoyées par l'API dans un tableau
                    // Permettra par la suite d'afficher de manière dynamique uniquement les informations concernant la station sélectionnée par l'utilisateur
                    self.stations = records
                    
                    var counterRecords = 0
                    var counterAnnotations = 0
                    
                    // On parcourt le JSON renvoyé par l'API
                    for record in records {
                        if let fields = record["fields"] as? [String: Any] {
                            
                            // Récupération des coordonnées géographiques de chaque station
                            if let geom = fields["geom"] as? [Double],
                               let latitude = geom.first,
                               let longitude = geom.last,
                               let adresse = fields["adresse"] as? String {
                                
                                // On place un marqueur sur la carte, légendé par l'adresse de la station
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
                
                // En cas d'échec de la requête (code 400 ou autres)
                // On affiche un message d'erreur
                
                print("Erreur lors du chargement des données (loadStationData) : \(error)")
            }
        }
    }
    
    // Méthode chargée d'envoyer les requêtes à l'API
    // Entrée : URL
    // Sortie : Réponse de l'API
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
    
    // Méthode appelée lorsque le bouton permettant de centrer la carte sur l'utilisateur est cliqué
    @IBAction func centerMapOnUserClicked(_ sender: UIButton) {
        
        guard let userLocation = locationManager.location else {
            print("Impossible de récupérer la localisation de l'utilisateur.")
            return
        }
        
        self.centerMapOnUserLocation(userLocation: userLocation)
    }
    
    // Méthode appelée à chaque fois que l'utilisateur clique sur un des marqueurs représentants les stations services sur la carte
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        
        guard let annotation = view.annotation as? MKPointAnnotation else {
            return
        }
        
        // annotation (CLLocation) correspond maintenant à la station séléctionnée par l'utilisateur
        
        // On tente de définir un itinéraire entre l'utilisateur et cette station
        var route : MKRoute?
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: self.locationManager.location!.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: annotation.coordinate))
        request.transportType = .automobile // On est souvent en voiture lorsqu'on a besoin d'essence
        
        let directions = MKDirections(request: request)
        // MKDirections est une classe fournie par Apple dans le framework MapKit
        // Elle permet de calculer l'itinéraire entre deux points géographiques donnés
        // et facilite la gestion des informations de direction, telles que les étapes de l'itinéraire, la distance et la durée estimée du trajet
        // Dans notre cas, on l'utilise pour définir itinéraire et distance
        
        directions.calculate { [self] (response, error) in
            guard let response = response, error == nil else {
                print("Erreur lors du calcul de l'itinéraire : \(error?.localizedDescription ?? "Erreur inconnue")")
                return
            }
            
            // Si la requête itinéraire a fonctionné, on affiche l'itinéraire de la nouvelle station sélectionnée sur la carte
            // En prenant soin de supprimer, s'il existait, l'itinéraire vers la dernière station sélectionnée avant celle-ci
            route = response.routes[0]
            self.map.removeOverlays(self.map.overlays)
            self.map.addOverlay(route!.polyline, level: .aboveRoads)
            
            // Centrage de la vue sur l'itinéraire actif
            let insets = UIEdgeInsets(top: 75, left: 50, bottom: 275, right: 50)
            self.map.setVisibleMapRect(route!.polyline.boundingMapRect, edgePadding: insets, animated: true)
            
            // On recupère les informations de la station séléctionnée en faisant appel à getInfosForStationAtAddress()
            if let stationAddress = annotation.title {
                self.getInfosForStationAtAddress(requestedAddress: stationAddress, distanceFromUser: Int(round(route!.distance)))
            }
            
            // On met à jour les outlets de l'interface avec les informations récupérées
            // En récupérant les données dans l'instance de la structure Infos mise à jour par la fonction getInfosForStationAtAdress()
            self.automateIcon.isHidden = !infos.automate
            self.addressLabel.text = infos.address
            self.distanceLabel.text = "à \(infos.distance) m"
            // Mise à jour de la CollectionView des carburants pour afficher les carburants disponibles à la station sélectionnée, ainsi que leurs prix
            self.fuelsCollectionView.reloadData()
            
            // Calculs permettant de centrer le contenu de la CollectionView des carburants
            let fuelsCollectionViewWidth = fuelsCollectionView.frame.width
            let cellWidth: CGFloat = 65
            let totalNumberOfCells = fuelsCollectionView.numberOfItems(inSection: 0)
            let totalCellWidth = CGFloat(totalNumberOfCells) * cellWidth
            let horizontalInset = max((fuelsCollectionViewWidth - totalCellWidth) / 2, 0)
            // Application de la marge calculée
            if let flowLayout = fuelsCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
                flowLayout.sectionInset = UIEdgeInsets(top: 0, left: horizontalInset, bottom: 0, right: horizontalInset)
            }
            
            // Affichage des services proposés à la station sélectionnée
            self.servicesList.text = self.infos.services.joined(separator: ", ")
            // self.servicesCollectionView.reloadData()
            // print(servicesCollectionView.numberOfItems(inSection: 0))
            
            // Affichage de la fenêtre présentant toutes les informations récupérées sur la station sélectionnée
            self.infosView.isHidden = false
        }
        
    }
        
    // Méthode appelée pour récupérer les informations concernants la station séléctionnée
    // Met à jour l'instance de la structure Infos connectée à la InfosView pour afficher les données dynamiquement
    func getInfosForStationAtAddress(requestedAddress: String, distanceFromUser: Int) {
        
        // Parcours des stations recupérées par la requête API et récupération des informations à afficher dans l'application
        for station in self.stations! {
            if let fields = station["fields"] as? [String: Any],
               let automate = fields["horaires_automate_24_24"] as? String,
               let address = fields["adresse"] as? String,
               let fuelsString = fields["prix"] as? String,
               let servicesString = (fields["services_service"] as? String) ?? (fields["services"] as? String) ?? "Aucun service renseigné." as? String {
                
                // On utilise les adresses des stations comme identifiants uniques pour cibler la station sélectionnée dans le tableau self.stations
                if address.uppercased() == requestedAddress.uppercased() {
                    
                    /*
                    print("#")
                    print("Adresse : \(address)")
                    print("Distance : \(distanceFromUser)")
                    print("Automate 24/24 : \(automate == "Oui")")
                    print("Carburants : \(fuelsString)")
                    print("#")
                    */
                    
                    // Nettoyage et sauvegarde (dans l'instance de la structure Infos) des informations concernants la station service sélectionnée
                    self.infos.address = address.uppercased()
                    self.infos.distance = distanceFromUser
                    self.infos.automate = (automate == "Oui")
                    self.infos.fuels = []
                    self.infos.services = []
                    
                    // Traitement des carburants, stockés sous forme d'un objet JSON sérialisé
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
                    
                    // Traitement particulier des services
                    // Car ils sont représentés sous 2 formes différentes dans l'API (chaine de caractères avec séparateur et objet JSON sérialisé)
                    
                    if servicesString == "Aucun service renseigné." {
                        self.infos.services = ["Aucun service renseigné."]
                    } else if servicesString.contains("{") {
                        
                        // Traite services comme un objet JSON sérialisé
                        if let data = servicesString.data(using: .utf8) {
                            do {
                                if let jsonObject = try JSONSerialization.jsonObject(with: data, options: []) as? [String: [String]] {
                                    if let servicesArray = jsonObject["service"] {
                                        for service in servicesArray {
                                            self.infos.services.append(service)
                                        }
                                    } else {
                                        print("Clé 'service' manquante dans l'objet JSON.")
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
                    } else {
                        
                        // Traite services comme une chaine de caractères avec séparateur
                        self.infos.services = servicesString.components(separatedBy: "//")
                    }
                }
            }
        }
    }
    
    // Méthode du protocole MKMapViewDelegate, appelée lorsque la carte a besoin de dessiner un overlay
    // Dans notre cas, permet de dessiner l'itinéraire entre l'utilisateur et la station service selectionnée
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        guard let polyline = overlay as? MKPolyline else {
            return MKOverlayRenderer()
        }
        
        let renderer = MKPolylineRenderer(polyline: polyline)
        renderer.strokeColor = .systemBlue
        renderer.lineWidth = 5
        return renderer
    }
    
    // Gestion d'un clic en dehors de la InfosView
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


// Extension de MapViewController pour implémenter les méthodes de UICollectionViewDataSource
extension MapViewController {

    // Méthodes appelée à chaque mise à jour de self.infos.fuels
    // ------
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.infos.fuels.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        // Configuration de chaque cellule de la collectionView des carburants
        let fuelCell = collectionView.dequeueReusableCell(withReuseIdentifier: "FuelCell", for: indexPath) as! FuelCell
        let fuel = self.infos.fuels[indexPath.item]
        fuelCell.configure(with: fuel)
        return fuelCell
    }
    // ------

}
 
// Classe représentant une cellule de la collectionView des carburants
class FuelCell: UICollectionViewCell {

    // Outlets pour les éléments d'interface utilisateur de la cellule
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var priceLabel: UILabel!

    // Méthode pour configurer la cellule avec les données d'un type de carburant
    func configure(with fuel: Fuel) {
        imageView.image = UIImage(named: fuel.name)
        priceLabel.text = fuel.price
    }
}
