# ABEDOME OS

ABEDOME OS è la distribuzione appliance di ABEDOME basata su Home Assistant Operating System (HAOS).

## Obiettivo della prima versione

Produrre un'immagine installabile per hardware supportato da HAOS che integri, senza dati personali:

- configurazione e branding ABEDOME;
- componenti ABEDOME distribuiti separatamente;
- un percorso di provisioning al primo avvio;
- aggiornamenti upstream sottoposti ad approvazione ABEDOME.

In questa fase il codice di Home Assistant OS non è stato modificato.

## Branch

| Branch | Ruolo |
|---|---|
| `dev` | copia del ramo di sviluppo upstream; non contiene modifiche ABEDOME |
| `abedome/develop` | base di integrazione ABEDOME, inizializzata dalla release HAOS `17.3` |
| `automation/upstream-haos-release` | proposta automatica, aggiornata dalla pipeline; mai da modificare a mano |
| `release/*` | immagini ABEDOME candidate o pubblicate |

Le modifiche ABEDOME entrano soltanto in `abedome/develop` tramite pull request.

## Aggiornamenti upstream

Una pipeline settimanale cerca l'ultima release ufficiale HAOS. Quando trova una release non ancora inclusa in `abedome/develop`, aggiorna una draft PR:

1. la PR confronta il tag ufficiale con il ramo ABEDOME;
2. eseguiamo build e test dell'immagine;
3. esaminiamo licenze, cambiamenti e conflitti;
4. solo un'approvazione esplicita ABEDOME permette il merge;
5. il rilascio ABEDOME viene poi creato da un branch `release/*`.

Non esiste alcun merge automatico dall'upstream.

## Licenze e marchi

Il fork mantiene tutti i file di licenza, copyright e notice presenti nell'upstream. Ogni file modificato da ABEDOME deve dichiarare la modifica. Il prodotto e il logo visibili all'utente sono ABEDOME; i riferimenti a Home Assistant sono limitati alle attribuzioni e alla descrizione tecnica richiesta.

## Confini

- nessuna configurazione reale di abitazioni nel repository;
- nessun token, certificato o segreto nell'immagine o nella pipeline;
- Core, Supervisor e Frontend restano upstream finché non richiedono modifiche ABEDOME specifiche;
- supportiamo soltanto hardware già supportato da HAOS fino a una decisione separata.
