#!/bin/bash

# Créer les dossiers temporaires
mkdir -p lambda/image_generator/nodejs
mkdir -p lambda/get_images/nodejs

# Copier les fichiers source et package.json
cp lambda/image_generator/index.js lambda/image_generator/nodejs/
cp lambda/get_images/index.js lambda/get_images/nodejs/
cp lambda/package.json lambda/image_generator/nodejs/
cp lambda/package.json lambda/get_images/nodejs/

# Installer les dépendances
cd lambda/image_generator/nodejs
npm install --production
cd ../../..

cd lambda/get_images/nodejs
npm install --production
cd ../../..

# Créer les archives ZIP
cd lambda/image_generator/nodejs
zip -r ../../image_generator.zip .
cd ../../..

cd lambda/get_images/nodejs
zip -r ../../get_images.zip .
cd ../../..

# Nettoyer les dossiers temporaires
rm -rf lambda/image_generator/nodejs
rm -rf lambda/get_images/nodejs

echo "Packages Lambda créés avec succès !" 