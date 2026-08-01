# Politica di aggiornamento upstream

## Fonte

La fonte ufficiale è `home-assistant/operating-system`. La baseline iniziale ABEDOME OS è il tag firmato `17.3`.

## Proposta automatica

Il workflow `propose-upstream-release.yml` gira ogni lunedì e può essere avviato manualmente. Controlla l'ultima release ufficiale HAOS e apre o aggiorna una pull request in stato draft verso `abedome/develop`.

La pipeline:

- non esegue merge;
- non crea una release ABEDOME;
- non modifica `abedome/develop`;
- usa un solo branch di proposta, così ogni release non approvata resta in una sola PR revisionabile.

## Approvazione

Una proposta può essere portata avanti solo dopo:

1. revisione del changelog e della sicurezza;
2. build completa dell'immagine per l'hardware supportato;
3. test di installazione e aggiornamento;
4. verifica che configurazione e branding ABEDOME siano applicati correttamente;
5. approvazione esplicita del responsabile ABEDOME.

## Eccezioni

Un aggiornamento di sicurezza urgente segue la stessa procedura, ma può avere priorità. Non deve mai saltare build, test o approvazione.
