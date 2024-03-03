import tensorflow as tf
from keras.preprocessing.image import ImageDataGenerator
from keras.applications import MobileNetV2
from keras.layers import Dense, GlobalAveragePooling2D
from keras.models import Model

# Define image dimensions and batch size
image_size = (224, 224)
batch_size = 32

# Path to the USD currency dataset
usd_dataset_path = '/Users/swopnilpanday/Downloads/wii'

# Create data generators for training and validation
train_datagen_usd = ImageDataGenerator(
    rescale=1./255,
    shear_range=0.2,
    zoom_range=0.2,
    horizontal_flip=True,
    validation_split=0.2
)

train_generator_usd = train_datagen_usd.flow_from_directory(
    usd_dataset_path,
    target_size=image_size,
    batch_size=batch_size,
    class_mode='categorical',
    subset='training'
)

validation_generator_usd = train_datagen_usd.flow_from_directory(
    usd_dataset_path,
    target_size=image_size,
    batch_size=batch_size,
    class_mode='categorical',
    subset='validation'
)

# Load pre-trained MobileNetV2 model without the top classification layer
base_model_usd = MobileNetV2(weights='imagenet', include_top=False, input_shape=(224, 224, 3))

# Add new top layers for classification
x_usd = base_model_usd.output
x_usd = GlobalAveragePooling2D()(x_usd)
x_usd = Dense(512, activation='relu')(x_usd)
predictions_usd = Dense(len(train_generator_usd.class_indices), activation='softmax')(x_usd)

# Combine base model with new top layers
model_usd = Model(inputs=base_model_usd.input, outputs=predictions_usd)

# Freeze the pre-trained layers
for layer in base_model_usd.layers:
    layer.trainable = False

# Compile the model
model_usd.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

# Train the model
epochs = 10  # Adjust the number of epochs as needed
history_usd = model_usd.fit(
    train_generator_usd,
    steps_per_epoch=train_generator_usd.samples // batch_size,
    epochs=epochs,
    validation_data=validation_generator_usd,
    validation_steps=validation_generator_usd.samples // batch_size
)

# Save the trained model for USD currency
model_usd.save('model_usd.h5')

# Optionally, you can also save the class indices for reference
with open('usd_class_indices.txt', 'w') as f:
    f.write(str(train_generator_usd.class_indices))
