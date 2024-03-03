import cv2
import numpy as np
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

def calculate_mse(image1, image2):
    # Resize images to same dimensions
    image1 = cv2.resize(image1, (224, 224))
    image2 = cv2.resize(image2, (224, 224))

    err = np.sum((image1.astype("float") - image2.astype("float")) ** 2)
    err /= float(image1.shape[0] * image1.shape[1])
    return err

# Load reference image
reference_image = cv2.imread("/Users/swopnilpanday/matchresearch/IMG_0170.jpg", cv2.IMREAD_GRAYSCALE)

# Define paths to the four folders of similar images
folder_dirs = [
    "/Users/swopnilpanday/matchresearch/datasets/nrs100",
    "/Users/swopnilpanday/matchresearch/datasets/1",
    "/Users/swopnilpanday/matchresearch/datasets/10",
    "/Users/swopnilpanday/matchresearch/datasets/20",
]

# Calculate similarity scores for each folder
def calculate_similarity(image):
    folder_similarity_scores = {}
    
    for folder_dir in folder_dirs:
        images10 = os.listdir(folder_dir)
        folder_scores = []
        
        for similar_image_path in images10:
            if similar_image_path.endswith(".DS_Store"):
                continue
            
            similar_image = cv2.imread(os.path.join(folder_dir, similar_image_path), cv2.IMREAD_GRAYSCALE)
            
            # Check if image is read successfully
            if similar_image is None:
                print(f"Error reading image: {similar_image_path}")
                continue
            
            # Calculate similarity if image is read successfully
            similarity = calculate_mse(image, similar_image)
            folder_scores.append(similarity)
        
        # Take the average MSE for the folder
        if len(folder_scores) > 0:
            folder_avg_score = np.mean(folder_scores)
            folder_name = os.path.basename(folder_dir)  # Get the last part of the path
            folder_similarity_scores[folder_name] = folder_avg_score
    
    return folder_similarity_scores

# Route to receive image from Swift app
@app.route("/upload", methods=["POST"])
def upload_image():
    if request.method == "POST":
        if "file" not in request.files:
            return jsonify({"error": "No file part"})
        
        file = request.files["file"]
        if file.filename == "":
            return jsonify({"error": "No selected file"})
        
        if file:
            # Convert file data to numpy array
            nparr = np.frombuffer(file.read(), np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_GRAYSCALE)
            
            if image is None:
                return jsonify({"error": "Failed to decode image"})
            
            # Calculate similarity scores
            similarity_scores = calculate_similarity(image)
            
            # Find the folder with the minimum average MSE (indicating highest similarity)
            if similarity_scores:
                best_match_folder = min(similarity_scores, key=similarity_scores.get)
                best_match_score = similarity_scores[best_match_folder]
                
                result = {
                    "folder": best_match_folder
                }
                
                return jsonify(result)
            else:
                return jsonify({"error": "No similarity scores calculated"})
    
    return jsonify({"error": "Invalid request"})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=4555)
