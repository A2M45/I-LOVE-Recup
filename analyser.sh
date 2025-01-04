#!/bin/bash

# En-tête HTTP pour indiquer que la réponse est en JSON
echo "Content-Type: application/json"
echo ""

# Fonction pour détecter les périphériques amovibles
if [ "$REQUEST_METHOD" = "GET" ] && [ -z "$QUERY_STRING" ]; then
    # Liste des périphériques amovibles
    peripheriques=($(lsblk -o NAME,MOUNTPOINT,LABEL,SIZE,MODEL | grep -e "sd[b-z]\|sr[0-9]" | awk '{print $1}'))

    # Retourne les périphériques détectés en JSON
    echo '{"peripheriques": ['$(printf '"%s",' "${peripheriques[@]}" | sed 's/,$//')']}'
    exit 0
fi

# Fonction pour analyser un périphérique
if [ "$REQUEST_METHOD" = "GET" ] && [ -n "$QUERY_STRING" ]; then
    # Récupère le périphérique depuis les paramètres de la requête
    device=$(echo "$QUERY_STRING" | sed -n 's/^.*device=\([^&]*\).*$/\1/p')

    # Dossier pour stocker les fichiers récupérés
    OUTPUT_DIR="../recuperes"
    mkdir -p "$OUTPUT_DIR"

    # Liste des signatures de fichiers (magic numbers)
    declare -A signatures=(
        ["jpg"]="\xFF\xD8\xFF"
        ["png"]="\x89PNG"
        ["pdf"]="\x25PDF"
        ["zip"]="\x50\x4B\x03\x04"
        ["mp3"]="\xFF\xFB"
        ["mp4"]="\x00\x00\x00\x20\x66\x74\x79\x70"
    )

    # Taille du bloc à lire (en octets)
    bloc_taille=4096

    # Compteur de fichiers récupérés
    fichiers_recuperes=0

    # Parcours des signatures
    for extension in "${!signatures[@]}"; do
        signature="${signatures[$extension]}"

        # Recherche des signatures dans le périphérique
        dd if="/dev/$device" bs="$bloc_taille" | grep -a -b -o -P "$signature" | while read -r match; do
            offset=$(echo "$match" | cut -d ':' -f 1)
            fichier_sortie="$OUTPUT_DIR/recupere_$fichiers_recuperes.$extension"
            dd if="/dev/$device" bs=1 skip="$offset" count=10485760 of="$fichier_sortie"
            fichiers_recuperes=$((fichiers_recuperes + 1))
        done
    done

    # Liste des fichiers récupérés
    fichiers=($(ls "$OUTPUT_DIR"))

    # Retourne les fichiers récupérés en JSON
    echo '{"fichiers": ['$(printf '"%s",' "${fichiers[@]}" | sed 's/,$//')']}'
    exit 0
fi
