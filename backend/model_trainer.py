import tensorflow as tf
import os
import numpy as np

# A very basic dummy Neural Network that mimics our AI logic for text scoring.
# In an actual deployment, this would use TF-DF (TensorFlow Decision Forests)
# or a full NLP pipeline with embeddings.

def train_and_export_tflite(output_path):
    print("Training a lightweight AI model for SOS priority classification...")
    
    # 1. Dummy Model Definition
    # We take a vectorized shape of [10] (dummy features).
    model = tf.keras.Sequential([
        tf.keras.layers.Dense(16, activation='relu', input_shape=(10,)),
        tf.keras.layers.Dense(3, activation='softmax') # 3 classes: Low, High, Critical
    ])
    
    model.compile(optimizer='adam', loss='sparse_categorical_crossentropy', metrics=['accuracy'])
    
    # Dummy data (100 samples)
    x_train = np.random.rand(100, 10).astype(np.float32)
    y_train = np.random.randint(0, 3, 100).astype(np.int32)
    
    model.fit(x_train, y_train, epochs=2, verbose=0)
    
    print("Exporting to TFLite...")
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    tflite_model = converter.convert()
    
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
        
    print(f"Model successfully saved to {output_path}")

if __name__ == '__main__':
    export_dir = os.path.join(os.path.dirname(__file__), '../resqnet/assets/model.tflite')
    os.makedirs(os.path.dirname(export_dir), exist_ok=True)
    try:
        train_and_export_tflite(export_dir)
    except Exception as e:
        print("TensorFlow not optimized/installed. Writing a dummy file.")
        with open(export_dir, 'wb') as f:
            f.write(b"DUMMY_TFLITE_MODEL")
