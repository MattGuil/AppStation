//
//  MapViewController.swift
//  AppStation
//
//  Created by Matthieu Guillemin on 04/04/2024.
//

import UIKit
import MapKit

class MapViewController: UIViewController {

    @IBOutlet weak var map: MKMapView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

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
                    if let records = json["results"] as? [[String: Any]] {
                        
                        var stationCounter = 0
                        
                        // parcours de toutes les stations services enregistrées dans l'API
                        for record in records {
                            // récupération des coordonnées géographiques de la station courante
                            if let geo_point = record["geo_point"] as? [String: Double] {
                                
                                // création d'une annotation de marqueur pour la station courante
                                let annotation = MKPointAnnotation()
                                annotation.coordinate = CLLocationCoordinate2D(latitude: geo_point["lat"] ?? 0.0, longitude: geo_point["lon"] ?? 0.0)
                                
                                // ajout de l'annotation à la carte
                                DispatchQueue.main.async {
                                    self.map.addAnnotation(annotation)
                                }
                            }
                            
                            stationCounter += 1
                        }
                        
                        print("stationCounter = \(stationCounter)")
                        
                    }
                }
            } catch {
                print("Erreur lors de la conversion JSON : \(error)")
            }
        }
        
        // lancement de la tâche
        task.resume()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
