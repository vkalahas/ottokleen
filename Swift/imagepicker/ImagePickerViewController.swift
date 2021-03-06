// Copyright 2016 Google Inc. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit
import SwiftyJSON


class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    let imagePicker = UIImagePickerController()
    let session = URLSession.shared
    
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var labelResults: UITextView!
    @IBOutlet weak var classificationResults: UITextView!
    @IBOutlet weak var faceResults: UITextView!
    
    // var googleAPIKey = "YOUR_API_KEY"
    var googleAPIKey = "AIzaSyAEkOF_OeChfhSYvBhpF8Iov2cpYoheTfE"
    var googleURL: URL {
        return URL(string: "https://vision.googleapis.com/v1/images:annotate?key=\(googleAPIKey)")!
    }
    
    @IBAction func loadImageButtonTapped(_ sender: UIButton) {
        classificationResults.isHidden = true
        imagePicker.allowsEditing = false
        imagePicker.sourceType = .camera
        
        present(imagePicker, animated: true, completion: nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        imagePicker.delegate = self
        labelResults.isHidden = true
        classificationResults.isHidden = true
        faceResults.isHidden = true
        spinner.hidesWhenStopped = true
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
}


/// Image processing

extension ViewController {
    
    func analyzeResults(_ dataToParse: Data) {
        
        // Update UI on the main thread
        DispatchQueue.main.async(execute: {
            
            // Use SwiftyJSON to parse results
            let json = JSON(data: dataToParse)
            let errorObj: JSON = json["error"]
            
            self.spinner.stopAnimating()
            self.imageView.isHidden = false //was true
            self.labelResults.isHidden = true//was false
            self.classificationResults.isHidden = false
            self.faceResults.isHidden = true //was false
            self.faceResults.text = ""
            
            // Check for errors
            if (errorObj.dictionaryValue != [:]) {
                self.labelResults.text = "Error code \(errorObj["code"]): \(errorObj["message"])"
            } else {
                // Parse the response
                print(json)
                let responses: JSON = json["responses"][0]
                
                // start ignore
                
                
                // Get face annotations
                let faceAnnotations: JSON = responses["faceAnnotations"]
                if faceAnnotations != JSON.null {
                    let emotions: Array<String> = ["joy", "sorrow", "surprise", "anger"]
                    
                    let numPeopleDetected:Int = faceAnnotations.count
                    
                    self.faceResults.text = "People detected: \(numPeopleDetected)\n\nEmotions detected:\n"
                    
                    var emotionTotals: [String: Double] = ["sorrow": 0, "joy": 0, "surprise": 0, "anger": 0]
                    var emotionLikelihoods: [String: Double] = ["VERY_LIKELY": 0.9, "LIKELY": 0.75, "POSSIBLE": 0.5, "UNLIKELY":0.25, "VERY_UNLIKELY": 0.0]
                    
                    for index in 0..<numPeopleDetected {
                        let personData:JSON = faceAnnotations[index]
                        
                        // Sum all the detected emotions
                        for emotion in emotions {
                            let lookup = emotion + "Likelihood"
                            let result:String = personData[lookup].stringValue
                            emotionTotals[emotion]! += emotionLikelihoods[result]!
                        }
                    }
                    // Get emotion likelihood as a % and display in UI
                    for (emotion, total) in emotionTotals {
                        let likelihood:Double = total / Double(numPeopleDetected)
                        let percent: Int = Int(round(likelihood * 100))
                        self.faceResults.text! += "\(emotion): \(percent)%\n"
                    }
                } else {
                    self.faceResults.text = "No faces found"
                }
                
                
                // end ignore
                
                
                // Get label annotations
                let labelAnnotations: JSON = responses["labelAnnotations"]
                let numLabels: Int = labelAnnotations.count
                var labels: Array<String> = []
                if numLabels > 0 {
                    var labelResultsText:String = "Labels found: "
                    for index in 0..<numLabels {
                        let label = labelAnnotations[index]["description"].stringValue
                        labels.append(label)
                    }
                }
                    
                // add labels to a long string to display
                var labelResultsText:String = ""
                for label in labels {
                    // if it's not the last item add a comma
                    if labels[labels.count - 1] != label {
                        labelResultsText += "\(label), "
                    } else {
                        labelResultsText += "\(label)"
                    }
                }
                    
                // shows labels
                if self.labelResults.text != nil {
                    self.labelResults.text = labelResultsText
                } else {
                    self.labelResults.text = "No labels found"
                }
                    
                // classification section
                // definitions
                var recycling = ["chip bag", "water bottle", "glass bottle", "plastic bag", "soda can", "snack bag", "plastic bottle", "plastic container", "rigid plastic", "paper", "cardboard", "cereal box", "snack box", "magazine", "mail", "office paper", "newspaper", "tin can", "aluminum can", "steel can", "glass container", "glass jar", "beer bottle", "wine bottle", "liquor bottle", "shredded paper", "box"]
                
                var compost = ["fruit waste", "vegetable waste", "apple", "orange", "pear", "banana", "broccoli", "twig", "grass", "old bread", "donut", "cookie", "cracker", "pizza crust", "noodle", "grain", "rice", "barley", "coffee", "ground", "tea bag", "fruit", "pulp", "vegetable pulp", "egg shell", "corn cob", "corn husk", "pizza", "pepperoni", "pizza cheese", "food", "cuisine", "french fries", "peel", "vegetarian food", "bread", "vegetable scraps", "egg", ]
                
                var trash = ["plastic stretch wrap", "stretch wrap", "egg carton", "take out container", "drinking cup", "broken glass", "sharp glass", "fast food packaging", "plastic utensil", "food waste", "garden hose", "light bulb", "soiled bag", "soiled container", "animal feces", "toy"]
                
                // classify
                // 0 - recycling, 1 - compost, 2 - trash, 3 - not trash
                var classification:Int = 3
                for label in labels {
                    // checks if in any category
                    if recycling.contains(label) {
                        classification = 0
                        break
                    } else if compost.contains(label) {
                        classification = 1
                        break
                    } else if trash.contains(label) {
                        classification = 2
                        break
                    }
                }
                    
                // show user classification
                switch(classification) {
                    case 0:
                        self.classificationResults.text = "The object found can be recycled!"
                        break
                    case 1:
                        self.classificationResults.text = "The object found can be composted!"
                        break
                    case 2:
                        self.classificationResults.text = "Tough luck! The object found is trash!"
                        break
                    default:
                        self.classificationResults.text = "WHAT ARE THOSE!? I can't believe it's not trash!"
                        break
                }
                    
                // send image and classification to storage for referencing
                  
                
            }
        })
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {
            imageView.contentMode = .scaleAspectFit
            imageView.image = pickedImage
            spinner.startAnimating()
            faceResults.isHidden = true
            labelResults.isHidden = true
            
            // Base64 encode the image and create the request
            let binaryImageData = base64EncodeImage(pickedImage)
            createRequest(with: binaryImageData)
        }
        
        dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
    
    func resizeImage(_ imageSize: CGSize, image: UIImage) -> Data {
        UIGraphicsBeginImageContext(imageSize)
        image.draw(in: CGRect(x: 0, y: 0, width: imageSize.width, height: imageSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        let resizedImage = UIImagePNGRepresentation(newImage!)
        UIGraphicsEndImageContext()
        return resizedImage!
    }
}


/// Networking

extension ViewController {
    func base64EncodeImage(_ image: UIImage) -> String {
        var imagedata = UIImagePNGRepresentation(image)
        
        // Resize the image if it exceeds the 2MB API limit
        if (imagedata?.count > 2097152) {
            let oldSize: CGSize = image.size
            let newSize: CGSize = CGSize(width: 800, height: oldSize.height / oldSize.width * 800)
            imagedata = resizeImage(newSize, image: image)
        }
        
        return imagedata!.base64EncodedString(options: .endLineWithCarriageReturn)
    }
    
    func createRequest(with imageBase64: String) {
        // Create our request URL
        
        var request = URLRequest(url: googleURL)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(Bundle.main.bundleIdentifier ?? "", forHTTPHeaderField: "X-Ios-Bundle-Identifier")
        
        // Build our API request
        let jsonRequest = [
            "requests": [
                "image": [
                    "content": imageBase64
                ],
                "features": [
                    [
                        "type": "LABEL_DETECTION",
                        "maxResults": 10
                    ],
                    [
                        "type": "FACE_DETECTION",
                        "maxResults": 10
                    ]
                ]
            ]
        ]
        let jsonObject = JSON(jsonDictionary: jsonRequest)
        
        // Serialize the JSON
        guard let data = try? jsonObject.rawData() else {
            return
        }
        
        request.httpBody = data
        
        // Run the request on a background thread
        DispatchQueue.global().async { self.runRequestOnBackgroundThread(request) }
    }
    
    func runRequestOnBackgroundThread(_ request: URLRequest) {
        // run the request
        
        let task: URLSessionDataTask = session.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "")
                return
            }
            
            self.analyzeResults(data)
        }
        
        task.resume()
    }
}


// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

// FIXME: comparison operators with optionals were removed from the Swift Standard Libary.
// Consider refactoring the code to use the non-optional operators.
fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}
