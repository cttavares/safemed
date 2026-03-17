# Regras para o ML Kit Text Recognition
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Opcional: Manter as classes base para evitar outros erros de missing classes
-keep class com.google.mlkit.vision.text.** { *; }