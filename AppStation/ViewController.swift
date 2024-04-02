//
//  ViewController.swift
//  AppStation
//
//  Created by Matthieu Guillemin on 02/04/2024.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // définition de l'URL de l'API
        let apiUrl = URL(string: "https://public.opendatasoft.com/api/explore/v2.1/catalog/datasets/prix_des_carburants_j_7/records?limit=5")!
        
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
            
            // conversion des données JSON en objet Swift
            do {
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                print(json)
                // traitement des données JSON...
            } catch {
                print("Erreur lors de la conversion JSON : \(error)")
            }
        }
        
        // lancement de la tâche
        task.resume()
    }


}

