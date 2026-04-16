  1. Asegurate que Django corra con 0.0.0.0:8000 en WSL:
  python manage.py runserver 0.0.0.0:8000
  2. En PowerShell/CMD del Windows, ejecutá:
  adb reverse tcp:8000 tcp:8000
  3. Corré la app con la URL correcta:
  flutter run --dart-define=API_URL=http://localhost:8000