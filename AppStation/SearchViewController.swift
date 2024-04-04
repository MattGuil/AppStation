//
//  ViewController.swift
//  AppStation
//
//  Created by Matthieu Guillemin on 02/04/2024.
//

import UIKit

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
                        var fuelsSet = Set<String>()
                        var servicesSet = Set<String>()
                        
                        for record in records {
                            if let fuels = record["fuel"] as? [String] {
                                fuelsSet.formUnion(fuels)
                            }
                            if let services = record["services"] as? [String] {
                                servicesSet.formUnion(services)
                            }
                        }
                        
                        var fuelsList = Array(fuelsSet)
                        var servicesList = Array(servicesSet)
                        
                        // trier les tableaux par ordre alphabétique
                        fuelsList.sort()
                        servicesList.sort()
                        
                        print("Fuels : \(fuelsList)")
                        print("Services : \(servicesList)")
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

