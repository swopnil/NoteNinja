from keras.applications.resnet50 import ResNet50
from keras.layers import Dense, GlobalAveragePooling2D
from keras.models import Model
from keras.preprocessing.image import ImageDataGenerator
from keras.applications.vgg16 import VGG16


base_model = ResNet50(weights='imagenet', include_top=False, input_shape=(224, 224, 3))
#base_model = VGG16(weights='imagenet', include_top=False, input_shape=(224, 224, 3))
# Freeze the base model layers
for layer in base_model.layers:
    layer.trainable = False
train_datagen = ImageDataGenerator(
    rescale=1./255,
    shear_range=0.2,
    zoom_range=0.2,
    horizontal_flip=True,
    rotation_range=20,
    width_shift_range=0.2,
    height_shift_range=0.2
)

train_generator = train_datagen.flow_from_directory(
    '/dataset/train',  
    target_size=(224, 224),
    batch_size=32,
    class_mode='categorical'
)
val_datagen = ImageDataGenerator(rescale=1./255)>>>>>
val_generator = val_datagen.flow_from_directory(
    '/dataset/test',  
    target_size=(224, 224),
    batch_size=32,
    class_mode='categorical'
)
#  top layer
x = base_model.output
x = GlobalAveragePooling2D()(x)
predictions = Dense(6, activation='softmax')(x)  # 6 classes: front and back of 3 currency notes

model = Model(inputs=base_model.input, outputs=predictions)

model.compile(optimizer='adam', loss='categorical_crossentropy', metrics=['accuracy'])

from keras.callbacks import EarlyStopping
early_stop = EarlyStopping(monitor='val_loss', patience=10)
model.fit_generator(
    train_generator,
    steps_per_epoch=len(train_generator),
    epochs=500,  
    validation_data=val_generator,
    validation_steps=len(val_generator),
    callbacks=[early_stop]  
)


from sklearn.metrics import accuracy_score, confusion_matrix, classification_report
y_true = val_generator.classes
y_pred = model.predict_generator(val_generator).argmax(axis=1)
class_accuracy = accuracy_score(y_true, y_pred)
conf_matrix = confusion_matrix(y_true, y_pred)
currency_report = classification_report(y_true, y_pred)
