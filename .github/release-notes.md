## PixelPaper {{VERSION}}

Scanner di documenti e archivio PDF per Android, **privacy first**: niente account, niente pubblicità, nessuna richiesta di rete. Documenti e foto restano nella memoria privata dell'app.

### Il modo consigliato: Google Play

- 🧪 **Diventa tester** e ricevi le versioni in anteprima:
  https://play.google.com/apps/testing/com.khovakrishnapilato.pixelpaper
- 📲 **Scarica l'app** dal Play Store, con aggiornamenti automatici:
  https://play.google.com/store/apps/details?id=com.khovakrishnapilato.pixelpaper

Il Play Store resta il canale più comodo: aggiorna da solo e verifica la firma per te.

### Installare l'APK a mano

Quale file scegliere:

| File | Per chi |
|---|---|
| `PixelPaper-{{VERSION}}-arm64-v8a.apk` | Quasi tutti i telefoni degli ultimi anni (consigliato) |
| `PixelPaper-{{VERSION}}-armeabi-v7a.apk` | Telefoni a 32 bit più vecchi |
| `PixelPaper-{{VERSION}}-x86_64.apk` | Emulatori e pochi tablet Intel |
| `PixelPaper-{{VERSION}}-universale.apk` | Se non sai quale scegliere: funziona ovunque, pesa di più |

**Gli avvisi di sicurezza di Android sono normali.** Installando un APK fuori dal Play Store il telefono mostra uno o più messaggi come:

- «Per motivi di sicurezza, il telefono non può installare app sconosciute da questa fonte» → tocca **Impostazioni** e attiva **Consenti da questa fonte** per il browser o il gestore file che stai usando, poi torna indietro;
- «App non sicura bloccata» o «Play Protect non riconosce lo sviluppatore» → tocca **Altri dettagli** e poi **Installa comunque**;
- «Vuoi installare questa app?» → **Installa**.

Succede con qualsiasi app scaricata da internet, non indica un problema di PixelPaper. Dopo l'installazione puoi disattivare di nuovo «Consenti da questa fonte».

Se hai già PixelPaper dal Play Store, l'APK si installa sopra solo se la firma coincide; in caso contrario Android lo rifiuta per proteggere i tuoi dati: in quel caso aggiorna dal Play Store.

### Verificare il file (facoltativo)

`SHA256SUMS.txt` contiene l'impronta di ogni APK. Su un computer:

```bash
sha256sum -c SHA256SUMS.txt --ignore-missing
```

### Privacy

- Permessi: solo **fotocamera**. Nessun accesso a internet, contatti, posizione o archivio.
- Foto e PDF condivisi o esportati escono **senza metadati**: niente coordinate GPS, modello del telefono o data di scatto nascosti nel file.
- Le copie temporanee create per condividere, stampare o esportare vengono cancellate subito dopo.
- Svuotando il Cestino i file vengono eliminati davvero dal telefono, album compresi.
- I dati dell'app sono esclusi dal backup su cloud di Google.
