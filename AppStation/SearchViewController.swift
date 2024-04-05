//
//  ViewController.swift
//  AppStation
//
//  Created by Matthieu Guillemin on 02/04/2024.
//

import UIKit
import MapKit

class SearchViewController: UIViewController {

    
    
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
                        
                        var markedDepartments = Set<String>()
                        
                        // parcours de toutes les stations services enregistrées dans l'API
                        for record in records {
                            if let cpString = record["cp"] as? String {
                                let department = String(cpString.prefix(2))
                                if !markedDepartments.contains(department) {
                                    // récupération des coordonnées géographiques de la station courante
                                    if let geo_point = record["geo_point"] as? [String: Double] {
                                        
                                        // création d'une annotation de marqueur pour la station courante
                                        let annotation = MKPointAnnotation()
                                        annotation.coordinate = CLLocationCoordinate2D(latitude: geo_point["lat"] ?? 0.0, longitude: geo_point["lon"] ?? 0.0)
                                        
                                        // ajout de l'annotation à la carte
                                        DispatchQueue.main.async {
                                            // self.map.addAnnotation(annotation)
                                        }
                                    }
                                    
                                    markedDepartments.insert(department)
                                }
                            }
                        }
                        
                        print(markedDepartments.sorted())
                    }
                }
            } catch {
                print("Erreur lors de la conversion JSON : \(error)")
            }
        }
        
        // lancement de la tâche
        task.resume()
        
    }


}

