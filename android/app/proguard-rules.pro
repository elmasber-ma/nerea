# Nerea: el motor Gecko no se ofusca (R8 rompe sus JNI/delegados).
-keep class org.mozilla.geckoview.** { *; }
-keep interface org.mozilla.geckoview.** { *; }
-dontwarn org.mozilla.**
# snakeyaml referencia java.beans (no existe en Android): falso positivo.
-dontwarn java.beans.**
-dontwarn org.yaml.snakeyaml.**
