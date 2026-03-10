#!/bin/bash
# Script para Vercel instalar o Flutter e buildar o projeto Web

echo "Baixando o Flutter SDK..."
git clone https://github.com/flutter/flutter.git -b stable

echo "Adicionando Flutter ao PATH..."
export PATH="$PATH:`pwd`/flutter/bin"

echo "Verificando instalação do Flutter..."
flutter doctor

echo "Compilando o aplicativo Flutter para Web..."
flutter build web --release
