# google_mlkit_text_recognition yalnızca Latin alfabesi modeliyle kullanılıyor.
# Eklenti diğer dillerin sınıflarına da referans verdiği için release
# derlemesinde R8 "Missing class" hatası verir; bu sınıflar bilerek yok.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
