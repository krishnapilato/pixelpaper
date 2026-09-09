# Scheda Google Play — testi (it-IT)

Lingua predefinita della scheda: **italiano**, perché l'app è solo in italiano.
I limiti sono quelli della Console: 30 caratteri il nome, 80 la descrizione
breve, 4.000 quella completa.

## Nome dell'app (max 30)

```
PixelPaper
```

## Descrizione breve (max 80)

```
Scanner di documenti e archivio PDF: tutto resta sul tuo dispositivo.
```

## Descrizione completa (max 4.000)

```
PixelPaper trasforma la carta in PDF e li tiene in ordine, senza chiedere niente in cambio: nessun account, nessun caricamento, nessuna pubblicità.

SCANSIONE
Il rilevamento dei bordi di Google ML Kit trova il foglio, raddrizza la prospettiva e pulisce ombre e riflessi. Più pagine di seguito diventano un unico PDF, e il nome lo scegli alla fine, quando hai già visto cosa hai acquisito.

FOTOCAMERA A PIENA RISOLUZIONE
Per le pagine che il ritaglio automatico rovinerebbe — inchiostri sbiaditi, carte fragili, testi antichi — c'è la fotocamera manuale: nessun ritaglio, nessuna correzione, il file resta come l'ha visto il sensore. Puoi anche importare foto già sul telefono e unirle in un unico PDF.

ARCHIVIO ED EDITOR
Elenco o griglia con anteprima, numero di pagine, dimensione e data; ricerca, ordinamento, rinomina, condivisione e stampa. Nell'editor la pagina occupa tutto lo schermo e si cambia scorrendo in orizzontale: trascini una miniatura per riordinare le pagine, ne aggiungi da fotocamera o galleria, duplichi, elimini. Puoi aprire una singola pagina come immagine per ritagliarla, ruotarla, disegnarci sopra o oscurare un dato sensibile, senza toccare le altre.

TESTO DALLE FOTO
L'estrazione del testo lavora sul dispositivo, senza rete. Legge l'alfabeto latino: italiano, inglese, francese e anche il latino. Non sono supportati greco, cirillico, ebraico e arabo; stampe gotiche e scrittura a mano danno risultati parziali.

CARTELLE E CESTINO
Un livello di cartelle per i documenti e uno per le immagini: trascini un elemento su una cartella per spostarlo. Eliminare è reversibile — compare subito Annulla, e il cestino conserva tutto per 30 giorni prima di liberare lo spazio.

PRIVACY
L'unico permesso richiesto è la fotocamera, e serve solo per gli scatti manuali. Lo scanner automatico usa la fotocamera dei servizi Google Play e non chiede permessi all'app; l'importazione passa dal selettore foto di sistema, quindi scegli tu una per una le immagini da condividere. I documenti restano nello spazio privato dell'app: nessun'altra app li vede e niente viene caricato da nessuna parte. Disinstallando l'app, i file vengono rimossi con lei.

NOTE
• Interfaccia disponibile solo in italiano.
• Richiede Android 7.0 o versioni successive.
• Lo scanner automatico richiede i servizi Google Play; dove non sono presenti, resta la fotocamera manuale.

Guida completa: https://krishnapilato.github.io/pixelpaper/

Sviluppata da Khova Krishna Pilato, da un'idea di Stefano Pilato.
```

## Risorse grafiche

| Elemento | File | Formato |
| :--- | :--- | :--- |
| Icona | `store/play-icon-512.png` | 512 × 512 PNG, quadrato pieno |
| Immagine in primo piano | `store/play-feature-1024x500.png` | 1024 × 500 PNG |
| Screenshot | `web/screenshots/*.jpg` | 420 × 935 (rigenerabili a piena risoluzione) |

Icona e immagine si rifanno con `node tool/icon.js` e
`powershell -File tool/feature-graphic.ps1`.
