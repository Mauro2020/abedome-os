# ABEDOME OS

ABEDOME OS è la distribuzione appliance di ABEDOME basata su Home Assistant Operating System (HAOS).

## Obiettivo della prima versione

Produrre un'immagine installabile per hardware supportato da HAOS che integri, senza dati personali:

- configurazione e branding ABEDOME;
- componenti ABEDOME distribuiti separatamente;
- un percorso di provisioning al primo avvio;
- aggiornamenti upstream sottoposti ad approvazione ABEDOME.

La baseline HAOS registrata in `UPSTREAM.json` viene mantenuta con modifiche
ABEDOME isolate e revisionabili, senza cambiare gli identificatori tecnici
necessari agli aggiornamenti e alla compatibilità RAUC.

## Branch

| Branch | Ruolo |
|---|---|
| `dev` | copia del ramo di sviluppo upstream; non contiene modifiche ABEDOME |
| `abedome/develop` | base di integrazione ABEDOME, allineata alla release HAOS registrata in `UPSTREAM.json` |
| `automation/upstream-haos-<release>-<base-sha>` | proposta automatica immutabile; mai da modificare a mano |
| `release/*` | immagini ABEDOME candidate o pubblicate |

Le modifiche ABEDOME entrano soltanto in `abedome/develop` tramite pull request.

## Aggiornamenti upstream

Una pipeline settimanale cerca l'ultima release ufficiale HAOS. Quando trova una release non ancora inclusa in `abedome/develop`, aggiorna una draft PR:

1. la pipeline verifica il tag ufficiale e crea un merge commit sopra l'ultima base ABEDOME;
2. esaminiamo il diff e approviamo esplicitamente l'avvio dei workflow della PR;
3. eseguiamo build e test dell'immagine;
4. esaminiamo licenze, cambiamenti e conflitti;
5. solo un'approvazione esplicita ABEDOME permette il merge, usando il metodo merge commit;
6. il rilascio ABEDOME viene poi creato da un branch `release/*`.

Non esiste alcun merge automatico dall'upstream.

## Branding della console

ABEDOME OS personalizza i metadati di sistema, il messaggio di login, la
console di emergenza e i metadati della macchina virtuale, conservando
`HAOS_ID="haos"`, i nomi degli artefatti e la compatibilità `haos-ova`.

Il grande logo ASCII e il prompt mostrati dalla console principale appartengono
invece all'immagine CLI distribuita separatamente. La loro sostituzione richiede
un fork controllato del binario CLI e del relativo container; non viene simulata
con una sostituzione fragile dentro l'immagine OS.

## Licenze e marchi

Il fork mantiene tutti i file di licenza, copyright e notice presenti nell'upstream. Ogni file modificato da ABEDOME deve dichiarare la modifica. Il prodotto e il logo visibili all'utente sono ABEDOME; i riferimenti a Home Assistant sono limitati alle attribuzioni e alla descrizione tecnica richiesta.

## Confini

- nessuna configurazione reale di abitazioni nel repository;
- nessun token, certificato o segreto nell'immagine o nella pipeline;
- Core, Supervisor e Frontend sono fork separati e versionati quando contengono
  modifiche ABEDOME; ogni sostituzione entra soltanto nel canale `dev` dopo CI e
  approvazione esplicita;
- il feed Core ABEDOME di questa fase è limitato alla build di validazione
  OVA/qemux86-64; non è un feed multiarchitettura;
- supportiamo soltanto hardware già supportato da HAOS fino a una decisione separata.
