#!/bin/bash
set -euo pipefail

echo "=== Inventario - Local Development Setup ==="
echo ""

# Check prerequisites
check_command() {
  if ! command -v "$1" &> /dev/null; then
    echo "ERROR: $1 is not installed. Please install it first."
    exit 1
  fi
  echo "  ✓ $1 found"
}

echo "Checking prerequisites..."
check_command docker
check_command node
check_command flutter
echo ""

# Backend setup
echo "Setting up backend..."
if [ ! -f backend/.env ]; then
  cp backend/.env.example backend/.env
  echo "  Created backend/.env from .env.example"
else
  echo "  backend/.env already exists, skipping"
fi

cd backend
if [ -f package.json ]; then
  npm install
  echo "  Backend dependencies installed"
fi
cd ..

# Mobile setup
echo "Setting up mobile..."
cd mobile
if [ -f pubspec.yaml ]; then
  flutter pub get
  echo "  Flutter dependencies installed"
fi
cd ..

# Start infrastructure services
echo ""
echo "Starting Docker services (PostgreSQL, Redis)..."
docker compose up -d postgres redis

echo ""
echo "=== Setup Complete ==="
echo ""
echo "To start the backend:  cd backend && npm run start:dev"
echo "To start the mobile:   cd mobile && flutter run"
echo "To start all services:  docker compose up"
echo ""
